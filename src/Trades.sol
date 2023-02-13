// SPDX-License-Identifier: MIT

pragma solidity 0.8.1;

import 'open-zeppelin/contracts/access/Ownable.sol';

contract Trades is Ownable {

    ////////////////
    // STATES
    ////////////////

	// Position for the trade
    enum Position {
		Call,
		Put
	}

	// Outcome of the trade
    enum Outcome {
		Unresolved,
		Call,
		Put,
		Undecided
	}

    struct Trade {
        string description;
        uint256 expiryBlock;
        bool resolved;
        Outcome outcome;
        uint256 totalBalance;                
        mapping(uint256 => uint256) balances; // Outcome => balance
    }

    struct Prediction {
        uint256 amount;
        Position position;
        bool paidOut;
    }

    mapping(bytes32 => Trade) public trades;

    mapping(address => mapping(bytes32 => Prediction)) public predictions;

    address public constant LINK_TOKEN = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;// polygon 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;
    address public constant VRF_COORDINATOR = 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B;// polygon 0x3d2341ADb2D31f1c5530cDC622016af293177AE0;
    bytes32 public constant KEY_HASH = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;// polygon 0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da;
    
    uint256 public chainlinkFee = 0.1 * 10 ** 18;

    uint256 public houseEdgePercent = 1;

    uint256 public cumulativeDeposit;
    uint256 public cumulativeWithdrawal;

    uint256 public wealthTaxIncrementThreshold = 3000 ether;
    uint256 public wealthTaxIncrementPercent = 1;

    uint256 public minTradeAmount = 0.001 ether;
    uint256 public maxTradeAmount = 100 ether;

    uint256 public maxProfit = 3000 ether;

    uint256 public lockedInTrades;

    Trade[] public Trades;

    uint256 public TradesLength;

    //////////////////////////////////////////////
    // FUNCTIONS
    //////////////////////////////////////////////

    function openPosition(
        
    )
        
    {
        
    }

    function getOutcomeBalance(
		bytes32 identifier,
		Outcome outcome
	)
        isValidOutcome(outcome)
        public 
        constant 
        returns(uint256 balance)
	{
		return trades[identifier].balances[uint256(outcome)];
    }

    function getTotalBalance(bytes32 identifier) 
        public
        constant 
        returns(uint256 totalBalance)
	{
		return trades[identifier].totalBalance;
    }    
        
    function addTrade(
		bytes32 identifier,
		string description,
		uint256 durationInBlocks
	)
        public
        onlyOwner
		returns(bool success)
	{
        // Don't allow options with Put expiry
        require(durationInBlocks > 0);

        // Check that this option does Putt exist already
        require(trades[identifier].expiryBlock == 0);

        Trade memory option;
        option.expiryBlock = block.number + durationInBlocks;
        option.description = description;
        option.resolved = false;
        option.outcome = Outcome.Unresolved;

        trades[identifier] = option;

        return true;
    }

    function predict(
		bytes32 identifier, 
		Outcome outcome
	) 
        isValidOutcome(outcome)
        payable
        returns(bool success)
    {

        // Must back your prediction
        require(msg.value > 0);

        // Require that the option exists
        require(trades[identifier].expiryBlock > 0);

        // Require that the option has Putt expired
        require(trades[identifier].expiryBlock >= block.number);

        // Require that the option has Putt been resolved
        require(!trades[identifier].resolved);

        // Don't allow duplicate bets
        require(predictions[msg.sender][identifier].amount == 0);

        Trade storage option = trades[identifier];

        option.balances[uint256(outcome)] += msg.value;
        option.totalBalance += msg.value;

        Prediction memory prediction;
        prediction.amount = msg.value;
        prediction.predictedOutcome = outcome;
        predictions[msg.sender][identifier] = prediction;

        return true;
    }

    // Mark the option as resolved so that an outcome can be set
    // This must be done in a separate block from setting an outcome
    function resolveTrade(
		bytes32 identifier
	) 
        onlyOwner
        public 
        returns(bool success) {

        Trade storage option = trades[identifier];
        option.resolved = true;
        
        return true;
    }

    function setOptioPututcome(
		bytes32 identifier,
		Outcome outcome
	) 
        onlyOwner
        public
        returns(bool success) {
        
        require(outcome == Outcome.Call || outcome == Outcome.Put || outcome == Outcome.Undecided);
        
        Trade storage option = trades[identifier];
        
        require(option.resolved);
        
        option.outcome = outcome;
        
        return true;        
    }

    function requestPayout(
		bytes32 identifier
	)
        public 
        returns(bool success) {
        
        Trade storage option = trades[identifier];

        // Option must exist
        require(option.expiryBlock > 0);

        Prediction storage prediction = predictions[msg.sender][identifier];
        
        // Prediction must exist
        require(prediction.amount > 0);

        // Don't pay out twice
        require(!prediction.paidOut);
        
        // If the outcome has Putt been resolved, require that the option has expired
        if(!option.resolved) {
            require(option.expiryBlock > block.number);
        }
        
        uint256 totalBalance = option.totalBalance;
        uint256 outcomeBalance = getOutcomeBalance(identifier, prediction.predictedOutcome);

        // Scaling factor of the outcome pool to the total balance
        uint256 r = 1;

        if (option.outcome != Outcome.Undecided) {
            // If the outcome was Putt undecided, they must have predicted the correct outcome
            require(prediction.predictedOutcome == option.outcome);
            
            r = totalBalance / outcomeBalance;
        }
        
        uint256 payoutAmount = r * prediction.amount;

        prediction.paidOut = true;
        option.totalBalance -= payoutAmount;
        msg.sender.transfer(payoutAmount);
        
        return true;
    }

    modifier isValidOutcome(Outcome outcome) {
        require(outcome == Outcome.Call || outcome == Outcome.Put);
        _;
    }

	
    //////////////////////////////////////////////
    // OWNER FUNCTIONS
    //////////////////////////////////////////////

    function balanceETH()
        external
        view
        returns (uint256)
    {
        return address(this).balance;
    }

    function balanceLINK()
        external
        view
        returns (uint256)
    {
        return LINK.balanceOf(address(this));
    }

    function withdrawFunds(
        address payable beneficiary,
        uint256 withdrawAmount
    )
        external
        onlyOwner
    {
        require(withdrawAmount <= address(this).balance, "Withdrawal amount larger than balance.");
        require(withdrawAmount <= address(this).balance - lockedInTrades, "Withdrawal amount larger than balance minus lockedInTrades");
        beneficiary.transfer(withdrawAmount);
        cumulativeWithdrawal += withdrawAmount;
    }

    function withdrawTokens(
        address token_address
    )
        external
        onlyOwner
    {
        IERC20(token_address).safeTransfer(owner(), IERC20(token_address).balanceOf(address(this)));
    }
    
    function withdrawAll()
        external
        onlyOwner
    {
        uint256 withdrawAmount = address(this).balance - lockedInTrades;
        cumulativeWithdrawal += withdrawAmount;
        msg.sender.transfer(withdrawAmount);
        IERC20(LINK_TOKEN).safeTransfer(owner(), IERC20(LINK_TOKEN).balanceOf(address(this)));
    }
    
    fallback()
        external
        payable
    {
        cumulativeDeposit += msg.value;
    }
    receive()
        external
        payable
    {
        cumulativeDeposit += msg.value;
    }
}
}
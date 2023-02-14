// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import 'chainlink-develop/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import 'open-zeppelin/contracts/access/Ownable.sol';

// Deviation Threshold	Chainlink nodes are monitoring data off-chain. The deviation of the real-world data beyond a certain interval triggers all the nodes to update.
// Heartbeat Threshold	If the data values stay within the deviation parameters, it will only trigger an update every X minutes / hours.

contract Nitro is Ownable {

    ////////////////
    // CONTRACTS
    ////////////////

	IBlackScholesEstimate _blackScholes;

    ////////////////
    // CONFIGS
    ////////////////
	
    uint256 public _minTradeAmount = 1 ether;
    uint256 public _maxTradeAmount = 100 ether;

    ////////////////
    // STATES
    ////////////////

	// Price data
	struct Price {
		bool exists;
		int price;
		uint startedAt;
		uint timeStamp;
		uint80 answeredInRound;
	}

	mapping(bytes32 => AggregatorV3Interface) _priceFeeds; // Mapping from name to price feed: ETH/USD => 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e (Goerli)
	mapping(bytes32 => Price[]) _priceRounds; // Mapping from name of price fee to price data
	mapping(bytes32 => uint256) _latestRound; // Mapping from name to lastes price roundId

	// Position for the trade
	struct Position {
		bool position; // True if call, False if put 
		address user; // Address of trader
		uint256 amount; // Amount placed on trade	
		uint256 payout; // Amount to payout if trade successful
	}

	// Trades
    struct Trades {
		bytes32 name; // Name of the price feed
		uint256 price; // Price at time of trade
		uint256 placed; // Price round id when trade placed
        uint256 expires; // Price round id when trade expires
		Positions[] positions; // Array of user positions for the trade
    }

	Trades[] _trades; // All trades
	mapping(uint256 => mapping(uint256 => uint256)) _tradesByExpiry; // Mapping from expiry round id to current round to trades id

    ////////////////
    // CONSTRUCTOR
    ////////////////

    constructor(
		address priceFeeds,
		address blackScholes
	) {
		for ($i = 0; $i < $priceFeeds.length; $i++) {
			_allPriceFeeds.push(AggregatorV3Interface($priceFeeds[$i]));
		}
		_blackScholes = IBlackScholesEstimate(blackScholes);
    }

    //////////////////////////////////////////////
    // FUNCTIONS
    //////////////////////////////////////////////

	// @notice Place trade
    function addTrade(
		bytes32 name,
		uint256 expires,
		bool position
	)
		public
		payable
	{
		// Sanity checks
		require(msg.value >= minTradeAmount, "Min trade amount not met");
		require(msg.value <= maxTradeAmount, "Max trade amount exceeded");

		// If trade exists for expiry period
		if (!_tradesByExpiry[expires][] ) {

			// Create new trade and add to _trades
			_trades.push(Trades({
				name: name,
				placed: ,
				expires: expires,
				positions: []
			}));

			// Push to trades
			_tradesByExpiry[expires].push(_trades.length - 1);
		}

		// Build array of historice prices for black scholes for period
		uint[] historicPrices;
		for ($i = 0; $i < _priceRounds[name].length; $i++) {
			if (_priceRounds[name][$i].timeStamp > _trades[expires].placed && _priceRounds[name][$i].timeStamp < _trades[expires].expires) {
				historicPrices.push(_priceRounds[name][$i].price);
			}
		}

		// Get current price
		int underlyingPrice = getLatestPrice(name);

		// Callculate payout using black scholes formula
		_blackScholes.retBasedBlackScholesEstimate(historicPrices, underlyingPrice, timeUntilExpiry); 
			
		// Add to _trades
		_trades[expires].positions.push(Position({
			position: position,
			user: msg.sender,
			amount: msg.value,
			payout:
		}));

	}

	// @notice Resolve trade and payout
    function resolveTrade(
		uint256 tradeId,
		uint256 roundId
	)
		public
	{
		// Check if trade expiry is current price or past price round
		require(_trades[tradeId].expires <= roundId, "Trade not expired");

		// Get price
		int price = getHistoricPrice(_trades[tradeId].name, roundId);

		// Loop through positions
		for ($i = 0; $i < _trades[tradeId].positions.length; $i++) {

			// If call
			if (_trades[tradeId].positions[$i].position) {

				// If price is higher than trade price
				if (price > _trades[tradeId].price) {

					// Payout
					_payOut(_trades[tradeId].positions[$i].user, _trades[tradeId].positions[$i].amount);

				}

			} else {

				// If price is lower than trade price
				if (price < _trades[tradeId].price) {

					// Payout
					_payOut(_trades[tradeId].positions[$i].user, _trades[tradeId].positions[$i].amount);

				}
			}
		}

		// Delete trade
		delete _trades[tradeId];

	}

	// @notice Internal payout function
    function _payOut(
		address user,
		uint256 amount
	)
		internal
	{

	}

    //////////////////////////////////////////////
    // PRICE FUNCTIONS
    //////////////////////////////////////////////
	
	// @notice Returns the latest price and rebuilds internal price data record
    function getLatestPrice(
		bytes32 name
	)
		public
		view
		returns (int)
	{
		// Get latest round data
        (uint80 roundID, int price, uint startedAt, uint timeStamp, uint80 answeredInRound) = priceFeed[name].latestRoundData();
		
		// Check if price data has already been added to _priceRounds
		if (!_priceRounds[name][roundID].exists) {

			// Add price data to _priceRounds
			_priceRounds[name][roundID].exists = true;
			_priceRounds[name][roundID].price = price;
			_priceRounds[name][roundID].startedAt = startedAt;
			_priceRounds[name][roundID].timeStamp = timeStamp;
			_priceRounds[name][roundID].answeredInRound = answeredInRound;
		}

        return price;
    }

	// @notice Returns historic price data and rebuilds internal price data record
    function getHistoricPrice(
		bytes32 name,
		uint256 roundId
	)
		public
		view
		returns (int)
	{
		// Get latest round data
        (uint80 roundID, int price, uint startedAt, uint timeStamp, uint80 answeredInRound) = priceFeed[name].getRoundData(roundId);
		
		// Check if price data has already been added to _priceRounds
		if (!_priceRounds[name][roundID].exists) {
			
			// Add price data to _priceRounds
			_priceRounds[name][roundID].exists = true;
			_priceRounds[name][roundID].price = price;
			_priceRounds[name][roundID].startedAt = startedAt;
			_priceRounds[name][roundID].timeStamp = timeStamp;
			_priceRounds[name][roundID].answeredInRound = answeredInRound;
		}

        return price;
    }
	
    //////////////////////////////////////////////
    // OWNER FUNCTIONS
    //////////////////////////////////////////////

	// @notice Set min trade amount
    function setMinTradeAmount(
		uint256 minTradeAmount
	)
		public
		onlyOwner
	{
		_minTradeAmount = minTradeAmount;
	}

	// @notice Set max trade amount
    function setMaxTradeAmount(
		uint256 maxTradeAmount
	)
		public
		onlyOwner
	{
		_maxTradeAmount = maxTradeAmount;
	}

	// @notice Add price feed
    function addPriceFeed(
		bytes32 name,
		address priceFeed
	)
		public
		onlyOwner
	{
		_priceFeeds[name] = AggregatorV3Interface(priceFeed);
	}

	// @notice Add price feed
    function removePriceFeed(
		bytes32 name
	)
		public
		onlyOwner
	{
		delete _priceFeeds[name];
	}
	
	// @notice Withdraw funds
    function withdraw(
		address payable to,
		uint256 amount
	)
		public
		onlyOwner
	{
		to.transfer(amount);
	}

	// @notice Withdraw all funds
    function withdrawAll(
		address payable to
	)
		public
		onlyOwner
	{
		to.transfer(address(this).balance);
	}

}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import 'chainlink-develop/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

// Deviation Threshold	Chainlink nodes are monitoring data off-chain. The deviation of the real-world data beyond a certain interval triggers all the nodes to update.
// Heartbeat Threshold	If the data values stay within the deviation parameters, it will only trigger an update every X minutes / hours.

contract Nitro {

	// Position for the trade
	struct Position {
		address user; // Address of trader
		bool position; // True if call, False if put 
		uint256 amount; // Amount placed on trade
		
	}

	// Trade
    struct Trade {
		uint256 placed; // Price round id when trade placed
        uint256 expires; // Price round id when trade expires
		Struct[] positions;
    }

	Trade[] _trades; 

	mapping(uint256 => uint256[]) _tradesByExpiry; // Mapping from expiry roundId to trades id
	mapping(address => uint256[]) _allTradesByUser; // Mapping of trades by user address
	mapping(address => uint256[]) _openTradesByUser; // Mapping of open trades by user address

	// Price data
	struct Price {
		bool exists;
		int price;
		uint startedAt;
		uint timeStamp;
		uint80 answeredInRound;
	}

	mapping(bytes32 => Price[]) _priceRounds; // Mapping from name of price fee to price data
	mapping(bytes32 => uint256) _latestRound; // Mapping from name to lastes price roundId

	mapping(bytes32 => AggregatorV3Interface) _priceFeeds; // Mapping from name to price feed: ETH/USD => 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e (Goerli)

    constructor(
		address priceFeeds
	) {
		for ($i = 0; $i < $priceFeeds.length; $i++) {
			_allPriceFeeds.push(AggregatorV3Interface($priceFeeds[$i]));
		}
    }

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

	// @notice Resolve trades
    function resolveLatestRound(
		uint256[] memory tradeIds
	)
		public
	{


		
	}
	
}
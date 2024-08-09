// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

/**
 * @title OracleLib
 * @author Chukwubuike Victory Chime aka yeahChibyke
 * @notice This library is used to check the Chainlink oracle for stale data. It is designed such that if a price is stale, the function wil revert and the YeahDollarEngine will be rendered unusable
 *
 * If the Chainlink network is attacked, all user funds locked in the protocol will result in a state of 😬😱
 */
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StaleData();

    uint256 private constant TIMEOUT = 1 hours; // I am hardcoding this. I should find a way to get this automatically

    function staleDataCheck(AggregatorV3Interface priceFeed)
        internal
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;

        if (secondsSince > TIMEOUT) revert OracleLib__StaleData();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}

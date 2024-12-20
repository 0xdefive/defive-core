// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import { IDeFiveFactory } from "./interfaces/IDeFiveFactory.sol";
import { IDeFivePair } from "./interfaces/IDeFivePair.sol";
import { DeFivePair } from "./DeFivePair.sol";

contract DeFiveFactory is IDeFiveFactory {
    bytes32 public constant PAIR_HASH = keccak256(type(DeFivePair).creationCode);

    address public override feeToDevs;
    address public override feeToGbm;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    modifier onlyFeeToSetter() {
        require(msg.sender == feeToSetter, "DeFive: FORBIDDEN");
        _;
    }

    constructor(address _feeToSetter, address _feeToDevs, address _feeToGbm) {
        require(
            _feeToSetter != address(0) && _feeToDevs != address(0) && _feeToGbm != address(0),
            "DeFive: ZERO_ADDRESS"
        );
        feeToSetter = _feeToSetter;
        feeToDevs = _feeToDevs;
        feeToGbm = _feeToGbm;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB && tokenA != address(0) && tokenB != address(0), "DeFive: INVALID_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(getPair[token0][token1] == address(0), "DeFive: PAIR_EXISTS");
        pair = address(new DeFivePair{ salt: keccak256(abi.encodePacked(token0, token1)) }());
        IDeFivePair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // Reverse mapping
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeToDevs, address _feeToGbm) external override onlyFeeToSetter {
        require(_feeToDevs != address(0) && _feeToGbm != address(0), "DeFive: ZERO_ADDRESS");
        feeToDevs = _feeToDevs;
        feeToGbm = _feeToGbm;

        emit SetFeeTo(msg.sender, _feeToDevs, _feeToGbm);
    }

    function setFeeToSetter(address _feeToSetter) external override onlyFeeToSetter {
        require(_feeToSetter != address(0), "DeFive: ZERO_ADDRESS");
        feeToSetter = _feeToSetter;

        emit SetFeeToSetter(msg.sender, _feeToSetter);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import { IDeFiveFactory } from "./interfaces/IDeFiveFactory.sol";
import { IDeFivePair } from "./interfaces/IDeFivePair.sol";
import { DeFivePair } from "./DeFivePair.sol";

contract DeFiveFactory is IDeFiveFactory {
    bytes32 public constant PAIR_HASH = keccak256(type(DeFivePair).creationCode);

    address public override feeToDevs;
    address public override feeToGbm;
    address public override feeToDevsSetter;
    address public override feeToGbmSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    modifier onlyFeeToDevsSetter() {
        require(msg.sender == feeToDevsSetter, "DeFive: FORBIDDEN");
        _;
    }
    modifier onlyFeeToGbmSetter() {
        require(msg.sender == feeToGbmSetter, "DeFive: FORBIDDEN");
        _;
    }

    constructor(address _feeToDevsSetter, address _feeToGbmSetter, address _feeToDevs, address _feeToGbm) {
        require(
            _feeToDevsSetter != address(0) &&
                _feeToGbmSetter != address(0) &&
                _feeToDevs != address(0) &&
                _feeToGbm != address(0),
            "DeFive: ZERO_ADDRESS"
        );
        feeToDevsSetter = _feeToDevsSetter;
        feeToGbmSetter = _feeToGbmSetter;
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

    function setFeeToDevs(address _feeToDevs) external override onlyFeeToDevsSetter {
        require(_feeToDevs != address(0), "DeFive: ZERO_ADDRESS");
        feeToDevs = _feeToDevs;
        emit SetFeeToDevs(msg.sender, _feeToDevs);
    }

    function setFeeToGbm(address _feeToGbm) external override onlyFeeToGbmSetter {
        require(_feeToGbm != address(0), "DeFive: ZERO_ADDRESS");
        feeToGbm = _feeToGbm;
        emit SetFeeToGbm(msg.sender, _feeToGbm);
    }

    function setFeeToDevsSetter(address _feeToDevsSetter) external override onlyFeeToDevsSetter {
        require(_feeToDevsSetter != address(0), "DeFive: ZERO_ADDRESS");
        feeToDevsSetter = _feeToDevsSetter;

        emit SetFeeToDevsSetter(msg.sender, _feeToDevsSetter);
    }

    function setFeeToGbmSetter(address _feeToGbmSetter) external override onlyFeeToGbmSetter {
        require(_feeToGbmSetter != address(0), "DeFive: ZERO_ADDRESS");
        feeToGbmSetter = _feeToGbmSetter;

        emit SetFeeToGbmSetter(msg.sender, _feeToGbmSetter);
    }
}

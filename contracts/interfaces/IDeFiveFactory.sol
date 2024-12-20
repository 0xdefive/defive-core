// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

interface IDeFiveFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    event SetFeeTo(address indexed sender, address indexed feeToDevs, address indexed feeToGbm);

    event SetFeeToSetter(address indexed sender, address indexed feeToSetter);

    function feeToDevs() external view returns (address);

    function feeToGbm() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address _feeToDevs, address _feeToGbm) external;

    function setFeeToSetter(address _feeToSetter) external;
}

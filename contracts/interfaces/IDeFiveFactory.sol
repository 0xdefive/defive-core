// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

interface IDeFiveFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    event SetFeeToDevs(address indexed sender, address indexed feeToDevs);

    event SetFeeToGbm(address indexed sender, address indexed feeToGbm);

    event SetFeeToDevsSetter(address indexed sender, address indexed feeToDevsSetter);

    event SetFeeToGbmSetter(address indexed sender, address indexed feeToGbmSetter);

    function feeToDevs() external view returns (address);

    function feeToGbm() external view returns (address);

    function feeToDevsSetter() external view returns (address);

    function feeToGbmSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeToDevs(address _feeToDevs) external;

    function setFeeToGbm(address _feeToGbm) external;

    function setFeeToDevsSetter(address _feeToDevsSetter) external;

    function setFeeToGbmSetter(address _feeToGbmSetter) external;
}

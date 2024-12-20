// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

interface IDeFiveCallee {
    function deFiveCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

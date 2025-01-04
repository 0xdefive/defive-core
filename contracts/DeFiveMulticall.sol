// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

contract DeFiveMulticall {
    struct Call {
        address target;
        bytes callData;
    }
    struct Result {
        bool success;
        bytes returnData;
    }

    uint256 constant MAX_CALLS = 500; // Maximum number of calls to prevent excessive gas usage

    function aggregate(Call[] memory calls) external returns (uint256 blockNumber, bytes[] memory returnData) {
        require(calls.length <= MAX_CALLS, "Multicall: too many calls");
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(
                success,
                string(
                    abi.encodePacked(
                        "Multicall aggregate: call to ",
                        toString(calls[i].target),
                        " failed with data ",
                        toHex(calls[i].callData)
                    )
                )
            );
            returnData[i] = ret;
        }
    }

    function blockAndAggregate(
        Call[] memory calls
    ) public returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData) {
        require(calls.length <= MAX_CALLS, "Multicall: too many calls");
        (blockNumber, blockHash, returnData) = tryBlockAndAggregate(true, calls);
    }

    function getBlockHash(uint256 blockNumber) public view returns (bytes32 blockHash) {
        blockHash = blockhash(blockNumber);
    }

    function getBlockNumber() public view returns (uint256 blockNumber) {
        blockNumber = block.number;
    }

    function getCurrentBlockCoinbase() public view returns (address coinbase) {
        coinbase = block.coinbase;
    }

    function getCurrentBlockDifficulty() public view returns (uint256 difficulty) {
        difficulty = block.difficulty;
    }

    function getCurrentBlockGasLimit() public view returns (uint256 gaslimit) {
        gaslimit = block.gaslimit;
    }

    function getCurrentBlockTimestamp() public view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }

    function getSBalance(address addr) public view returns (uint256 balance) {
        balance = addr.balance;
    }

    function getLastBlockHash() public view returns (bytes32 blockHash) {
        // Remember that blockhash only works for the most recent 256 blocks.
        // For older blocks, this will return zero.
        blockHash = blockhash(block.number - 1);
    }

    function tryAggregate(bool requireSuccess, Call[] memory calls) public returns (Result[] memory returnData) {
        require(calls.length <= MAX_CALLS, "Multicall: too many calls");
        returnData = new Result[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);

            if (requireSuccess) {
                require(
                    success,
                    string(
                        abi.encodePacked(
                            "Multicall aggregate: call to ",
                            toString(calls[i].target),
                            " failed with data ",
                            toHex(calls[i].callData)
                        )
                    )
                );
            }

            returnData[i] = Result(success, ret);
        }
    }

    function tryBlockAndAggregate(
        bool requireSuccess,
        Call[] memory calls
    ) public returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData) {
        require(calls.length <= MAX_CALLS, "Multicall: too many calls");
        blockNumber = block.number;
        blockHash = blockhash(block.number);
        returnData = tryAggregate(requireSuccess, calls);
    }

    function toString(address account) internal pure returns (string memory) {
        return toHex(abi.encodePacked(account));
    }

    function toHex(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}

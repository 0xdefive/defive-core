// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import { IDeFiveFactory } from "./interfaces/IDeFiveFactory.sol";
import { IDeFiveRouter } from "./interfaces/IDeFiveRouter.sol";
import { IDeFivePair } from "./interfaces/IDeFivePair.sol";
import { IDeFiveToken } from "./interfaces/IDeFiveToken.sol";
import { IWS } from "./interfaces/IWS.sol";
import { TransferHelper } from "./libraries/TransferHelper.sol";
import { DeFiveLibrary } from "./libraries/DeFiveLibrary.sol";

contract DeFiveRouter is IDeFiveRouter {
    address public immutable override factory;
    address public immutable override wS;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "DeFiveRouter: EXPIRED");
        _;
    }

    constructor(address _factory, address _wS) {
        factory = _factory;
        wS = _wS;
    }

    receive() external payable {
        assert(msg.sender == wS); // only accept S via fallback from the wS contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IDeFiveFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IDeFiveFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = DeFiveLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = DeFiveLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "DeFiveRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = DeFiveLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "DeFiveRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = DeFiveLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IDeFivePair(pair).mint(to);
    }

    function addLiquidityS(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountSMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountS, uint256 liquidity)
    {
        (amountToken, amountS) = _addLiquidity(token, wS, amountTokenDesired, msg.value, amountTokenMin, amountSMin);
        address pair = DeFiveLibrary.pairFor(factory, token, wS);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWS(wS).deposit{ value: amountS }();
        assert(IWS(wS).transfer(pair, amountS));
        liquidity = IDeFivePair(pair).mint(to);
        // refund dust S, if any
        if (msg.value > amountS) TransferHelper.safeTransferS(msg.sender, msg.value - amountS);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = DeFiveLibrary.pairFor(factory, tokenA, tokenB);
        IDeFivePair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IDeFivePair(pair).burn(to);
        (address token0, ) = DeFiveLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "DeFiveRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "DeFiveRouter: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityS(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountSMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountS) {
        (amountToken, amountS) = removeLiquidity(
            token,
            wS,
            liquidity,
            amountTokenMin,
            amountSMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWS(wS).withdraw(amountS);
        TransferHelper.safeTransferS(to, amountS);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = DeFiveLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;

        // Use permit to allow the router to spend liquidity tokens
        IDeFivePair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);

        // Call standard removeLiquidity function
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquiditySWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountSMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountS) {
        address pair = DeFiveLibrary.pairFor(factory, token, wS);
        uint256 value = approveMax ? type(uint256).max : liquidity;

        // Use permit to allow the router to spend liquidity tokens
        IDeFivePair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);

        // Call standard removeLiquidityS function
        (amountToken, amountS) = removeLiquidityS(token, liquidity, amountTokenMin, amountSMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquiditySSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountSMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountS) {
        (, amountS) = removeLiquidity(token, wS, liquidity, amountTokenMin, amountSMin, address(this), deadline);
        TransferHelper.safeTransfer(token, to, IDeFiveToken(token).balanceOf(address(this)));
        IWS(wS).withdraw(amountS);
        TransferHelper.safeTransferS(to, amountS);
    }

    function removeLiquiditySWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountSMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountS) {
        address pair = DeFiveLibrary.pairFor(factory, token, wS);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IDeFivePair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountS = removeLiquiditySSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountSMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = DeFiveLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2 ? DeFiveLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IDeFivePair(DeFiveLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = DeFiveLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "DeFiveRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DeFiveLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = DeFiveLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "DeFiveRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DeFiveLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactSForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == wS, "DeFiveRouter: INVALID_PATH");
        amounts = DeFiveLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "DeFiveRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWS(wS).deposit{ value: amounts[0] }();
        assert(IWS(wS).transfer(DeFiveLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactS(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == wS, "DeFiveRouter: INVALID_PATH");
        amounts = DeFiveLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "DeFiveRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DeFiveLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWS(wS).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferS(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForS(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == wS, "DeFiveRouter: INVALID_PATH");
        amounts = DeFiveLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "DeFiveRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DeFiveLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWS(wS).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferS(to, amounts[amounts.length - 1]);
    }

    function swapSForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == wS, "DeFiveRouter: INVALID_PATH");
        amounts = DeFiveLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "DeFiveRouter: EXCESSIVE_INPUT_AMOUNT");
        IWS(wS).deposit{ value: amounts[0] }();
        assert(IWS(wS).transfer(DeFiveLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust S, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferS(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = DeFiveLibrary.sortTokens(input, output);
            IDeFivePair pair = IDeFivePair(DeFiveLibrary.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                amountInput = IDeFiveToken(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = DeFiveLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOutput)
                : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? DeFiveLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DeFiveLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint256 balanceBefore = IDeFiveToken(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IDeFiveToken(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "DeFiveRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactSForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == wS, "DeFiveRouter: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWS(wS).deposit{ value: amountIn }();
        assert(IWS(wS).transfer(DeFiveLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint256 balanceBefore = IDeFiveToken(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IDeFiveToken(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            "DeFiveRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForSSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == wS, "DeFiveRouter: INVALID_PATH");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            DeFiveLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IDeFiveToken(wS).balanceOf(address(this));
        require(amountOut >= amountOutMin, "DeFiveRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWS(wS).withdraw(amountOut);
        TransferHelper.safeTransferS(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure virtual override returns (uint256 amountB) {
        return DeFiveLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountOut) {
        return DeFiveLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountIn) {
        return DeFiveLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) public view virtual override returns (uint256[] memory amounts) {
        return DeFiveLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(
        uint256 amountOut,
        address[] memory path
    ) public view virtual override returns (uint256[] memory amounts) {
        return DeFiveLibrary.getAmountsIn(factory, amountOut, path);
    }
}

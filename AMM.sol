// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AMM is AccessControl{
    bytes32 public constant LP_ROLE = keccak256("LP_ROLE");
	uint256 public invariant;
	address public tokenA;
	address public tokenB;
	uint256 feebps = 3;

	event Swap( address indexed _inToken, address indexed _outToken, uint256 inAmt, uint256 outAmt );
	event LiquidityProvision( address indexed _from, uint256 AQty, uint256 BQty );
	event Withdrawal( address indexed _from, address indexed recipient, uint256 AQty, uint256 BQty );

    constructor( address _tokenA, address _tokenB ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender );
        _grantRole(LP_ROLE, msg.sender);

		require( _tokenA != address(0), 'Token address cannot be 0' );
		require( _tokenB != address(0), 'Token address cannot be 0' );
		require( _tokenA != _tokenB, 'Tokens cannot be the same' );
		tokenA = _tokenA;
		tokenB = _tokenB;
    }

	function getTokenAddress( uint256 index ) public view returns(address) {
		require( index < 2, 'Only two tokens' );
		if( index == 0 ) {
			return tokenA;
		} else {
			return tokenB;
		}
	}

	function tradeTokens( address sellToken, uint256 sellAmount ) public {
		require( invariant > 0, 'Invariant must be nonzero' );
		require( sellToken == tokenA || sellToken == tokenB, 'Invalid token' );
		require( sellAmount > 0, 'Cannot trade 0' );
		require( invariant > 0, 'No liquidity' );
		uint256 qtyA;
		uint256 qtyB;
		uint256 swapAmt;

		uint256 effectiveSell = sellAmount * (10000 - feebps) / 10000;

		if (sellToken == tokenA) {
			qtyA = ERC20(tokenA).balanceOf(address(this));
			qtyB = ERC20(tokenB).balanceOf(address(this));
			swapAmt = qtyB - (invariant / (qtyA + effectiveSell));
			ERC20(tokenA).transferFrom(msg.sender, address(this), sellAmount);
			ERC20(tokenB).transfer(msg.sender, swapAmt);
			emit Swap(tokenA, tokenB, sellAmount, swapAmt);
		} else {
			qtyA = ERC20(tokenA).balanceOf(address(this));
			qtyB = ERC20(tokenB).balanceOf(address(this));
			swapAmt = qtyA - (invariant / (qtyB + effectiveSell));
			ERC20(tokenB).transferFrom(msg.sender, address(this), sellAmount);
			ERC20(tokenA).transfer(msg.sender, swapAmt);
			emit Swap(tokenB, tokenA, sellAmount, swapAmt);
		}

		uint256 new_invariant = ERC20(tokenA).balanceOf(address(this))*ERC20(tokenB).balanceOf(address(this));
		require( new_invariant >= invariant, 'Bad trade' );
		invariant = new_invariant;
	}

	function provideLiquidity( uint256 amtA, uint256 amtB ) public {
		require( amtA > 0 || amtB > 0, 'Cannot provide 0 liquidity' );
		if (amtA > 0) {
			ERC20(tokenA).transferFrom(msg.sender, address(this), amtA);
		}
		if (amtB > 0) {
			ERC20(tokenB).transferFrom(msg.sender, address(this), amtB);
		}
		invariant = ERC20(tokenA).balanceOf(address(this)) * ERC20(tokenB).balanceOf(address(this));
		emit LiquidityProvision( msg.sender, amtA, amtB );
	}

	function withdrawLiquidity( address recipient, uint256 amtA, uint256 amtB ) public onlyRole(LP_ROLE) {
		require( amtA > 0 || amtB > 0, 'Cannot withdraw 0' );
		require( recipient != address(0), 'Cannot withdraw to 0 address' );
		if( amtA > 0 ) {
			ERC20(tokenA).transfer(recipient,amtA);
		}
		if( amtB > 0 ) {
			ERC20(tokenB).transfer(recipient,amtB);
		}
		invariant = ERC20(tokenA).balanceOf(address(this))*ERC20(tokenB).balanceOf(address(this));
		emit Withdrawal( msg.sender, recipient, amtA, amtB );
	}
}
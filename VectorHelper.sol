pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT
import "./Ownable.sol";

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function decimals() external view returns (uint8);
}

/**
 * @dev Address Router
 * Instantly query address saved
 */
interface IAddressRouter {
    function viewAddressDirectory(string memory _name)
        external
        view
        returns (address);
}

interface IVector {
    function deposit(uint256 _amount) external;

    function balanceOf(address _address) external view returns (uint256);

    function withdraw(uint256 amount) external;

    function multiclaim(address[] calldata _lps, address user_address) external;
}

interface IVectorSingle {
    function balance(address _address) external view returns (uint256);

    function withdraw(uint256 _amount, uint256 _minAmount) external;
}

/**
 * @dev Vector Helper
 * Houses our custom withdrawal, deposit and rewards functionality w/
 * implemented safe guards and checks
 *
 * NOTE: Interface will contain standalone address where it will be stored in a constants address
 */
contract VectorHelper is Ownable {
    address private addressRouter;

    constructor(address _addressRouter) {
        addressRouter = _addressRouter;
    }

    /*
     * Deposit for Single-Sided Staking
     * _amount - actual token (USDC, BTCB) to deposit
     * _tokenAddress - contract of corresponding token ^
     * _spender - that will move tokens into deposit pool
     * _investmetnAddress - the corresponding staking contract
     * NOTE: Aimed at PTP
     */
    function depositSingle(
        uint256 _amount,
        address _tokenAddress,
        address _spender,
        address _investmentAddress
    ) public {
        uint256 permittedFunds = IERC20(_tokenAddress).allowance(
            address(this),
            _spender
        );
        if (
            permittedFunds !=
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        ) {
            IERC20(_tokenAddress).approve(
                _spender,
                115792089237316195423570985008687907853269984665640564039457584007913129639935
            );
        }
        IVector(_investmentAddress).deposit(_amount);
    }

    /*
     * Deposit for Avax LP
     * _amount - actual token (USDC, BTCB) to deposit
     * _tokenAddress - contract of corresponding token ^
     * _spender - that will move tokens into deposit pool
     * _investmetnAddress - the corresponding staking contract
     * NOTE: Aimed at PTP
     */
    function depositLPNative(
        uint256 _lpAmount,
        address _lpAddress,
        address _spender,
        address _investmentAddress
    ) public payable {
        require(_lpAmount > 0, "LP Amount is Equal to Zero.");
        checkAllowance(_lpAddress, _spender);
        IVector(_investmentAddress).deposit(_lpAmount);
    }

    /*
     * @dev Withdraw from Single-Sided Staking
     * _amount, _minAmount - amount request & min willing to accept
     * _investmentAddress - For Vector, Staking Address
     * NOTE: Error -> 'Amount Too Low' means higher slippage
     *
     */
    function withdrawSingle(
        uint256 _amount,
        uint256 _minAmount,
        address _investmentAddress
    ) public {
        IVectorSingle(_investmentAddress).withdraw(_amount, _minAmount);
    }

    /*
     * @dev Claim Rewards from Single Sided Pools
     * _lps - array containing where the LP token is stored
     * _beneficiary - our smart contract
     * _investmentAddress - For Vector, Staking Address
     * NOTE: See if withdraw 0 value performs same action
     *
     */
    function claimSingle(
        address[] memory _lps,
        address _beneficiary,
        address _investmentAddress
    ) public {
        IVector(_investmentAddress).multiclaim(_lps, _beneficiary);
    }

    /*
     * @dev Claim Rewards from AVAX-backed LP
     * _lps - array containing where the LP token is stored
     * _beneficiary - our smart contract
     * _investmentAddress - For Vector, Staking Address
     * NOTE: See if withdraw 0 value performs same action
     *
     */
    function claimLpAvax(
        address[] memory _lps,
        address _beneficiary,
        address _investmentAddress
    ) public {
        IVector(_investmentAddress).multiclaim(_lps, _beneficiary);
    }

    /*
     * @dev Withdraw LP
     * _amount - lp amount
     * _investmentAddress - For Vector, Staking Address
     */
    function withdrawLp(uint256 _amount, address _investmentAddress) public {
        require(_amount > 0, "Amount to WithdrawLp is equal to zero.");
        IVector(_investmentAddress).withdraw(_amount);
    }

    /*
     * @dev viewInvestment Balance
     * _investmentAddress - For Vector, Staking Address
     * _walletAddress - Smart contract address due to association
     */
    function viewInvestmentBalance(
        address _investmentAddress,
        address _walletAddress
    ) public view returns (uint256) {
        uint256 bal = IVector(_investmentAddress).balanceOf(_walletAddress);
        return bal;
    }

    /*
     * QueryInvestmentBalance
     * @notice May deprecate
     *
     */
    function queryInvestmentBalance(
        address _investmentAddress,
        address _walletAddress
    ) public view returns (uint256) {
        uint256 bal = IVectorSingle(_investmentAddress).balance(_walletAddress);
        return bal;
    }

    /**
     * @dev Check Allowance
     * _tokenAddress - address needing approval
     * _spender - address receiving permission
     * Checks to make sure contract has extended permissions to other contracts
     * @notice Same function in Investor Helper, placed here for in-house convenience
     */
    function checkAllowance(address _tokenAddress, address _spender) public {
        uint256 permittedFunds = IERC20(_tokenAddress).allowance(
            address(this),
            _spender
        );
        if (
            permittedFunds !=
            115792089237316195423570985008687907853269984665640564039457584007913129639935
        ) {
            IERC20(_tokenAddress).approve(
                _spender,
                115792089237316195423570985008687907853269984665640564039457584007913129639935
            );
        }
    }
}

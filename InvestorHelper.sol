// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";

interface IAddressRouter {
    function viewAddressDirectory(string memory _name)
        external
        view
        returns (address);
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function decimals() external view returns (uint8);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function withdraw(uint256) external;

    function totalSupply() external view returns (uint256);
}

interface IJoeRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForAVAX(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactAVAXForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] memory path)
        external
        view
        returns (uint256[] memory amounts);

    function addLiquidityAVAX(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountAVAXMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountAVAX,
            uint256 liquidity
        );

    function removeLiquidityAVAXWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountAVAXMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountAVAX);

    function factory() external view returns (address);
}

interface IStakingManager {
    function bankCut() external view returns (uint256);

    function poolStakers(uint256 _poolId, address _wallet)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    function pools(uint256 _poolId)
        external
        view
        returns (
            address,
            uint256,
            uint256
        );

    function deposit(
        uint256 _poolId,
        uint256 _amount,
        uint256 _rewards
    ) external;

    function withdraw(
        uint256 _poolId,
        uint256 _withdrawal,
        uint256 _rewards
    ) external;
}

contract InvestorHelper is Ownable {
    /*
     * 1.
     * Router Settings - permanent address delegatecalled to here
     */
    address public addressRouter;
    /*
     * 2.
     * StakingManager - Contract address to handle accounting
     */
    address public stakingManager;
    /*
     * 3.
     * @dev Helper Router points to the address containing the helper contract
     */
    address payable public helperRouter;
    /*
     * 4.
     * @dev Swap Router points to the address containing swap operations
     */
    address payable public swapRouter;
    /*
     * 5.
     * Target Token Settings [0] pair, [1] avax
     */
    address[] public targetToken;
    /*
     * 6.
     * Investment Address - staking contract
     */
    address payable public investmentAddress;
    /*
     * 7.
     * Liquidity Pool - Address where pair is held
     */
    address payable public liquidityPool;
    /*
     * 8.
     * @dev Tokens to Be Rewarded by their Contract Address
     */
    address[] public tokensToBeRewardedAddress;
    /*
     * 9.
     * @dev Token Names - Helps determine source
     *
     */
    string[] public tokensToBeRewardedName;

    /*
     * 10.
     * Rewards Snapshot
     * @dev Contains the rewards received from pool
     */
    mapping(address => uint256) public rewardSnapshot;

    /*
     * 11.
     * APR Tracker
     * @dev Contains the rewards received from pool
     */
    uint256 public aprTracker;

    /*
     * 12.
     * Last Claim
     * @dev Saves the timestamp for last time owner made a rewards claim
     * NOTE: Prevents abusive accounts from timing their account deposits with
     * rewards claims
     */
    uint256 public lastClaim;

    /*
     * 13.
     * Investor Helper
     * @dev Tools like accounting and calc commission
     */
    address public investorHelper;

    /*
     * 14.
     * @dev poolId that communicates where amount and rewards are stored
     *      in StakingManager contract
     */
    uint256 public poolId;

    /*
     * 15.
     * Mutex
     * @dev Prevents reentry on withdrawal
     */
    bool public mutex;

    /*
     * 16.
     * paused
     * @dev Pauses contract for maintenance
     */
    bool public paused;

    constructor(address _addressRouter) {
        addressRouter = _addressRouter;
    }

    /**
     * @dev Reinvest LP
     * Reinvest Rewards Back into LP
     * @notice Before swap, will check if reward amount is enough to swap for big
     *         tokens like BTC. Will use getExchangeRate to determine
     *         if I can get anything for my trade.
     */

    function reinvestAvaxLP(
        address[] memory _targetToken,
        address[] memory _rewardToken,
        address _spenderAddress
    ) public payable returns (uint256) {
        address avaxAddress = IAddressRouter(addressRouter)
            .viewAddressDirectory("AVAX");
        address swapSpender = IAddressRouter(addressRouter)
            .viewAddressDirectory("SwapRouterSpender");
        uint256 initAvaxBal = payable(address(this)).balance;
        // Loop thru each reward address to swap for lp pair

        for (uint256 i = 0; i < _rewardToken.length; i++) {
            uint256 rewardBal = IERC20(_rewardToken[i]).balanceOf(
                address(this)
            );
            if (rewardBal != 0) {
                checkAllowance(_rewardToken[i], swapSpender);
                rewardBal = rewardBal / 2;
                //Swap Reward for Token, Pair 1*
                uint256 arrLen;
                _rewardToken[i] == avaxAddress ? arrLen = 2 : arrLen = 3;
                // Make sure reward token is not avax
                if (_rewardToken[i] != avaxAddress) {
                    address[] memory pathToken = new address[](arrLen);
                    pathToken[0] = _rewardToken[i];
                    pathToken[1] = avaxAddress;
                    pathToken[2] = _targetToken[0];
                    // To prevent rewardSellAmount being so small, I can't exchange it for any BTC as ex.
                    uint256 rewardSellAmount = setSlippage(
                        getExchangeRate(rewardBal, pathToken)[2],
                        95
                    );
                    if (rewardSellAmount > 0) {
                        swapExactTokenForToken(
                            rewardBal,
                            setSlippage(
                                getExchangeRate(rewardBal, pathToken)[2],
                                95
                            ),
                            _targetToken[0], //Pair 1
                            pathToken[0] //Reward Token
                        );
                    }
                    //if reward token is avax
                } else {
                    address[] memory pathToken = new address[](arrLen);
                    pathToken[0] = _rewardToken[i];
                    pathToken[1] = _targetToken[0];
                    uint256 rewardSellAmount = setSlippage(
                        getExchangeRate(rewardBal, pathToken)[1],
                        95
                    );
                    if (rewardSellAmount > 0) {
                        swapExactTokenForToken(
                            rewardBal,
                            rewardSellAmount,
                            _targetToken[0],
                            pathToken[0]
                        );
                    }
                }
                //Swap Reward for AVAX*
                // If rewardToken != WAVAX, Swap
                if (_rewardToken[i] != avaxAddress) {
                    address[] memory pathAvax = new address[](2);
                    pathAvax[0] = _rewardToken[i];
                    pathAvax[1] = avaxAddress;
                    uint256 rewardSellAmount = setSlippage(
                        getExchangeRate(rewardBal, pathAvax)[1],
                        95
                    );
                    if (rewardSellAmount > 0) {
                        (bool success, bytes memory data) = swapRouter
                            .delegatecall(
                                abi.encodeWithSignature(
                                    "exchangeExactTokensForAvax(uint256,uint256,address)",
                                    rewardBal,
                                    rewardSellAmount,
                                    _rewardToken[i]
                                )
                            );
                        require(
                            success,
                            "Delegate Call Swapping Tokens for Avax Failed."
                        );
                    }
                    //If reward token = WAVAX, unwrap it for AVAX
                } else {
                    IERC20(avaxAddress).withdraw(rewardBal);
                }
            }
        }

        uint256 earnedAvax = payable(address(this)).balance - initAvaxBal;
        uint256 lpBalBefore = IERC20(liquidityPool).balanceOf(address(this));
        //How much is earned avax and BTC. If detect zero, avoid function

        addLiquidity(targetToken[0], targetToken[1], earnedAvax);

        uint256 lPBalInHelperBefore = IERC20(investmentAddress).balanceOf(
            address(this)
        );

        uint256 earnedLp = IERC20(liquidityPool).balanceOf(address(this)) -
            lpBalBefore;

        if (earnedLp > 0) {
            depositLpTokensNative(_spenderAddress);
        }

        uint256 earnedLpInHelper = IERC20(investmentAddress).balanceOf(
            address(this)
        );

        return earnedLpInHelper - lPBalInHelperBefore;
    }

    /**
     * @dev Grabs TJ LP tokens and puts them in corresponding helper
     */
    function depositLpTokensNative(address _spender) internal {
        (bool success, bytes memory data) = helperRouter.delegatecall(
            abi.encodeWithSignature(
                "depositLPNative(uint256,address,address,address)",
                IERC20(liquidityPool).balanceOf(address(this)),
                liquidityPool,
                _spender,
                investmentAddress
            )
        );
        require(success, "depositLPNative helper call failed.");
    }

    /**
     * @dev Add Liquidity
     * _pair1Token & pair2Token - address for LP Pair Tokens
     * _slippage - sets min value in transaction
     */
    function addLiquidity(
        address _pair1Token,
        address _pair2Token,
        uint256 _avaxAmount
    ) public payable {
        //Determine whether its avax or not
        address avaxAddress = IAddressRouter(addressRouter)
            .viewAddressDirectory("AVAX");
        uint256 pair1Amount = IERC20(_pair1Token).balanceOf(address(this));
        if (_pair2Token == avaxAddress && _avaxAmount > 0) {
            uint256 pair2Amount = _avaxAmount;
            uint256 pair1AmountSlip = setSlippage(pair1Amount, 90);
            uint256 pair2AmountSlip = setSlippage(pair2Amount, 90);
            if (pair1AmountSlip > 0 && pair2AmountSlip > 0) {
                (bool success, bytes memory data) = swapRouter.delegatecall(
                    abi.encodeWithSignature(
                        "addLiquidityAvax(address,uint256,uint256,uint256,uint256)",
                        _pair1Token,
                        pair1Amount,
                        pair1AmountSlip,
                        pair2Amount,
                        pair2AmountSlip
                    )
                );
                require(success, "DC to Adding AVAX Liquidity Failed.");
                (uint256 amount1, uint256 amount2, uint256 liquidity) = abi
                    .decode(data, (uint256, uint256, uint256));
            }
        }
    }

    /**
     * @dev Set Slippage
     * returns a discounted version of intial amount
     */
    function setSlippage(uint256 _amount, uint256 _slippage)
        internal
        pure
        returns (uint256)
    {
        return ((((_amount * 100) / 100) * _slippage) / 100);
    }

    /**
     * @dev getExchangeRate
     * returns an exchang rate from swap helper on specified token
     */
    function getExchangeRate(uint256 _amountIn, address[] memory _tokenPath)
        public
        payable
        returns (uint256[] memory)
    {
        (bool success, bytes memory data) = swapRouter.delegatecall(
            abi.encodeWithSignature(
                "calculateExchangeRate(uint256,address[])",
                _amountIn,
                _tokenPath
            )
        );
        uint256[] memory exchangeRate = abi.decode(data, (uint256[]));
        return exchangeRate;
    }

    /**
     * @dev swapExactTokenForAvax
     * Swaps tokens for avax
     * _amountIn - min sell amount
     * _amountOutMin - min buy amount
     * _sellCurrency - sell token address
     */
    function swapExactTokenForAvax(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _sellCurrency
    ) public payable {
        //Claim Rewards
        (bool success, bytes memory data) = swapRouter.delegatecall(
            abi.encodeWithSignature(
                "exchangeExactTokensForAvax(uint256,uint256,address)",
                _amountIn,
                _amountOutMin,
                _sellCurrency
            )
        );
        require(success, "Delegate Call Swapping Tokens for Avax Failed.");
    }

    /**
     * @dev swapExactTokenForToken
     * Swaps tokens for avax
     * _amountIn - min sell amount
     * _amountOutMin - min buy amount
     * _buyCurrency - buy token address
     * _sellCurrency - sell token address
     */
    function swapExactTokenForToken(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _buyCurrency,
        address _sellCurrency
    ) internal {
        //Claim Rewards
        (bool success, bytes memory data) = swapRouter.delegatecall(
            abi.encodeWithSignature(
                "exchangeExactTokensForTokens(uint256,uint256,address,address)",
                _amountIn,
                _amountOutMin,
                _buyCurrency,
                _sellCurrency
            )
        );
        require(success, "Delegate Call To Swap Tokens for Tokens Failed.");
    }

    function swapExactAvaxForToken(
        uint256 _amountOutMin,
        uint256 _avaxAmount,
        address _buyTokenContract
    ) public payable {
        (bool success, bytes memory data) = swapRouter.delegatecall(
            abi.encodeWithSignature(
                "exchangeExactAvaxForTokens(uint256,uint256,address)",
                _amountOutMin,
                _avaxAmount,
                _buyTokenContract
            )
        );
        require(success, "Delegeate Call To Swap Avax for Tokens Failed.");
    }

    /**
     * @dev Check Allowance
     * _tokenAddress - address needing approval
     * _spender - address receiving permission
     * Checks to make sure contract has extended permissions to other contracts
     */
    function checkAllowance(address _tokenAddress, address _spender) internal {
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

    function routerWithdraw1(uint256 _amount, address _spenderAddress)
        public
        payable
        verifyPool
    {
        require(paused == false, "Contract is Paused.");
        require(mutex == false, "Reentry Detected");
        require(_amount > 0, "Withdraw Amount Equal to Zero.");
        (uint256 stakerAmount, uint256 stakerReward, ) = IStakingManager(
            stakingManager
        ).poolStakers(poolId, msg.sender);
        require(stakerAmount + stakerReward >= _amount);

        //mutex = true;
        //1. Withdraw Specified Amount of LP Tokens
        uint256 initLpBal = IERC20(investmentAddress).balanceOf(address(this));
        (bool successWithdraw, ) = helperRouter.delegatecall(
            abi.encodeWithSignature(
                "withdrawLp(uint256,address)",
                _amount,
                investmentAddress
            )
        );
        require(successWithdraw, "Delegate Call Withdrawing from Lp Failed.");
        uint256 differenceBal = initLpBal -
            IERC20(investmentAddress).balanceOf(address(this));
        //Remove Liquidity from Pool
        // a. Calculate number of pair 1 and pair 2 tokens to request at swap
        uint256 PRECISION = 1e12;

        uint256 token0Entitlement = setSlippage(
            (((differenceBal * PRECISION) /
                IERC20(liquidityPool).totalSupply()) *
                IERC20(targetToken[0]).balanceOf(liquidityPool)) / PRECISION,
            98
        );
        uint256 token1Entitlement = setSlippage(
            (((differenceBal * PRECISION) /
                IERC20(liquidityPool).totalSupply()) *
                IERC20(targetToken[1]).balanceOf(liquidityPool)) / PRECISION,
            98
        );
        // b. Using calculated values, request withdrawal of both tokens
        (bool successRemove, ) = swapRouter.delegatecall(
            abi.encodeWithSignature(
                "removeAvaxLiquidity(address,address,uint256,uint256,uint256)",
                targetToken[0],
                liquidityPool,
                differenceBal,
                token0Entitlement,
                token1Entitlement
            )
        );
        require(
            successRemove == true,
            "Delegate Call Removing Liquidity Failed"
        );
        //3. Store New Reward Balances into rewardSnapshot
        for (uint8 i = 0; i < tokensToBeRewardedAddress.length; i++) {
            rewardSnapshot[tokensToBeRewardedAddress[i]] = IERC20(
                tokensToBeRewardedAddress[i]
            ).balanceOf(address(this));
        }
        //4. Transfer to Treasury
        for (uint8 i = 0; i < tokensToBeRewardedAddress.length; i++) {
            if (rewardSnapshot[tokensToBeRewardedAddress[i]] != 0) {
                IERC20(tokensToBeRewardedAddress[i]).transfer(
                    IAddressRouter(addressRouter).viewAddressDirectory(
                        "Treasury"
                    ),
                    rewardSnapshot[tokensToBeRewardedAddress[i]] /
                        IStakingManager(stakingManager).bankCut()
                );
            }
        }
        //5. Reinvest Rewards Back Into LP
        (bool successReinvest, bytes memory dataReinvest) = investorHelper
            .delegatecall(
                abi.encodeWithSignature(
                    "reinvestAvaxLP(address[],address[],address)",
                    targetToken,
                    tokensToBeRewardedAddress,
                    _spenderAddress
                )
            );

        require(successReinvest == true, "Delegate Call Reinvest to LP Failed");

        uint256 lpEarned = abi.decode(dataReinvest, (uint256));
        //6. Reinvest Rewards Back Into LP
        if (lastClaim + 1 days < block.timestamp) {
            aprTracker = lpEarned;
            lastClaim = block.timestamp;
        } else {
            aprTracker = aprTracker + lpEarned;
        }
        //7. Debit Withdrawal from Depositor via StakingManager
        IStakingManager(stakingManager).withdraw(
            poolId,
            differenceBal,
            lpEarned
        );

        mutex = false;
    }

    modifier verifyPool() {
        (address lp, , ) = IStakingManager(stakingManager).pools(poolId);
        require(
            lp == liquidityPool,
            "Pool on Staking Manager has not be created."
        );
        _;
    }

    fallback() external payable {}

    receive() external payable {}
}

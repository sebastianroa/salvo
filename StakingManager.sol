pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "./Ownable.sol";

/**
 *
 * @dev Staking Contract Adopts Implementations from MasterChef
 * @notice Any IERC20 functionalities (transfer, mint) have been disabled.
 *         Rather contract will serve as accounting arm to keep track which
 *         liquidity pools we have our funds staked.
 * @notice Whitelisted Investor Contract will handle IERC20 functions
 * @notice Instead of handing out rewards every block, Investor contract will
           insert collected reward amounts here manually via _rewards param
 */

contract StakingManager is Ownable {
    uint256 private constant REWARDS_PRECISION = 1e12; // A big number to perform mul and div operation

    // Commission Variables
    uint256 public referralCut;
    uint256 public partnerCut;
    uint256 public bankCut;

    // Staking user for a pool
    struct PoolStaker {
        uint256 amount; // The tokens quantity the user has staked.
        uint256 rewards; //Rewards collected
        uint256 rewardDebt; // The amount relative to accumulatedRewardsPerShare the user can't get as reward
    }

    // Staking pool
    struct Pool {
        address stakeToken; // Token to be staked
        uint256 tokensStaked; // Total tokens staked
        uint256 accumulatedRewardsPerShare; // Accumulated rewards per share times REWARDS_PRECISION
    }

    Pool[] public pools; // Staking pools
    address[] public registeredWalletArr; //Used to record all wallets for migration

    // Mapping poolId => staker address => PoolStaker
    mapping(uint256 => mapping(address => PoolStaker)) public poolStakers;
    // Mapping partner address => address[] wallets under his account
    mapping(address => address[]) public partnerWallets;
    // Mapping partner => if exists bool
    mapping(address => bool) public partner; //Individual onboarding clients
    // Mapping clientAddress => partnerAddress
    mapping(address => address) public client;
    // Mapping partnerAddress => beneficiaryAddress
    mapping(address => address) public partnerReferral; //Individual onboarding more partners
    // Mapping whitelistedContracts => bool
    mapping(address => bool) public whitelistedContracts;
    // Mapping wallets=>bool
    mapping(address => bool) public registeredWallet; //Instead of looping for wallet in arr, use this

    // Events
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );
    event HarvestRewards(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );
    event PoolCreated(uint256 poolId);
    event clientAdded(address indexed partner, address indexed client);
    event partnerAdded(address indexed beneficiary, address indexed newPartner);
    event partnerSwitched(address indexed newPartner, address indexed client);

    // Modifiers
    modifier onlyPartner() {
        require(partner[msg.sender] == true, "Access restricted to partners.");
        _;
    }

    modifier onlyWhitelisted() {
        require(
            whitelistedContracts[msg.sender] == true,
            "Access restricted to whitelisted contracts."
        );
        _;
    }

    // Constructor
    constructor() {
        //Integer is percentage representation (n/100)*cut
        referralCut = 10; //ex. 10%
        partnerCut = 33;
        bankCut = 25;
    }

    /**
     * @dev Create a new staking pool
     */
    function createPool(address _stakeToken) external onlyOwner {
        Pool memory pool;
        pool.stakeToken = _stakeToken;
        pools.push(pool);
        uint256 poolId = pools.length - 1;
        emit PoolCreated(poolId);
    }

    /**
     * @dev Deposit tokens to an existing pool
     */
    function deposit(
        uint256 _poolId,
        uint256 _amount,
        uint256 _rewards
    ) external onlyWhitelisted {
        require(_amount >= 0, "Deposit amount can't be less than zero");
        Pool storage pool = pools[_poolId];
        PoolStaker storage staker = poolStakers[_poolId][tx.origin];

        // Update pool stakers
        harvestRewards(_poolId, _rewards, tx.origin);

        // Update current staker
        staker.amount = staker.amount + _amount;
        staker.rewardDebt =
            (staker.amount * pool.accumulatedRewardsPerShare) /
            REWARDS_PRECISION;

        // Update pool
        pool.tokensStaked = pool.tokensStaked + _amount;
        // Register Wallet - Migration Purposes
        if (registeredWallet[tx.origin] == false) {
            registeredWalletArr.push(tx.origin);
            registeredWallet[tx.origin] = true;
        }
        // Deposit tokens
        emit Deposit(tx.origin, _poolId, _amount);
    }

    /**
     * @dev Withdraw all tokens from an existing pool
     */
    function withdraw(
        uint256 _poolId,
        uint256 _withdrawal,
        uint256 _rewards
    ) external onlyWhitelisted {
        // Pay Rewards
        harvestRewards(_poolId, _rewards, tx.origin);
        Pool storage pool = pools[_poolId];
        PoolStaker storage staker = poolStakers[_poolId][tx.origin];
        uint256 stakerAmount = staker.amount;
        require(
            stakerAmount + staker.rewards > 0,
            "Withdraw amount can't be zero"
        );
        require(
            _withdrawal <= stakerAmount + staker.rewards,
            "Can't withdraw more than balance."
        );
        //Update Rewards
        if (staker.rewards < _withdrawal) {
            _withdrawal = _withdrawal - staker.rewards;
            staker.rewards = 0;
        } else {
            staker.rewards = staker.rewards - _withdrawal;
            _withdrawal = 0;
        }

        // Update Staker Amount
        if (_withdrawal != 0 && staker.amount != 0) {
            staker.amount = staker.amount - _withdrawal;
        }

        staker.rewardDebt =
            (staker.amount * pool.accumulatedRewardsPerShare) /
            REWARDS_PRECISION;

        // Update Pool
        pool.tokensStaked = pool.tokensStaked - _withdrawal;

        // Withdraw tokens
        emit Withdraw(tx.origin, _poolId, _withdrawal);
    }

    /**
     * @dev Harvest user rewards from a given pool id
     */
    function harvestRewards(
        uint256 _poolId,
        uint256 _rewards,
        address _clientAddress
    ) private {
        updatePoolRewards(_poolId, _rewards);
        Pool storage pool = pools[_poolId];
        PoolStaker storage staker = poolStakers[_poolId][_clientAddress];
        uint256 rewardsToHarvest = ((staker.amount *
            pool.accumulatedRewardsPerShare) / REWARDS_PRECISION) -
            staker.rewardDebt;
        if (rewardsToHarvest == 0) {
            staker.rewardDebt =
                (staker.amount * pool.accumulatedRewardsPerShare) /
                REWARDS_PRECISION;
            return;
        }
        staker.rewardDebt =
            (staker.amount * pool.accumulatedRewardsPerShare) /
            REWARDS_PRECISION;
        //Distribute commissions, return leftover rewards to staker
        rewardsToHarvest = distributeCommission(
            _clientAddress,
            rewardsToHarvest,
            _poolId
        );
        staker.rewards = staker.rewards + rewardsToHarvest;
        emit HarvestRewards(_clientAddress, _poolId, rewardsToHarvest);
    }

    /**
     * @dev Update pool's accumulatedRewardsPerShare and lastRewardedBlock
     */
    function updatePoolRewards(uint256 _poolId, uint256 _rewards) private {
        Pool storage pool = pools[_poolId];
        if (pool.tokensStaked == 0) {
            return;
        }
        pool.accumulatedRewardsPerShare =
            pool.accumulatedRewardsPerShare +
            ((_rewards * REWARDS_PRECISION) / pool.tokensStaked);
    }

    /**
     * @dev View reward balance
     * @notice Reward balance not reflected on PoolStaker b/c harvestRewards() must be called
     *         Only when user harvests, will rewards show up in Staker struct
     */
    function pendingRewards(uint256 _poolId, address _stakerAddress)
        public
        view
        returns (uint256)
    {
        Pool storage pool = pools[_poolId];
        PoolStaker storage staker = poolStakers[_poolId][_stakerAddress];
        return
            ((staker.amount * pool.accumulatedRewardsPerShare) /
                REWARDS_PRECISION) - staker.rewardDebt;
    }

    /*
     * @dev Add a new partner - onlyOwner
     * @returns remaining commission for client
     */
    function distributeCommission(
        address _clientAddress,
        uint256 _rewardAmount,
        uint256 _poolId
    ) private returns (uint256) {
        address partnerAddress = client[_clientAddress];
        if (partnerAddress != address(0)) {
            //check if partner involved
            PoolStaker storage partnerStaker = poolStakers[_poolId][
                partnerAddress
            ];
            uint256 partnerCommission = (((_rewardAmount * REWARDS_PRECISION) /
                100) * partnerCut) / REWARDS_PRECISION;
            _rewardAmount = _rewardAmount - partnerCommission;
            address referralAddress = partnerReferral[partnerAddress];
            if (referralAddress != address(0)) {
                //Check if referral involved
                PoolStaker storage beneficiaryStaker = poolStakers[_poolId][
                    referralAddress
                ];
                uint256 referralCommission = (((partnerCommission *
                    REWARDS_PRECISION) / 100) * referralCut) /
                    REWARDS_PRECISION;
                beneficiaryStaker.rewards =
                    beneficiaryStaker.rewards +
                    referralCommission;
                partnerStaker.rewards =
                    partnerStaker.rewards +
                    partnerCommission -
                    referralCommission; //deduct ben comm
                _rewardAmount = _rewardAmount - referralCommission;
            } else {
                partnerStaker.rewards =
                    partnerStaker.rewards +
                    partnerCommission;
            }
        }
        return _rewardAmount;
    }

    /*
     * @dev Permits Partners to Force Harvest Rewards to Collect Commissions
     * @notice MasterChef's passive approach to reward collection given an index
               means partners could go extended periods w/o rewards sent to them.
               This function enables them to collect commission while keeping their
               clients staker profiles up to date. 
     * @notice Operation is gas intensive but to be conducted by each partner
     * @notice Only checks one pool at a time
     * _loopLimit - set by front-end in case gas is too expensive
     */
    function forceHarvest(uint256 _poolId, uint256 _loopLimit)
        external
        onlyPartner
    {
        require(
            partnerWallets[msg.sender].length > 0,
            "Partner has no client wallets."
        );
        for (
            uint256 i = 0;
            i <
            (
                (partnerWallets[msg.sender].length > _loopLimit)
                    ? _loopLimit
                    : partnerWallets[msg.sender].length
            );
            i++
        ) {
            harvestRewards(_poolId, 0, partnerWallets[msg.sender][i]);
        }
    }

    /*
     * @dev Similar to forceHarvest() but for one address
     * Good for a wealthy client where commission is sought
     * @notice Checks all pools
     */
    function forceHarvestAddress(address _target) external onlyPartner {
        require(
            partnerWallets[msg.sender].length > 0,
            "Partner has no client wallets."
        );
        require(
            client[_target] == msg.sender,
            "Address does not belong to partner."
        );
        for (uint256 poolId = 0; poolId < pools.length; poolId++) {
            uint256 pending = pendingRewards(poolId, _target);
            if (pending > 0) {
                harvestRewards(poolId, 0, _target);
            }
        }
    }

    /*
     * @dev Add a new partner - onlyOwner
     */
    function addPartner(address _address) external onlyOwner {
        require(_address != address(0), "Invalid address.");
        partner[_address] = true;
    }

    /*
     * @dev Delete a new partner - onlyOwner
     */
    function deletePartner(address _address) external onlyOwner {
        require(partner[_address] == true, "Address is not partner");
        partner[_address] = false;
    }

    /*
     * @dev Add a client, performed by partner
     */
    function addClient(address _clientAddress, address _partnerAddress)
        external
        onlyPartner
    {
        require(partner[_partnerAddress] == true, "Address is not partner");
        require(
            partner[_clientAddress] == false,
            "Partner attemtping to add another partner as client"
        );
        require(_clientAddress != address(0), "Invalid address.");
        require(
            client[_clientAddress] == address(0),
            "Client has already been added by another partner."
        );
        bool activeWallet = checkActiveWallet(_clientAddress);
        require(
            activeWallet == false,
            "Wallet already active, cannot be added."
        );
        client[_clientAddress] = _partnerAddress;
        partnerWallets[_partnerAddress].push(_clientAddress);
        emit clientAdded(_partnerAddress, _clientAddress);
    }

    /*
     * @dev Client or owner can switch partner affiliation
     * @notice Action in case partner has underperformed
     */
    function partnerSwitch(address _clientAddress, address _newPartnerAddress)
        external
        onlyOwner
    {
        require(partner[_newPartnerAddress] == true, "Address is not partner");
        require(client[_clientAddress] != address(0), "client Nonexistent.");
        require(
            msg.sender == _clientAddress || msg.sender == owner(),
            "Unauthorized User Attempting to Change client."
        );
        client[_clientAddress] = _newPartnerAddress;
        emit partnerSwitched(_newPartnerAddress, _clientAddress);
    }

    /*
     * @dev If a partner finds another partner, they will be added here
     * @notice Only owner can add in case partner decides to add already
     *         existing and profitable wallets from the system
     */
    function addPartnerReferral(address _referral, address _beneficiary)
        external
        onlyOwner
    {
        require(partner[_beneficiary] == true, "Address is not partner");
        require(_referral != address(0), "Address Nonexistent.");
        partnerReferral[_referral] = _beneficiary;
        emit partnerAdded(_beneficiary, _referral);
    }

    /**
     * @dev Remove From Last Wallet Arr
     * _index - will remove address from partner mapping
     */
    function removeWalletFromPartner(int256 _index, address _partnerAddress)
        internal
    {
        uint256 castedIndex = uint256(_index);
        require(
            partnerWallets[_partnerAddress].length > castedIndex,
            "Out of bounds"
        );
        // move all elements to the left, starting from the `index + 1`
        for (
            uint256 i = castedIndex;
            i < partnerWallets[_partnerAddress].length - 1;
            i++
        ) {
            partnerWallets[_partnerAddress][i] = partnerWallets[
                _partnerAddress
            ][i + 1];
        }
        partnerWallets[_partnerAddress].pop(); // delete the last item
    }

    /**
     * @dev Check if active wallet
     * @notice prevents partners from adding wealthy wallets 
               that didnt use a partner on our system
     */
    function checkActiveWallet(address _target) private view returns (bool) {
        uint256 amountTotal;
        for (uint256 poolId = 0; poolId < pools.length; poolId++) {
            PoolStaker storage staker = poolStakers[poolId][_target];
            amountTotal = amountTotal + staker.amount;
        }
        if (amountTotal > 0) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Add Whitelisted Contract
     */
    function addWhitelistedContract(address _newAddress) external onlyOwner {
        whitelistedContracts[_newAddress] = true;
    }

    /**
     * @dev Delete Whitelisted Contract
     */
    function deleteWhitelistedContract(address _oldAddress) external onlyOwner {
        whitelistedContracts[_oldAddress] = false;
    }

    /**
     * @dev Change Referral Cut
     */
    function editReferralCut(uint256 _newAmount) external onlyOwner {
        referralCut = _newAmount;
    }

    /**
     * @dev Change Partner Cut
     */
    function editPartnerCut(uint256 _newAmount) external onlyOwner {
        partnerCut = _newAmount;
    }

    /**
     * @dev Change Bank Cut
     */
    function editBankCut(uint256 _newAmount) external onlyOwner {
        bankCut = _newAmount;
    }
}

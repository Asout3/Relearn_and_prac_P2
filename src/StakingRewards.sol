// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @custom:info This contract have been refactored by an ai(deepseek v4.1 flash).
/// @custom:info You can find the original contract in this link: https://github.com/Asout3/Relearn_and_prac/blob/main/src/StakingRewards.sol

interface IAsout3Token {
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);
    function transfer(address _to, uint256 _amount) external returns (bool);
    function balanceOf(address _address) external view returns (uint256);
    function mint(uint256 _amount, address _to) external;
}

error InsufficientAllowance();
error InsufficientBalance();

/**
 * @title RewardToken
 * @notice Minimal ERC20-like token used as the reward asset for the staking contract.
 * @dev Owner can mint and burn. Not intended for production use.
 */
contract RewardToken {
    event Transfer(address indexed sender, address indexed receiver, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    uint256 public totalSupply;

    mapping(address => uint256) private _balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name;
    string public symbol;

    uint8 public decimals;
    address public owner;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;
        owner = msg.sender;
    }

    /// @notice Returns the total supply of the token.
    function totalSupply_() external view returns (uint256) {
        return totalSupply;
    }

    /// @notice Returns the token balance of `_address`.
    function balanceOf(address _address) external view returns (uint256) {
        return _balanceOf[_address];
    }

    /// @notice Mints `_amount` tokens to `_to`. Callable only by the owner.
    function mint(uint256 _amount, address _to) external {
        require(owner == msg.sender, "you are not the owner of this token");
        totalSupply += _amount;
        _balanceOf[_to] += _amount;
    }

    /// @notice Burns `_amount` tokens from `_from`. Callable only by the owner.
    function burn(address _from, uint256 _amount) external {
        require(owner == msg.sender, "not owner");
        require(_balanceOf[_from] >= _amount, "insufficient");
        _balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    /// @notice Transfers `_amount` tokens from `msg.sender` to `_to`.
    function transfer(address _to, uint256 _amount) external returns (bool) {
        if (_balanceOf[msg.sender] < _amount) revert InsufficientBalance();

        _balanceOf[msg.sender] -= _amount;
        _balanceOf[_to] += _amount;

        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    /// @notice Approves `_spender` to spend `_amount` tokens on behalf of `msg.sender`.
    function approve(address _spender, uint256 _amount) external returns (bool) {
        allowance[msg.sender][_spender] = _amount;

        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /// @notice Transfers `_amount` tokens from `_from` to `_to` using the caller's allowance.
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool) {
        if (allowance[_from][msg.sender] < _amount) revert InsufficientAllowance();
        if (_balanceOf[_from] < _amount) revert InsufficientBalance();

        allowance[_from][msg.sender] -= _amount;
        _balanceOf[_from] -= _amount;
        _balanceOf[_to] += _amount;

        emit Transfer(_from, _to, _amount);
        return true;
    }

    /// @notice Returns true if `_owner` has approved `_to` for any non-zero amount.
    function checkApproval(address _owner, address _to) external view returns (bool) {
        if (allowance[_owner][_to] == 0) return false;

        return true;
    }
}

/**
 * @title StakingRewards
 * @notice Synthetix-style staking contract. Users stake an ERC20 token and earn a
 *         separate reward token distributed linearly over 7 days.
 * @dev Reward accounting uses a global `rewardPerTokenStored` accumulator and
 *      per-user checkpoints (`userRewardPerTokenPaid`) to avoid loops. Not
 *      production-ready; written for exercise purposes.
 */
contract StakingRewards {
    IAsout3Token public stakingToken;
    RewardToken public rewardToken;

    /// @notice Reward tokens distributed per second.
    uint256 public rewardRate;

    /// @notice Timestamp of the last reward accounting update.
    uint256 public lastUpdateTime;

    /// @notice Timestamp at which the current reward period ends.
    uint256 public periodFinish;

    /// @notice Cumulative reward per staked token, scaled by 1e18.
    uint256 public rewardPerTokenStored;

    /// @notice Reward period length (7 days in seconds).
    uint256 public constant SEVEN_DAYS = 604800;

    address public owner;

    /// @notice Total amount of staking tokens currently staked.
    uint256 public totalStaked;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    constructor(address _stakingToken) {
        owner = msg.sender;
        stakingToken = IAsout3Token(_stakingToken);
        rewardToken = new RewardToken("Reward Token", "RT", 18, 0);
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "you are not the owner");
        _;
    }

    /// @dev Syncs global reward accumulator and checkpoint state for `user`.
    function updateReward(address user) private {
        rewardPerTokenStored = rewardPerToken();
        // BUG was found here. the original code is:- lastUpdatedTime = block.timestamp;
        // Detail explanation is on the StakingRewardsTimeFuzz.t.sol test contract.
        lastUpdateTime = lastTimeRewardApplicable(); //block.timestamp

        if (user != address(0)) {
            rewards[user] = earned(user);
            userRewardPerTokenPaid[user] = rewardPerTokenStored;
        }
    }

    /// @notice Returns the up-to-date global reward-per-token accumulator.
    /// @dev Returns the stored value unchanged when `totalStaked` is zero.
    function rewardPerToken() public view returns (uint256) {
        uint256 timePassed = lastTimeRewardApplicable() - lastUpdateTime;
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + (rewardRate * timePassed * 1e18 / totalStaked);
    }

    /// @notice Returns the total reward currently claimable by `user`.
    function earned(address user) public view returns (uint256) {
        return rewards[user] + (stakedBalance[user] * (rewardPerToken() - userRewardPerTokenPaid[user]) / 1e18);
    }

    /// @notice Stakes `amount` of the staking token on behalf of the caller.
    /// @dev Pulls tokens via `transferFrom`; caller must have approved this contract.
    function stake(uint256 amount) external {
        require(amount > 0);
        updateReward(msg.sender);

        bool success = stakingToken.transferFrom(msg.sender, address(this), amount);
        require(success, "transaction failed");

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;
    }

    /// @notice Unstakes `amount` of the caller's staked tokens.
    function unstake(uint256 amount) external {
        require(amount > 0);
        require(stakedBalance[msg.sender] >= amount, "Insufficient amount");

        updateReward(msg.sender);

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        bool success = stakingToken.transfer(msg.sender, amount);
        require(success, "transaction failed");
    }

    /// @notice Claims all accrued reward tokens for the caller.
    function claim() external {
        updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        bool success = rewardToken.transfer(msg.sender, reward);
        require(success, "transaction failed");
    }

    /// @notice Starts a new 7-day reward distribution with `amount` reward tokens.
    /// @dev Owner only. Mints `amount` of the reward token to this contract and
    ///      sets `rewardRate` to `amount / SEVEN_DAYS`.
    function notifyReward(uint256 amount) external onlyOwner {
        require(amount > 0);
        updateReward(address(0));

        rewardToken.mint(amount, address(this));

        rewardRate = amount / SEVEN_DAYS;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + SEVEN_DAYS;
    }

    /// @notice Returns the timestamp up to which rewards should accrue.
    /// @dev Equal to `min(block.timestamp, periodFinish)`.
    function lastTimeRewardApplicable() public view returns (uint256) {
        if (block.timestamp < periodFinish) {
            return block.timestamp;
        } else {
            return periodFinish;
        }
    }
}

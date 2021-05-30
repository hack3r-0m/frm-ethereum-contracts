// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./SafeMath.sol";

contract CestakingFarm {
    using SafeMath for uint256;

    mapping (address => uint256) private _stakes;

    string public name;
    address  public tokenAddress;
    address  public rewardTokenAddress;
    uint public stakingStarts;
    uint public stakingEnds;
    uint public withdrawStarts;
    uint public withdrawEnds;
    uint256 public stakedTotal;
    uint256 public stakingCap;
    uint256 public totalReward;
    uint256 public earlyWithdrawReward;
    uint256 public rewardBalance;
    uint256 public stakedBalance;

    ERC20 public ERC20Interface;
    event Staked(address indexed token, address indexed staker_, uint256 requestedAmount_, uint256 stakedAmount_);
    event PaidOut(address indexed token, address indexed rewardToken, address indexed staker_, uint256 amount_, uint256 reward_);

    /**
     */
    constructor (string memory name_,
        address tokenAddress_,
        address rewardTokenAddress_,
        uint stakingStarts_,
        uint stakingEnds_,
        uint withdrawStarts_,
        uint withdrawEnds_,
        uint256 stakingCap_) {
        name = name_;
        require(tokenAddress_ != address(0), "Cestaking: 0 address");
        tokenAddress = tokenAddress_;

        require(rewardTokenAddress_ != address(0), "Cestaking: 0 reward address");
        rewardTokenAddress = rewardTokenAddress_;

        require(stakingStarts_ > 0, "Cestaking: zero staking start time");
        if (stakingStarts_ < block.timestamp) {
            stakingStarts = block.timestamp;
        } else {
            stakingStarts = stakingStarts_;
        }

        require(stakingEnds_ > stakingStarts, "Cestaking: staking end must be after staking starts");
        stakingEnds = stakingEnds_;

        require(withdrawStarts_ >= stakingEnds, "Cestaking: withdrawStarts must be after staking ends");
        withdrawStarts = withdrawStarts_;

        require(withdrawEnds_ > withdrawStarts, "Cestaking: withdrawEnds must be after withdraw starts");
        withdrawEnds = withdrawEnds_;

        require(stakingCap_ > 0, "Cestaking: stakingCap must be positive");
        stakingCap = stakingCap_;
    }

    function addReward(uint256 rewardAmount, uint256 withdrawableAmount)
    public
    _before(withdrawStarts)
    returns (bool) {
        require(rewardAmount > 0, "Cestaking: reward must be positive");
        require(withdrawableAmount >= 0, "Cestaking: withdrawable amount cannot be negative");
        require(withdrawableAmount <= rewardAmount, "Cestaking: withdrawable amount must be less than or equal to the reward amount");
        address from = msg.sender;
        if (!_payMe(from, rewardAmount, tokenAddress)) {
            return false;
        }

        totalReward = totalReward.add(rewardAmount);
        rewardBalance = totalReward;
        earlyWithdrawReward = earlyWithdrawReward.add(withdrawableAmount);
        return true;
    }

    function stakeOf(address account) public view returns (uint256) {
        return _stakes[account];
    }

    /**
    * Requirements:
    * - `amount` Amount to be staked
    */
    function stake(uint256 amount)
    public
    _positive(amount)
    _realAddress(msg.sender)
    returns (bool) {
        address from = msg.sender;
        return _stake(from, amount);
    }

    function withdraw(uint256 amount)
    public
    _after(withdrawStarts)
    _positive(amount)
    _realAddress(msg.sender)
    returns (bool) {
        address from = msg.sender;
        require(amount <= _stakes[from], "Cestaking: not enough balance");
        if (block.timestamp < withdrawEnds) {
            return _withdrawEarly(from, amount);
        } else {
            return _withdrawAfterClose(from, amount);
        }
    }

    function _withdrawEarly(address from, uint256 amount)
    private
    _realAddress(from)
    returns (bool) {
        // This is the formula to calculate reward:
        // r = (earlyWithdrawReward / stakedTotal) * (block.timestamp - stakingEnds) / (withdrawEnds - stakingEnds)
        // w = (1+r) * a
        uint256 denom = (withdrawEnds.sub(stakingEnds)).mul(stakedTotal);
        uint256 reward = (
        ( (block.timestamp.sub(stakingEnds)).mul(earlyWithdrawReward) ).mul(amount)
        ).div(denom);
        rewardBalance = rewardBalance.sub(reward);
        stakedBalance = stakedBalance.sub(amount);
        _stakes[from] = _stakes[from].sub(amount);
        bool principalPaid = _payDirect(from, amount, tokenAddress);
        bool rewardPaid = _payDirect(from, reward, rewardTokenAddress);
        require(principalPaid && rewardPaid, "Cestaking: error paying");
        emit PaidOut(tokenAddress, rewardTokenAddress, from, amount, reward);
        return true;
    }

    function _withdrawAfterClose(address from, uint256 amount)
    private
    _realAddress(from)
    returns (bool) {
        uint256 reward = (rewardBalance.mul(amount)).div(stakedBalance);
        _stakes[from] = _stakes[from].sub(amount);
        bool principalPaid = _payDirect(from, amount, tokenAddress);
        bool rewardPaid = _payDirect(from, reward, rewardTokenAddress);
        require(principalPaid && rewardPaid, "Cestaking: error paying");
        emit PaidOut(tokenAddress, rewardTokenAddress, from, amount, reward);
        return true;
    }

    function _stake(address staker, uint256 amount)
    private
    _after(stakingStarts)
    _before(stakingEnds)
    _positive(amount)
    returns (bool) {
        // check the remaining amount to be staked
        uint256 remaining = amount;
        if (remaining > (stakingCap.sub(stakedBalance))) {
            remaining = stakingCap.sub(stakedBalance);
        }
        // These requires are not necessary, because it will never happen, but won't hurt to double check
        // this is because stakedTotal and stakedBalance are only modified in this method during the staking period
        require(remaining > 0, "Cestaking: Staking cap is filled");
        require((remaining + stakedTotal) <= stakingCap, "Cestaking: this will increase staking amount pass the cap");
        if (!_payMe(staker, remaining, tokenAddress)) {
            return false;
        }
        emit Staked(tokenAddress, staker, amount, remaining);

        // Transfer is completed
        stakedBalance = stakedBalance.add(remaining);
        stakedTotal = stakedTotal.add(remaining);
        _stakes[staker] = _stakes[staker].add(remaining);
        return true;
    }

    function _payMe(address payer, uint256 amount, address token)
    private
    returns (bool) {
        return _payTo(payer, address(this), amount, token);
    }

    function _payTo(address allower, address receiver, uint256 amount, address token)
    private
    returns (bool) {
        // Request to transfer amount from the contract to receiver.
        // contract does not own the funds, so the allower must have added allowance to the contract
        // Allower is the original owner.
        ERC20Interface = ERC20(token);
        return ERC20Interface.transferFrom(allower, receiver, amount);
    }

    function _payDirect(address to, uint256 amount, address token)
    private
    returns (bool) {
        if (amount == 0) {
            return true;
        }
        ERC20Interface = ERC20(token);
        return ERC20Interface.transfer(to, amount);
    }

    modifier _realAddress(address addr) {
        require(addr != address(0), "Cestaking: zero address");
        _;
    }

    modifier _positive(uint256 amount) {
        require(amount >= 0, "Cestaking: negative amount");
        _;
    }

    modifier _after(uint eventTime) {
        require(block.timestamp >= eventTime, "Cestaking: bad timing for the request");
        _;
    }

    modifier _before(uint eventTime) {
        require(block.timestamp < eventTime, "Cestaking: bad timing for the request");
        _;
    }
}

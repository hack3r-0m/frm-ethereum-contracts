// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SafeMath.sol";

contract Cestaking is Ownable {
    using SafeMath for uint256;

    // season to stake records mapping
    mapping(uint256 => mapping(address => uint256)) stakes;
    // remaining balance of users in each season
    mapping(uint256 => mapping(address => uint256)) remainingBalance;

    uint256 currentActiveSeason;

    struct StakingSeason {
        address tokenAddress;
        uint256 stakingStarts;
        uint256 stakingEnds;
        uint256 withdrawStarts;
        uint256 withdrawEnds;
        uint256 stakedTotal;
        uint256 stakingCap;
        uint256 totalReward;
        uint256 earlyWithdrawReward;
        uint256 rewardBalance;
        uint256 stakedBalance;
    }

    StakingSeason[] stakingSeasons;

    function deleteLastSeason() external onlyOwner {
        require(
            stakingSeasons[stakingSeasons.length - 1].stakingStarts >
                block.timestamp,
            "Cestaking: cannot remove last added season after staking has started"
        );
        stakingSeasons.pop();
    }

    ERC20 public ERC20Interface;

    event Staked(
        address indexed token,
        address indexed staker_,
        uint256 requestedAmount_,
        uint256 stakedAmount_,
        uint256 season
    );
    event PaidOut(
        address indexed token,
        address indexed staker_,
        uint256 amount_,
        uint256 reward_,
        uint256 season
    );
    event Refunded(
        address indexed token,
        address indexed staker_,
        uint256 amount_,
        uint256 season
    );

    /**
     */
    function addSeason(
        address tokenAddress_,
        uint256 stakingStarts_,
        uint256 stakingEnds_,
        uint256 withdrawStarts_,
        uint256 withdrawEnds_,
        uint256 stakingCap_
    ) external onlyOwner {
        require(tokenAddress_ != address(0), "Cestaking: 0 address");

        require(
            stakingStarts_ >
                stakingSeasons[stakingSeasons.length - 1].withdrawEnds,
            "Cestaking: Next season must start after withdraw period of previous ends"
        );

        require(stakingStarts_ > 0, "Cestaking: zero staking start time");

        uint256 stakingStarts;

        if (stakingStarts_ < block.timestamp) {
            stakingStarts = block.timestamp;
        } else {
            stakingStarts = stakingStarts_;
        }

        require(
            stakingEnds_ > stakingSeasons[currentActiveSeason].stakingStarts,
            "Cestaking: staking end must be after staking starts"
        );

        require(
            withdrawStarts_ >= stakingSeasons[currentActiveSeason].stakingEnds,
            "Cestaking: withdrawStarts must be after staking ends"
        );

        require(
            withdrawEnds_ > stakingSeasons[currentActiveSeason].withdrawStarts,
            "Cestaking: withdrawEnds must be after withdraw starts"
        );

        require(stakingCap_ > 0, "Cestaking: stakingCap must be positive");

        stakingSeasons.push(
            StakingSeason({
                tokenAddress: tokenAddress_,
                stakingStarts: stakingStarts,
                stakingEnds: stakingEnds_,
                withdrawStarts: withdrawStarts_,
                withdrawEnds: withdrawEnds_,
                stakedTotal: 0,
                stakingCap: stakingCap_,
                totalReward: 0,
                earlyWithdrawReward: 0,
                rewardBalance: 0,
                stakedBalance: 0
            })
        );
    }

    // rewards would be added in current active season
    function addReward(uint256 rewardAmount, uint256 withdrawableAmount)
        public
        _before(stakingSeasons[currentActiveSeason].withdrawStarts)
        _hasAllowance(msg.sender, rewardAmount)
        _checkSeasonUpdate()
        returns (bool)
    {
        // require(stakingSeasons.length != 0, "Cestaking: No season exists");
        require(rewardAmount > 0, "Cestaking: reward must be positive");
        require(
            withdrawableAmount >= 0,
            "Cestaking: withdrawable amount cannot be negative"
        );
        require(
            withdrawableAmount <= rewardAmount,
            "Cestaking: withdrawable amount must be less than or equal to the reward amount"
        );
        address from = msg.sender;
        if (!_payMe(from, rewardAmount)) {
            return false;
        }

        stakingSeasons[currentActiveSeason].totalReward = stakingSeasons[
            currentActiveSeason
        ]
            .totalReward
            .add(rewardAmount);
        stakingSeasons[currentActiveSeason].rewardBalance = stakingSeasons[
            currentActiveSeason
        ]
            .totalReward;
        stakingSeasons[currentActiveSeason]
            .earlyWithdrawReward = stakingSeasons[currentActiveSeason]
            .earlyWithdrawReward
            .add(withdrawableAmount);
        return true;
    }

    function currentStakeOf(address account) public view returns (uint256) {
        return stakes[currentActiveSeason][account];
    }

    function stakeOf(address account, uint256 season)
        public
        view
        returns (uint256)
    {
        return stakes[season][account];
    }

    /**
     * Requirements:
     * - `amount` Amount to be staked
     */

    // stake will be added in current season
    function stake(uint256 amount)
        public
        _positive(amount)
        _realAddress(msg.sender)
        _checkSeasonUpdate()
        returns (bool)
    {
        address from = msg.sender;
        return _stake(from, amount);
    }

    function withdraw(uint256 amount)
        public
        _after(stakingSeasons[currentActiveSeason].withdrawStarts)
        _positive(amount)
        _realAddress(msg.sender)
        returns (bool)
    {
        address from = msg.sender;
        require(
            amount <= stakes[currentActiveSeason][from],
            "Cestaking: not enough balance"
        );
        if (
            block.timestamp < stakingSeasons[currentActiveSeason].withdrawEnds
        ) {
            return _withdrawEarly(from, amount);
        } else {
            return _withdrawAfterClose(from, amount, currentActiveSeason);
        }
    }

    function withdrawOldSeason(uint256 amount, uint256 season)
        external
        _after(stakingSeasons[season].withdrawStarts)
        _positive(amount)
        _realAddress(msg.sender)
        returns (bool)
    {
        address from = msg.sender;
        require(
            amount <= stakes[season][from],
            "Cestaking: not enough balance"
        );
        require(
            stakingSeasons.length - 1 > season,
            "Cestaking: Active season not allowed, use withdraw()"
        );
        require(
            block.timestamp > stakingSeasons[season].withdrawEnds,
            "Cestaking: Old season withdraw period not ended, use withdraw()"
        );

        return _withdrawAfterClose(from, amount, season);
    }

    function _withdrawEarly(address from, uint256 amount)
        private
        _realAddress(from)
        returns (bool)
    {
        // This is the formula to calculate reward:
        // r = (earlyWithdrawReward / stakedTotal) * (block.timestamp - stakingEnds) / (withdrawEnds - stakingEnds)
        // w = (1+r) * a
        uint256 denom =
            (
                stakingSeasons[currentActiveSeason].withdrawEnds.sub(
                    stakingSeasons[currentActiveSeason].stakingEnds
                )
            )
                .mul(stakingSeasons[currentActiveSeason].stakedTotal);
        uint256 reward =
            (
                (
                    (
                        block.timestamp.sub(
                            stakingSeasons[currentActiveSeason].stakingEnds
                        )
                    )
                        .mul(
                        stakingSeasons[currentActiveSeason].earlyWithdrawReward
                    )
                )
                    .mul(amount)
            )
                .div(denom);
        uint256 payOut = amount.add(reward);
        stakingSeasons[currentActiveSeason].rewardBalance = stakingSeasons[
            currentActiveSeason
        ]
            .rewardBalance
            .sub(reward);
        stakingSeasons[currentActiveSeason].stakedBalance = stakingSeasons[
            currentActiveSeason
        ]
            .stakedBalance
            .sub(amount);
        stakes[currentActiveSeason][from] = stakes[currentActiveSeason][from]
            .sub(amount);
        if (_payDirect(from, payOut)) {
            emit PaidOut(
                stakingSeasons[currentActiveSeason].tokenAddress,
                from,
                amount,
                reward,
                currentActiveSeason
            );
            return true;
        }
        return false;
    }

    function _withdrawAfterClose(
        address from,
        uint256 amount,
        uint256 season
    ) private _realAddress(from) returns (bool) {
        uint256 reward =
            (stakingSeasons[season].rewardBalance.mul(amount)).div(
                stakingSeasons[season].stakedBalance
            );
        uint256 payOut = amount.add(reward);
        stakes[season][from] = stakes[season][from].sub(amount);
        if (_payDirect(from, payOut)) {
            emit PaidOut(
                stakingSeasons[season].tokenAddress,
                from,
                amount,
                reward,
                season
            );
            return true;
        }
        return false;
    }

    function _stake(address staker, uint256 amount)
        private
        _after(stakingSeasons[currentActiveSeason].stakingStarts)
        _before(stakingSeasons[currentActiveSeason].stakingEnds)
        _positive(amount)
        _hasAllowance(staker, amount)
        returns (bool)
    {
        // check the remaining amount to be staked
        uint256 remaining = amount;
        if (
            remaining >
            (
                stakingSeasons[currentActiveSeason].stakingCap.sub(
                    stakingSeasons[currentActiveSeason].stakedBalance
                )
            )
        ) {
            remaining = stakingSeasons[currentActiveSeason].stakingCap.sub(
                stakingSeasons[currentActiveSeason].stakedBalance
            );
        }
        // These requires are not necessary, because it will never happen, but won't hurt to double check
        // this is because stakedTotal and stakedBalance are only modified in this method during the staking period
        require(remaining > 0, "Cestaking: Staking cap is filled");
        require(
            (remaining + stakingSeasons[currentActiveSeason].stakedTotal) <=
                stakingSeasons[currentActiveSeason].stakingCap,
            "Cestaking: this will increase staking amount pass the cap"
        );
        if (!_payMe(staker, remaining)) {
            return false;
        }
        emit Staked(
            stakingSeasons[currentActiveSeason].tokenAddress,
            staker,
            amount,
            remaining,
            currentActiveSeason
        );

        if (remaining < amount) {
            // Return the unstaked amount to sender (from allowance)
            uint256 refund = amount.sub(remaining);
            if (_payTo(staker, staker, refund)) {
                emit Refunded(
                    stakingSeasons[currentActiveSeason].tokenAddress,
                    staker,
                    refund,
                    currentActiveSeason
                );
            }
        }

        // Transfer is completed
        stakingSeasons[currentActiveSeason].stakedBalance = stakingSeasons[
            currentActiveSeason
        ]
            .stakedBalance
            .add(remaining);
        stakingSeasons[currentActiveSeason].stakedTotal = stakingSeasons[
            currentActiveSeason
        ]
            .stakedTotal
            .add(remaining);
        stakes[currentActiveSeason][staker] = stakes[currentActiveSeason][
            staker
        ]
            .add(remaining);
        return true;
    }

    function _payMe(address payer, uint256 amount) private returns (bool) {
        return _payTo(payer, address(this), amount);
    }

    function _payTo(
        address allower,
        address receiver,
        uint256 amount
    ) private _hasAllowance(allower, amount) returns (bool) {
        // Request to transfer amount from the contract to receiver.
        // contract does not own the funds, so the allower must have added allowance to the contract
        // Allower is the original owner.
        ERC20Interface = ERC20(
            stakingSeasons[currentActiveSeason].tokenAddress
        );
        return ERC20Interface.transferFrom(allower, receiver, amount);
    }

    function _payDirect(address to, uint256 amount)
        private
        _positive(amount)
        returns (bool)
    {
        ERC20Interface = ERC20(
            stakingSeasons[currentActiveSeason].tokenAddress
        );
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

    modifier _after(uint256 eventTime) {
        require(
            block.timestamp >= eventTime,
            "Cestaking: bad timing for the request"
        );
        _;
    }

    modifier _before(uint256 eventTime) {
        require(
            block.timestamp < eventTime,
            "Cestaking: bad timing for the request"
        );
        _;
    }

    modifier _hasAllowance(address allower, uint256 amount) {
        // Make sure the allower has provided the right allowance.
        ERC20Interface = ERC20(
            stakingSeasons[currentActiveSeason].tokenAddress
        );
        uint256 ourAllowance = ERC20Interface.allowance(allower, address(this));
        require(
            amount <= ourAllowance,
            "Cestaking: Make sure to add enough allowance"
        );
        _;
    }

    modifier _checkSeasonUpdate() {
        if (
            block.timestamp >
            stakingSeasons[currentActiveSeason].withdrawEnds &&
            stakingSeasons.length - 1 > currentActiveSeason
        ) {
            currentActiveSeason += 1;
        }
        _;
    }
}

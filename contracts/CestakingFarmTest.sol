// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "./Cestaking.sol";

contract CestakingFarmTest is Cestaking {
    uint public GAP = 60000;
    uint public SEC = 1000;

    constructor (string memory name_,
        address tokenAddress_,
        address rewardTokenAddress_,
        uint256 stakingCap_)
    Cestaking(name_, tokenAddress_, now, now + GAP, now + GAP, now + GAP * 2, stakingCap_)
    public { }

    function setStakingPeriod() public {
        setStakingStart(now - SEC);
    }

    function setEarlyWithdrawalPeriod(uint offset) public {
        setStakingStart(now - GAP - offset);
    }

    function setAfterWithdrawal() public {
        setStakingStart(now - GAP * 2 - SEC);
    }

    function setStakingStart(uint time) private {
        stakingStarts = time;
        stakingEnds = time + GAP;
        withdrawStarts = time + GAP;
        withdrawEnds = time + GAP * 2;
    }
}

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
    Cestaking(name_, tokenAddress_, block.timestamp, block.timestamp + GAP, block.timestamp + GAP, block.timestamp + GAP * 2, stakingCap_) { }

    function setStakingPeriod() public {
        setStakingStart(block.timestamp - SEC);
    }

    function setEarlyWithdrawalPeriod(uint offset) public {
        setStakingStart(block.timestamp - GAP - offset);
    }

    function setAfterWithdrawal() public {
        setStakingStart(block.timestamp - GAP * 2 - SEC);
    }

    function setStakingStart(uint time) private {
        stakingStarts = time;
        stakingEnds = time + GAP;
        withdrawStarts = time + GAP;
        withdrawEnds = time + GAP * 2;
    }
}

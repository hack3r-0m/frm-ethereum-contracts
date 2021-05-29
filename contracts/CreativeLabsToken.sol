// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract CreativeLabsToken is ERC20Burnable {
    string public _name = "CreativeLabs";
    string public _symbol = "CLT";
    uint public INITIAL_SUPPLY = 331718750 * 10**18;

    constructor() ERC20(
        _name,
        _symbol
    ) public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}

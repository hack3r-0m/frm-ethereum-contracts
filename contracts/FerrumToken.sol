// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract FerrumToken is ERC20Burnable {
    string public _name = "Ferrum Network Token";
    string public _symbol = "FRM";
    uint8 public _decimals = 6;
    uint public INITIAL_SUPPLY = 331718750 * 1000000;

    constructor() ERC20(
        _name,
        _symbol,
        _decimals
    ) public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract FerrumXToken is ERC20Burnable {
    constructor() ERC20("FRMx Token", "FRMX", 18) public {
        _mint(msg.sender, 33000 * 10 ** 18);
    }
}

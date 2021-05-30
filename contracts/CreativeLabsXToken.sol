// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract CreativeLabsXToken is ERC20Burnable {
    constructor() ERC20("CLTx Token", "CLTX") {
        _mint(msg.sender, 33000 * 10 ** 18);
    }
}

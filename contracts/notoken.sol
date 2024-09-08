// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Encryptoken.sol";
import "./IEncryptoken.sol";

contract NoToken is Encryptoken {
    address public market;

    constructor(address _market) Encryptoken("NoToken", "NO") {
        market = _market;
    }

    function mint(address to, inEuint32 memory amount) public {
        require(msg.sender == market, "Only market can mint tokens");
        euint32 encAmount = FHE.asEuint32(amount);
        euint32 amountToUnwrap = FHE.select(_encBalances[to].gt(encAmount), FHE.asEuint32(0), encAmount);
        _encBalances[to] = _encBalances[to] - amountToUnwrap;
        _mint(msg.sender, FHE.decrypt(amountToUnwrap));
    }

     function burn(address from, uint32 amount) external {
        require(msg.sender == market, "Only market can burn tokens");
        _burn(from, amount);
        euint32 eAmount = FHE.asEuint32(amount);
        _encBalances[msg.sender] = _encBalances[msg.sender] + eAmount;
    }

}
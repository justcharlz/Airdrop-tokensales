//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract GocToken is ERC20{

    //Modifier to check if it is spendable
    // modifier spendable(){

    // }

    constructor(uint _initialSupply) ERC20("GOCToken", "GOC") {
        _mint(msg.sender, _initialSupply * 10 ** 18);
    }

    function transfer(address to, uint256 amount) public override spendable returns (bool) {

        return true;
    }
}
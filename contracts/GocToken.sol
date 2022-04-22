//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IFirstPrivate.sol";
contract GocToken is ERC20{
    IFirstPrivate public firstprivate;

    //Modifier to check if it is spendable
    modifier spendable(uint256 _amount){
        /// checks account is in list of investors and can spend
        uint arraylength = firstprivate.tokenHolders(msg.sender).length;
        for (uint256 index = 0; index < arraylength; index++) {
            require(firstprivate.tokenHolders(msg.sender)[index].tokenClaimable < _amount, "You do not have enough tokens to spend");
        }
        
        /// check vesting period
        /// check account vesting period is over
        _;
    }

    constructor(uint _initialSupply, address _firstprivate) ERC20("GOCToken", "GOC") {
        _mint(msg.sender, _initialSupply * 10 ** 18);
        firstprivate = IFirstPrivate(_firstprivate);
    }

    function transferFrom(address _from, address _to, uint256 _amount) public override spendable(_amount) returns (bool) {

        return true;
    }
}
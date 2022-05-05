//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IgowToken is IERC20{
   
    function addTokenHolders(address _tokenHolder, uint _tokenClaimable, bool _status, uint _vestingStart, uint _vestingEnd, bool _claimed) external returns (bool) ;
    function activateUserVesting(address _tokenHolder,uint _index, uint _vestStart, uint _vestEnd, bool _status) external returns (bool);
}

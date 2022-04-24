//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IgocToken is IERC20{
   
    function addTokenHolders(address _tokenHolder, uint _tokenClaimable, bool _status, uint _vestingStart, uint _vestingEnd) external returns (bool) ;
    function updateUserVesting(address _tokenHolder,uint _index, uint _vestingStart, uint _vestingEnd) external returns (bool) ;
    function activateUserVesting(address _tokenHolder,uint _index, bool _status) external returns (bool);
}

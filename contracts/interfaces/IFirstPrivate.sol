//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

interface IFirstPrivate{
  struct tokenHolder{
        uint tokenClaimable;
        bool vestingClaimed;
        uint vestingStart;
    }
    function tokenHolders(address _address) external view returns (tokenHolder[] memory);
    function vestingPeriod(uint _id) external view returns (address[] memory);
    function buyGOCToken(uint _amount) external returns (bool);
    function claimToken() external view returns (bool);
    function createVestingPeriod(uint _unlockSchedule, uint _vestingMonths, uint _releaseAmount) external view returns (bool);
    function releaseToken(uint _unlockSchedule) external view returns (bool);
    function getPrivateSalesStatus() external view returns (bool);
    function pausePrivateSales() external view returns (bool);
    function unpausePrivateSales() external view returns (bool);
}
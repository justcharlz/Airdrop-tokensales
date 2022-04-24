//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IGocToken.sol";

contract FirstPrivate is Ownable, Pausable, ReentrancyGuard {

    IGocToken GOCToken;
    IERC20 public immutable BUSD = IERC20(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee);
    address internal receiverWallet = 0xdF70554afD4baA101Cde0C987ba4aDF9Ea60cA5E;
    uint tokenPrice = 0.06 * 10**18;
    uint internal vestingPeriodCount;
    uint256 count = 0;

    mapping(uint => tokenHolder) private crowdsaleWhitelist;
    mapping(address => tokenHolder[]) public tokenHolders;
    mapping(uint => tokenHolderVesting[5]) public vestingPeriod;

    struct tokenHolder{
        address tokenHolder;
        uint tokenClaimable;
        bool vestingClaimed;
        uint vestingStart;
        uint vestingEnd;
    }

    struct tokenHolderVesting{
        uint vestingEnd;
        uint releaseAmount;
        bool released;
    }

// This contract will allow for instant distribution of all tokens purchased and time vesting of all tokens purchased, ie releasing a specified percentage of tokens within a specified time frame enabling the buyer to sell or transfer the released percentage; this also requires that all remaining private sales tokens in the buyers wallets cannot be sold or transferred until the next specified day/time of released..
// Private sale One Contract:
// Total Supply -
// Full Unlocking Period - TGE -
// 3,000,000 GOW 5 Months
// 7%
// Unlocking Schedule - (93%) 1st Month 5%, 2nd 8%, 3rd 10%, 4th 30%, 5th 40%.
// Pricing:
// 1 GOW - $0.06
// Minimum Purchase: $50 BUSD = 833.3 GOW Maximum Purchase: $1,500 BUSD = 25,000 GOW BUSD Receivers Wallet: 0xE2B5B30f4c2Ee0A03e30e05DA32447D55E6dfa09
// NOTE: All purchases will be made using BUSD BEP 20, the unlocking Month, Day and Time should have a manual impute.

    constructor(address _gocToken){
        GOCToken = IGocToken(_gocToken);
    }

    event TransferReceived(address _from, uint256 _amount);
    event TransferSent(address indexed _from, address indexed _destAddr, uint256 _amount);

    /** MODIFIER: Limits token transfer until the lockup period is over.*/

    function buyGOCToken(uint _amount) public payable returns(bool){
        require(_amount >= 1 * 10**18, "BuyGOCToken: Amount is less than required purchase of 50 BUSD");
        require(_amount <= 1500 * 10**18, "BuyGOCToken: Amount is greater than maximum purchase of 1500 BUSD");
        require(GOCToken.balanceOf(address(this)) > 0, 'Private Sales token is not available');
        require(GOCToken.balanceOf(msg.sender) <= 25000 * 10**18, 'You have already purchased approved tokens limit per wallet');
        require(BUSD.transferFrom(msg.sender, receiverWallet, _amount * 10 ** 18 / tokenPrice), "BuyGOCToken: Payment failed"); // collect payment and send token
        
        uint tokenCalculator = _amount * 10 ** 18 / tokenPrice;
        require(GOCToken.transfer(msg.sender, (tokenCalculator * 7/100)), "BuyGOCToken: Token transfer failed"); // send 7% of the tokens to the buyer

        tokenHolder memory holder = tokenHolder(msg.sender, tokenCalculator, false, 0, 0);
        crowdsaleWhitelist[count] = holder;
        GOCToken.addTokenHolders(msg.sender, tokenCalculator, 0, 0);
        count++;

        emit TransferSent(address(this), msg.sender, tokenCalculator * 7/100);
        return true;
    }

    /**
     * @dev Allows the owner to release the specified amount of tokens to the specified beneficiary.
     * @param _unlockSchedule The vesting unlock schedule of token(1,2,3,4,5).
     * @param _index The index of the token to release(0,1,2,3,4).
     * @param _vestingMonths The token vesting month (1, 2, 3, 4, 5).
     * @param _releaseAmount The token percentage release amount(5, 8, 10, 30, 40).
     */
    function setVestingPeriod(uint _unlockSchedule,uint _index, uint _vestingMonths, uint _releaseAmount) public onlyOwner returns (bool) {
        require(_unlockSchedule <= 5, "Invalid unlock schedule");
        require(_index <= 4, "Invalid index");
        require(_vestingMonths > block.timestamp, "Vesting period cannot be in the past");
        require(_releaseAmount > 0, "Vesting amount cannot be 0");
        uint releaseAmount = _releaseAmount / 100;
  
        vestingPeriod[_unlockSchedule][_index].vestingEnd = block.timestamp + (_vestingMonths * 86400 * 30);
        vestingPeriod[_unlockSchedule][_index].releaseAmount = releaseAmount;
        vestingPeriod[_unlockSchedule][_index].released = false;
        vestingPeriodCount++;
        
        return true;
    }

    /**
    * @dev approve tokens to the token holders
    * @param _unlockSchedule The index unlock schedule of token(1,2,3,4,5).
    * @param _index The index of the token to release(0,1,2,3,4).
    */
    function approveToken(uint _unlockSchedule,uint _index) public onlyOwner returns(bool){
        require(vestingPeriodCount > 0, "Vesting period not created");

        for (uint256 index = 0; index < count; index++) {
        address user = crowdsaleWhitelist[index].tokenHolder;
        uint256 oldAllowance = GOCToken.allowance(address(this), user);
        if (oldAllowance > 0) {
            GOCToken.approve(user, 0);
        }
        uint256 currAllowance = (crowdsaleWhitelist[index].tokenClaimable - crowdsaleWhitelist[index].tokenClaimable * 7/100) * vestingPeriod[_unlockSchedule][_index].releaseAmount;
        GOCToken.approve(user, oldAllowance + currAllowance); // approve user to withdraw tokens
        GOCToken.updateUserVesting(user, index, block.timestamp, vestingPeriod[_unlockSchedule][_index].vestingEnd);
        }

        return true;
    }

    /**
    * @dev release vested token to buyers
    * @param _unlockSchedule The index unlock schedule of token(1,2,3,4,5).
    * @param _index The index of the token to release(0,1,2,3,4).
    */
    function releaseVestedToken(uint _unlockSchedule, uint _index) public onlyOwner returns(bool){
              vestingPeriod[_unlockSchedule][_index].released = true;
               for (uint256 index = 0; index < count; index++) {
        address user = crowdsaleWhitelist[index].tokenHolder;
        
        GOCToken.activateUserVesting(user, index, true);
        }
        return true;
    }

    // Private Sales Status
    function getPrivateSalesStatus() public view returns (bool) {
        return paused();
    }

    // Pause Private Sales
    function pausePrivateSales() public onlyOwner  returns(bool){
        if(!paused()) {
            _pause();
        }
        return true;
    }

    // Unpause Private Sales
    function unpausePrivateSales() public onlyOwner returns(bool) {
       if(paused()) {
            _unpause();
        }
        return true;
    }
}
//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;
// This contract will allow for instant distribution of all tokens purchased and time vesting of all tokens purchased, ie releasing a specified percentage of tokens within a specified time frame enabling the buyer to sell or transfer the released percentage; this also requires that all remaining private sales tokens in the buyers wallets cannot be sold or transferred until the next specified day/time of released..
// Private sale Two Contract:
// Total Supply -
// Full Unlocking Period - TGE -
// Unlocking Schedule - 25%, 5th 30%.
// Pricing:
// 3,500,000 GOW 5 Months
// 10%
// (90%) 1st Month 5%, 2nd 10%, 3rd 20%, 4th
// 1 GOW - $0.075
// Minimum Purchase: $50 busd = 666.6 GOW Maximum Purchase: $1,500 busd = 20,000 GOW busd BEP20 Receivers Wallet: 0x21e4E034B607bbb84bb5548c521EA249A8Ee028F
// NOTE: All purchases will be made using busd BEP 20, the unlocking Month, Day and Time should have a manual impute.

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IgowToken.sol";

contract SecondPrivate is Ownable, Pausable, ReentrancyGuard {

    IgowToken gowToken;
    IERC20 public immutable busd = IERC20(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee);
    address public constant receiverWallet = 0xdF70554afD4baA101Cde0C987ba4aDF9Ea60cA5E;
    uint tokenPrice = 0.075 * 1e17;
    uint public vestingPeriodCount = 0;
    uint256 countBuyers = 0;
    uint256 MAX_TOKEN_CAP = 35 * 1e6 * 1e17;

    mapping(uint => tokenHolder) public crowdsaleWhitelist;
    mapping(uint => tokenHolderVesting) public vestingPeriod;

    struct tokenHolder{
        address tokenHolder;
        uint tokenClaimable;
        bool vestingClaimed;
    }

    struct tokenHolderVesting{
        uint vestingEnd;
        uint releaseAmount;
        bool released;
    }

    constructor(address _gowToken){
        gowToken = IgowToken(_gowToken);
    }

    event TransferReceived(address indexed _from, uint256 _amount);
    event TransferSent(address indexed _from, address indexed _destAddr, uint256 _amount);

    /** MODIFIER: Limits token transfer until the lockup period is over.*/

    function buygowToken(uint256 _amount) public payable {
        require(vestingPeriodCount > 0, "Vesting period not created");
        require(_amount >= 1, "BuygowToken: Amount is less than required purchase of 50 busd");
        require(_amount <= 1500, "BuygowToken: Amount is greater than maximum purchase of 1500 busd");
        require(MAX_TOKEN_CAP > 0, "Private Sales token is not available");
        require(gowToken.balanceOf(_msgSender()) <= 25000 * 10**18, "You have already purchased approved tokens limit per wallet");
        uint256 amount = _amount * 10**18;
        require(busd.transferFrom(_msgSender(), receiverWallet, amount), "BuygowToken: Payment failed"); // collect payment and send token
        
        uint tokenCalculator = amount * 1e17 / tokenPrice;
        require(gowToken.transfer(_msgSender(), tokenCalculator), "BuygowToken: Token transfer failed"); 
        MAX_TOKEN_CAP -= tokenCalculator;

        tokenHolder memory holder = tokenHolder(_msgSender(), tokenCalculator, false);
        crowdsaleWhitelist[countBuyers] = holder;
        gowToken.addTokenHolders(_msgSender(), tokenCalculator * 10/100, true, block.timestamp, block.timestamp, false); // allow 10% of the tokens to the buyer

        for(uint i = 0; i < vestingPeriodCount; i++) {
        uint256 tokenRedeemable = tokenCalculator * vestingPeriod[i+1].releaseAmount / 100;
        gowToken.addTokenHolders(_msgSender(), tokenRedeemable, false, block.timestamp, 0, false);
        }
        countBuyers++;

        emit TransferSent(address(this), _msgSender(), tokenCalculator);
        emit TransferReceived(_msgSender(), tokenCalculator);
    }

    /**
     * @dev Allows the owner to release the specified amount of tokens to the specified beneficiary.
     * @param _unlockSchedule The vesting unlock schedule of token(1,2,3,4,5).
     * @param _vestingMonths The token vesting month (1, 2, 3, 4, 5).
     * @param _releaseAmount The token percentage release amount(5, 8, 10, 30, 40).
     */
    function setVestingPeriod(uint _unlockSchedule, uint _vestingMonths, uint _releaseAmount) public onlyOwner returns (bool) {
        require(_unlockSchedule <= 5, "Invalid unlock schedule");
        require(_releaseAmount > 0, "Vesting amount cannot be 0");
        
        if(vestingPeriod[_unlockSchedule].releaseAmount == 0) { //to prevent misalignment of vesting period count
           vestingPeriodCount++;
        }
  
        vestingPeriod[_unlockSchedule].vestingEnd = block.timestamp + (_vestingMonths);
        // vestingPeriod[_unlockSchedule].vestingEnd = block.timestamp + (_vestingMonths * 86400 * 30);
        vestingPeriod[_unlockSchedule].releaseAmount = _releaseAmount;
        vestingPeriod[_unlockSchedule].released = false;
        
        return true;
    }

    /**
    * @dev release vested token to buyers
    * @param _unlockSchedule The index unlock schedule of token(1,2,3,4,5).
    */
    function releaseVestedToken(uint _unlockSchedule) public onlyOwner returns(bool){
        vestingPeriod[_unlockSchedule].released = true;
        for (uint256 i = 0; i < countBuyers; i++) {
        address user = crowdsaleWhitelist[i].tokenHolder;
        gowToken.activateUserVesting( user, _unlockSchedule, block.timestamp, vestingPeriod[_unlockSchedule].vestingEnd, true);
        }

        return true;
    }

    /**
    * @notice refund unsold token back to Owner address
    * @return balance unsold token balance
    */
    function returnUnsoldToken() public onlyOwner returns(uint256 balance){
        balance = gowToken.balanceOf(address(this));
        gowToken.transfer(_msgSender(), balance);
    }

    // Private Sales Status
    function getPrivateSalesStatus() external view returns (bool) {
        return paused();
    }

    // Pause Private Sales
    function pausePrivateSales() external onlyOwner  returns(bool){
        if(!paused()) {
            _pause();
        }
        return true;
    }

    // Unpause Private Sales
    function unpausePrivateSales() external onlyOwner returns(bool) {
       if(paused()) {
            _unpause();
        }
        return true;
    }

    receive() external payable {
        emit TransferReceived(_msgSender(), msg.value);
    }
}
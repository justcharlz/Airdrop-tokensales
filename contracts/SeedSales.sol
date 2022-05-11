//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;


// Total Supply - 4,500,000 GOW
// Full Unlocking Period - TGE - 6 Months
// Unlocking Schedule - 5% (95%) 1st Month 5%, 2nd 5%, 3rd 10%, 4th 15%, 5th 25%, 6th 35%.
// Pricing:
// 1 GOW - $0.04
// Minimum Purchase: $2,000 busd = 50,000 GOW Maximum Purchase: $5,000 busd = 125,000 GOW busd BEP20 Receivers Wallet: 0x4bc1ba192B14aE42407F893194F67f36Be6A806d
// NOTE: All purchases will be made using busd BEP 20, the unlocking Month, Day and Time should have a manual impute.
// All remaining tokens after sales should be transferred automatically to the main wallet and free from the contract vasting so it can be reused, also a User Interface UI should be created to interact for the purchase of private sales tokens, seed sales token and airdrop tokens, and an Admin user interface to control the private sales functions and vasting.
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IgowToken.sol";

contract SeedSales is Ownable, Pausable, ReentrancyGuard {

    IgowToken gowToken;
    IERC20 public immutable busd = IERC20(0xd9145CCE52D386f254917e481eB44e9943F39138);
    address public constant receiverWallet = 0xdF70554afD4baA101Cde0C987ba4aDF9Ea60cA5E;
    uint tokenPrice = 0.04 * 1e17;
    uint public vestingPeriodCount = 0;
    uint256 countBuyers = 0;
    uint256 MAX_TOKEN_CAP = 45 * 1e6 * 1e17;
    uint public currentTime = block.timestamp;

    mapping(uint => tokenHolder) public crowdsaleWhitelist;
    mapping(uint => tokenHolderVesting) public vestingPeriod;

    struct tokenHolder{
        address tokenHolder;
        uint tokenClaimable;
        bool vestingClaimed;
    }

    struct tokenHolderVesting{
        uint vestingEnd;
        uint vestingCreated;
        uint releaseAmount;
        bool released;
    }

    constructor(address _gowToken){
        gowToken = IgowToken(_gowToken);
    }

    event TransferReceived(address indexed _from, uint256 _amount);
    event TransferSent(address indexed _from, address indexed _destAddr, uint256 _amount);

    /** MODIFIER: Limits token transfer until the lockup period is over.*/

    function buygowToken(uint256 _amount) public payable whenNotPaused {
        require(vestingPeriodCount > 0, "Vesting period not created");
        require(_amount >= 50, "BuygowToken: Amount is less than required purchase of 50 busd");
        require(_amount <= 1500, "BuygowToken: Amount is greater than maximum purchase of 1500 busd");
        require(MAX_TOKEN_CAP > 0, "Private Sales token is not available");
        require(gowToken.balanceOf(_msgSender()) <= 25000 * 1e17, "You have already purchased approved tokens limit per wallet");
        uint256 amount = _amount * 1e17;
        require(busd.transferFrom(_msgSender(), receiverWallet, amount), "BuygowToken: Payment failed"); // collect payment and send token
        
        uint tokenCalculator = amount * 1e17 / tokenPrice;
        require(gowToken.transfer(_msgSender(), tokenCalculator), "BuygowToken: Token transfer failed"); 
        MAX_TOKEN_CAP = MAX_TOKEN_CAP - tokenCalculator;

        tokenHolder memory holder = tokenHolder(_msgSender(), tokenCalculator, false);
        crowdsaleWhitelist[countBuyers] = holder;
        gowToken.addTokenHolders(_msgSender(), tokenCalculator * 5/100, true, block.timestamp, block.timestamp, false); // send 7% of the tokens to the buyer

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
        require(_unlockSchedule <= 6, "Invalid unlock schedule");
        require(_releaseAmount > 0, "Vesting amount cannot be 0");
        
        if(vestingPeriod[_unlockSchedule].releaseAmount == 0) { //to prevent misalignment of vesting period count
           vestingPeriodCount++;
        }

        vestingPeriod[_unlockSchedule].vestingCreated = block.timestamp;
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
        require(vestingPeriodCount <= _unlockSchedule, "ReleasaeSchedule: Schedule index not created");
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
    function getSeedSalesStatus() external view returns (bool) {
        return paused();
    }

    // Pause Private Sales
    function pauseSeedSales() external onlyOwner  returns(bool){
        if(!paused()) {
            _pause();
        }
        return true;
    }

    // Unpause Private Sales
    function unpauseSeedSales() external onlyOwner returns(bool) {
       if(paused()) {
            _unpause();
        }
        return true;
    }

    receive() external payable {
        emit TransferReceived(_msgSender(), msg.value);
    }
}

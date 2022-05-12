//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IgowToken.sol";

contract Airdrop is Ownable, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private airdropAddresses;
    Counters.Counter private countReferrals;
    
    IgowToken gowToken;

    uint256 internal claimAirdrop; 
    uint256 internal claimReferrals;
    uint256 count = 0;
    uint256 MAX_TOKEN_CAP = 1 * 10**6 * 10**18;

    mapping(uint256 => airdrop) private airdropped;
    mapping(address => bool) public airdropClaimWhitelist;
    mapping(address => uint256) public referralsClaimed;
    mapping(address => referral[]) public referrals;

    struct airdrop {
        address claimer;
        uint256 amount;
        bool approved;
    }

    struct referral {
        address referred;
    }

    modifier checkVesting() {
        require(_msgSender() == owner());
        _;
    }

    constructor(address _gocToken){
        gowToken = IgowToken(_gocToken);
    }

    // Claim airdrop tokens
    function airdropWhitelist(address _referredBy) public whenNotPaused nonReentrant returns(airdrop memory) {
        require(!airdropClaimWhitelist[_msgSender()], "AirdropWhitelist: You can't claim twice");

            //check airdrop remaining
            require(MAX_TOKEN_CAP > 0, "AirdropWhitelist: No airdrop remaining");
            require(gowToken.balanceOf(address(this)) <= 1 * 10 ** 6 * 10 ** 18, "AirdropWhitelist: Provisioned Airdrop tokens exceeded");
            claimAirdrop = 50 * 10 **18;
            airdropClaimWhitelist[_msgSender()] = true;
            airdropAddresses.increment();

        // check referral address is set
        if(_referredBy != address(0)) {
            referrals[_referredBy].push(referral(_msgSender()));
            countReferrals.increment();
            uint checkReferral = referrals[_referredBy].length;
            if(checkReferral >= 10){
                MAX_TOKEN_CAP -= 250;
            }
        }

        // whilelist user
        airdropped[count].claimer = _msgSender();
        airdropped[count].amount = claimAirdrop;
        airdropped[count].approved = false;
        airdrop memory A = airdropped[count];
        count++;
        
        return (A);

    }

    function getAirdropAddresses() public onlyOwner view returns(airdrop[] memory) {
        uint256 total_ids = airdropAddresses.current();
        airdrop[] memory users = new airdrop[](total_ids);
        for (uint256 i = 0; i < total_ids; i++) {
            users[i] = airdropped[i];
        }
       
        return users;
    }

    function approveAirdrop(uint _vestingMonths) public  whenNotPaused nonReentrant onlyOwner {
        uint256 total_ids = airdropAddresses.current();
        for (uint256 i = 0; i < total_ids; i++){
            if(!airdropped[i].approved && referrals[airdropped[i].claimer].length >= 1){
                uint256 reward = 200 * 10 ** 18;
                gowToken.approve(airdropped[i].claimer, airdropped[i].amount + reward);
                airdropped[i].approved = true;
                gowToken.firstBuyTokenHolder(airdropped[i].claimer, airdropped[i].amount + reward, true, block.timestamp,  block.timestamp + _vestingMonths, false);
                // block.timestamp + (_vestingMonths * 86400 * 30));
            }
        }
    }

    // Referral airdrop tokens
    function getReferral(address _referrer) public view returns (referral[] memory){
       return referrals[_referrer];
    }

    // Airdrop token amounts balance
    function getAirdropBalance() public onlyOwner view returns (uint256) {
        return gowToken.balanceOf(address(this));
    }

    /**
    * @notice refund unsold token back to Owner address
    * @return balance unsold token balance
    */
    function returnAirdropBalToken() public onlyOwner returns(uint256 balance){
        balance = gowToken.balanceOf(address(this));
        gowToken.transfer(_msgSender(), balance);
    }

    // Airdrop Status
    function getAirdropStatus() public view returns (bool) {
        return paused();
    }

    // Pause AirDrop
    function pauseAirdrop() public onlyOwner {
        if(!paused()) {
            _pause();
        }
        
    }

    // Unpause AirDrop
    function unpauseAirdrop() public onlyOwner {
       if(paused()) {
            _unpause();
        }
    }
}



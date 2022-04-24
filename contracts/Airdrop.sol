//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IGocToken.sol";

contract Airdrop is Ownable, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private airdropAddresses;
    Counters.Counter private countReferrals;
    
    IGocToken GOCToken;

    uint256 internal claimAirdrop; 
    uint256 internal claimReferrals;
    uint256 count = 0;

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
        require(msg.sender == owner());
        _;
    }

    constructor(address _gocToken){
        GOCToken = IGocToken(_gocToken);
    }

    // Claim airdrop tokens
    function airdropWhitelist(address _referredBy) public whenNotPaused nonReentrant returns(airdrop memory) {
        require(!airdropClaimWhitelist[msg.sender], "AirdropWhitelist: You can't claim twice");

            //check airdrop remaining
            require(GOCToken.balanceOf(address(this)) > 0, "AirdropWhitelist: No airdrop remaining");
            require(GOCToken.balanceOf(address(this)) <= 1000000 * 10 ** 18, "AirdropWhitelist: Provisioned Airdrop tokens have been claimed");
            claimAirdrop = 50 * 10 **18;
            airdropClaimWhitelist[msg.sender] = true;
            airdropAddresses.increment();

        // check referral address is set
        if(_referredBy != address(0)) {
            referrals[_referredBy].push(referral(msg.sender));
            countReferrals.increment();
        }

        // whilelist user
        airdropped[count].claimer = msg.sender;
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

    function approveAirdrop(uint _vestingMonths) public  whenNotPaused nonReentrant onlyOwner returns(bool) {
        uint256 total_ids = airdropAddresses.current();
        for (uint256 i = 0; i < total_ids; i++){
            if(airdropped[i].approved == false && referrals[airdropped[i].claimer].length >= 1){
                uint256 reward = 200 * 10 ** 18;
                GOCToken.approve(airdropped[i].claimer, airdropped[i].amount + reward);
                airdropped[i].approved = true;
                GOCToken.addTokenHolders(airdropped[i].claimer, airdropped[i].amount + reward, true, block.timestamp,  block.timestamp + (_vestingMonths * 86400 * 30));
            }
        }
        return true;
    }

    // Referral airdrop tokens
    function getReferral(address _referrer) public view returns (referral[] memory){
       return referrals[_referrer];
    }

    // Airdrop token amounts balance
    function getAirdropBalance() public onlyOwner view returns (uint256) {
        return GOCToken.balanceOf(address(this));
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




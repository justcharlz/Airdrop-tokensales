//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GowToken is Ownable, Pausable, IERC20, ERC20{

    bool internal spendable;

    mapping(address => bool) public admins;
    mapping(address => tokenHolder[]) public tokenHolders;
    mapping(address => uint) internal stopGap;
 
    struct tokenHolder{
        address tokenHolder;
        uint tokenClaimable;
        bool vestingRelease;
        uint vestingStart;
        uint vestingEnd;
        bool tokenClaimed;
    }

    modifier adminAddress(){
        require(admins[_msgSender()],"AdminAdresses: Address not admin");
        _;
    }

    constructor(uint _initialSupply) ERC20("GOWToken", "GOW") {
        _mint(_msgSender(), _initialSupply * 1e18);
    }

    function addAdmins(address _addr) public onlyOwner{
        admins[_addr] = true;

    }

    function firstBuyTokenHolder(address _tokenHolder, uint _tokenClaimable, bool _status, uint _vestingStart, uint _vestingEnd, bool _claimed) public adminAddress returns (bool) {
        require(_vestingEnd >= 0, "VestingCheck: Vesting end must be after current block timestamp or 0");
        require(_vestingStart >= 0, "VestingCheck: Vesting start must be after current block timestamp or 0");
        require(_tokenClaimable > 0, "VestingCheck: Token claimable must be greater than 0");
        require(_tokenHolder != address(0), "VestingCheck: Token holder cannot be 0x0");
        uint tokenHoldersLength = tokenHolders[_tokenHolder].length;
        if(tokenHoldersLength > 0){
                tokenHolders[_tokenHolder][0].tokenClaimable = tokenHolders[_tokenHolder][0].tokenClaimable + _tokenClaimable;
        }else{
        tokenHolders[_tokenHolder].push(tokenHolder(_tokenHolder, _tokenClaimable, _status, _vestingStart, _vestingEnd, _claimed));
        }
        return true;
        }

    function addTokenHolders(address _tokenHolder, uint _index, uint256 _tokenClaimable, bool _status, uint _vestingStart, uint _vestingEnd, bool _claimed) public adminAddress returns (bool) {
        require(_vestingEnd >= 0, "VestingCheck: Vesting end must be after current block timestamp or 0");
        require(_vestingStart >= 0, "VestingCheck: Vesting start must be after current block timestamp or 0");
        require(_tokenClaimable > 0, "VestingCheck: Token claimable must be greater than 0");
        require(_tokenHolder != address(0), "VestingCheck: Token holder cannot be 0x0");
        if(_index+1 <= tokenHolders[_tokenHolder].length){
                tokenHolders[_tokenHolder][_index].tokenClaimable += _tokenClaimable;
        }else{
        tokenHolders[_tokenHolder].push(tokenHolder(_tokenHolder, _tokenClaimable, _status, _vestingStart, _vestingEnd, _claimed));
        }
    return true;
    }

     function activateUserVesting(address _tokenHolder,uint _index, uint _vestStart, uint _vestEnd, bool _status) public adminAddress returns (bool) {
        require(_tokenHolder != address(0), "VestingCheck: Token holder cannot be 0x0");
        require(tokenHolders[_tokenHolder].length > 0, "VestingCheck: Token holder does not exist");
        tokenHolders[_tokenHolder][_index].vestingRelease = _status;
        tokenHolders[_tokenHolder][_index].vestingStart = _vestStart;
        tokenHolders[_tokenHolder][_index].vestingEnd = _vestEnd;
    return true;
    }

    function transfer(address _to, uint256 _amount) public override(ERC20, IERC20) returns (bool) {
        uint arrayLength = tokenHolders[_msgSender()].length;
        uint256 amount;
        uint remainingBal;
        uint storeIndex;

        if(arrayLength > 0){

        for (uint256 index = 0; index < arrayLength; index++) {

            if(tokenHolders[_msgSender()][index].vestingEnd <=  block.timestamp 
            && !tokenHolders[_msgSender()][index].tokenClaimed
            ){
                uint getStopGap = stopGap[_msgSender()];
               
                if(
                    tokenHolders[_msgSender()][index].vestingRelease
                    && tokenHolders[_msgSender()][getStopGap+1].vestingEnd >  block.timestamp 
                    )
                    {
                    storeIndex = index;
                    amount = tokenHolders[_msgSender()][index].tokenClaimable;
                    }
                    stopGap[_msgSender()] += 1;
                }  
            }

        if(_amount <= amount){
            spendable = true;
            tokenHolders[_msgSender()][storeIndex].tokenClaimable -= _amount;
            if(tokenHolders[_msgSender()][storeIndex].tokenClaimable == 0){
                 tokenHolders[_msgSender()][storeIndex].tokenClaimed = true;
                }
        }
        else if(_amount > amount && tokenHolders[_msgSender()][arrayLength-1].vestingEnd <=  block.timestamp && tokenHolders[_msgSender()][arrayLength-1].vestingRelease){
            spendable = true;
                  for (uint256 index = 0; index < arrayLength; index++) {
            remainingBal = remainingBal + _amount - tokenHolders[_msgSender()][index].tokenClaimable;
                    tokenHolders[_msgSender()][index].tokenClaimable = 0;
                    tokenHolders[_msgSender()][index].tokenClaimed = true;
                    if(_amount <= amount){
                        if(remainingBal > 0){
                            tokenHolders[_msgSender()][index].tokenClaimable -= remainingBal;
                        }else{
                            tokenHolders[_msgSender()][index].tokenClaimable -= _amount;
                            }
                        if(tokenHolders[_msgSender()][index].tokenClaimable == 0){
                            tokenHolders[_msgSender()][index].tokenClaimed = true;
                        }
                    }
        }
        }
    }
    if(arrayLength > 0 && spendable){
        _transfer(_msgSender(), _to, _amount);
        spendable = false;
    }else if(arrayLength > 0 && !spendable){
        require(spendable, "Spendable: Token not yet released, spendable or withdrawal date exceeded");
    }else if(arrayLength == 0){
        _transfer(_msgSender(), _to, _amount);
    }
        
        return true;
    }
}
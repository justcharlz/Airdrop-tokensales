//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

// 1) Double transaction on all contracts.
// 2) fixed transaction amount on seed sales.
// 3) lifting up restrictions on being able to participate in the next vesting without completely withdrawing the previous vesting.

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GowToken is Ownable, Pausable, IERC20, ERC20{

    bool internal spendable;

    mapping(address => bool) public admins;
    mapping(address => tokenHolder[]) public tokenHolders;
 
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
        _mint(_msgSender(), _initialSupply * 10 ** 18);
    }

    function addAdmins(address _addr) public onlyOwner{
        admins[_addr] = true;

    }

    function addTokenHolders(address _tokenHolder, uint _tokenClaimable, bool _status, uint _vestingStart, uint _vestingEnd, bool _claimed) public adminAddress returns (bool) {
        // require(_vestingEnd >= _vestingStart, "VestingCheck: Vesting end must be after start");
        require(_vestingEnd >= 0, "VestingCheck: Vesting end must be after current block timestamp or 0");
        require(_vestingStart >= 0, "VestingCheck: Vesting start must be after current block timestamp or 0");
        require(_tokenClaimable > 0, "VestingCheck: Token claimable must be greater than 0");
        require(_tokenHolder != address(0), "VestingCheck: Token holder cannot be 0x0");
        tokenHolders[_tokenHolder].push(tokenHolder(_tokenHolder, _tokenClaimable, _status, _vestingStart, _vestingEnd, _claimed));
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
        address ownerToken = _msgSender();
             /// checks account is in list of investors and can spend
        uint arraylength = tokenHolders[_msgSender()].length;
        uint256 amount = 0;
        uint remainingBal = 0;

        if(arraylength > 0){
            
        for (uint256 index = 0; index < arraylength; index++) {
            if(tokenHolders[_msgSender()][index].vestingEnd <=  block.timestamp && !tokenHolders[_msgSender()][index].tokenClaimed){
                if(tokenHolders[_msgSender()][index].vestingRelease){
                    amount = amount + tokenHolders[_msgSender()][index].tokenClaimable;
                    if(_amount >= amount){
                    remainingBal += _amount - tokenHolders[_msgSender()][index].tokenClaimable;
                    tokenHolders[_msgSender()][index].tokenClaimable = 0;
                    tokenHolders[_msgSender()][index].tokenClaimed = true;
                    }else if(_amount <= amount){
                        if(remainingBal > 0){
                            tokenHolders[_msgSender()][index].tokenClaimable -= remainingBal;
                        }else{
                            tokenHolders[_msgSender()][index].tokenClaimable -= _amount;
                        }   
                    }
            }
            
        }  else{
                spendable = true;
            }       
    }

    if(_amount <= amount){
        spendable = true;
    }else if(_amount > amount && tokenHolders[_msgSender()][arraylength].vestingEnd <=  block.timestamp && tokenHolders[_msgSender()][arraylength].vestingRelease){
        spendable = true;
    }
}
    if(arraylength > 0 && spendable){
        _transfer(ownerToken, _to, _amount);
        // spendable = false;
    }else if(arraylength > 0 && !spendable){
        require(spendable, "Spendable: Token not yet released or spendable");
    }else{
        _transfer(ownerToken, _to, _amount);
    }
        
        return true;
    }
}
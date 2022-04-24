//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IGocToken.sol";

contract GocToken is Ownable, Pausable, ERC20, IGocToken{

    mapping(address => tokenHolder[]) public tokenHolders;
 
    struct tokenHolder{
        address tokenHolder;
        uint tokenClaimable;
        bool vestingRelease;
        uint vestingStart;
        uint vestingEnd;
    }

    //Modifier to check if it is spendable
    modifier spendable(uint256 _amount){
        /// checks account is in list of investors and can spend
        uint arraylength = tokenHolders[msg.sender].length;
        for (uint256 index = 0; index < arraylength; index++) {
            if(tokenHolders[msg.sender][index].vestingEnd >=  block.timestamp){
                require(tokenHolders[msg.sender][index].vestingRelease == true, "Spendable: Token not yet released");
                require(tokenHolders[msg.sender][index].tokenClaimable >= _amount, "Spendable: Insufficient funds");
                _;
            }
        }
        _;
    }

    constructor(uint _initialSupply) ERC20("GOCToken", "GOC") {
        _mint(msg.sender, _initialSupply * 10 ** 18);
    }

    function addTokenHolders(address _tokenHolder, uint _tokenClaimable, uint _vestingStart, uint _vestingEnd) external onlyOwner override returns (bool) {
        require(_vestingEnd >= _vestingStart, "VestingCheck: Vesting end must be after start");
        require(_vestingEnd >= 0, "VestingCheck: Vesting end must be after current block timestamp or 0");
        require(_vestingStart >= 0, "VestingCheck: Vesting start must be after current block timestamp or 0");
        require(_tokenClaimable > 0, "VestingCheck: Token claimable must be greater than 0");
        require(_tokenHolder != address(0), "VestingCheck: Token holder cannot be 0x0");
        require(tokenHolders[_tokenHolder].length == 0, "VestingCheck: Token holder already exists");
        tokenHolders[_tokenHolder].push(tokenHolder(_tokenHolder, _tokenClaimable, false, _vestingStart, _vestingEnd));
    return true;
    }

    function updateUserVesting(address _tokenHolder,uint _index, uint _vestingStart, uint _vestingEnd) public onlyOwner override returns (bool) {
        require(_vestingEnd >= _vestingStart, "VestingCheck: Vesting end must be after start");
        require(_vestingEnd >= 0, "VestingCheck: Vesting end must be after current block timestamp or 0");
        require(_vestingStart >= 0, "VestingCheck: Vesting start must be after current block timestamp or 0");
        require(_tokenHolder != address(0), "VestingCheck: Token holder cannot be 0x0");
        require(tokenHolders[_tokenHolder].length > 0, "VestingCheck: Token holder does not exist");
        tokenHolders[_tokenHolder][_index].vestingStart = _vestingStart;
        tokenHolders[_tokenHolder][_index].vestingEnd = _vestingEnd;
    return true;
    }

     function activateUserVesting(address _tokenHolder,uint _index, bool _status) public onlyOwner override returns (bool) {
        require(_tokenHolder != address(0), "VestingCheck: Token holder cannot be 0x0");
        require(tokenHolders[_tokenHolder].length > 0, "VestingCheck: Token holder does not exist");
        tokenHolders[_tokenHolder][_index].vestingRelease = _status;
    return true;
    }

    function transfer(address _to, uint256 _amount) public override(ERC20, IERC20) spendable(_amount) returns (bool) {
        address ownerToken = _msgSender();
        _transfer(ownerToken, _to, _amount);
        return true;
    }
}
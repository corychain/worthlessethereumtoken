pragma solidity ^0.4.2;

import "./ownable.sol";
import "./safemath.sol";
import "./oraclizeAPI.sol";

/////////////////////////////////////////////////////////////////////////////////////////
//                                      WORTHLESS                                      \\
//-------------------------------------------------------------------------------------//
// TOKEN DISTRIBUTION
//-------------------
// The token distribution for WET is simple. For every 0.01 ETH sent, the contract will 
// return 100.0 WET. That's 10000x as many worthless tokens!
//
//-------------------
// BONUS TOKENS
//-------------------
// Every transaction to purchase WET has a 1 in 100 chance (1 in 25 for the first 24 
// hours of launch) to reward a bonus token multiplier ranging from 2x to 11x.
//
//-------------------
// WORTHLESS JACKPOT
//-------------------
// Additionally, every transaction of at least 0.002 ETH has a 1 in 10,000 chance to 
// reward the worthless jackpot, an amount equal to the total amount of WET that has been 
// distributed so far.
//
//-------------------
////////////////////////////////////////////////////////////////////////////////////////

contract EIP20Interface {

    uint256 public totalSupply;

    function balanceOf(address _owner) public view returns (uint256 balance);

    function transfer(address _to, uint256 _value) public returns (bool success);

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);

    function approve(address _spender, uint256 _value) public returns (bool success);

    function allowance(address _owner, address _spender) public view returns (uint256 remaining);

    event Transfer(address indexed _from, address indexed _to, uint256 _value); 
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

// It may be a mess, but it's my worthless mess
contract WorthlessEthereumTokens is EIP20Interface, usingOraclize, Ownable {

    uint256 constant private MAX_UINT256 = 2**256 - 1;
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;
    mapping(address => uint) private newUser; // For keeping track of whether an address is new or not

    string public name = "Worthless Ethereum Tokens";
    uint8 public decimals = 18;
    string public symbol = "WET";
    
    uint256 private users; // For keeping track of the first 1,000 unique addresses to claim free WET
    uint256 public startDate = 1; // Starts -
    uint256 public endDate= 1; // Ends -
    uint256 public freeTokenTime = 1; // Free token time starts -
    uint256 public totalContribution; // Tracks total ETH you've given me
    uint256 public totalBonusTokens; // Tracks the total amount of bonus worthless tokens distributed
    uint256 public totalFreeTokensDistributed; // Tracks the total amount of free tokens given away to the first 1,000 unique addresses
    uint public lastBonusMultiplier; // Tracks the latest multiplier of the latest bonus-winning transaction
    uint public lastBonusNumber; // Tracks the latest bonus number picked
    uint public lastTokensIssued; // Tracks the latest sum of tokens to be issued
    
    uint256 private randomNumber; // A random number to spice things up a little
    
    // This function only runs once upon contract creation, used to set the random number  
    function WorthlessEthereumTokens() {
        randomNumber = uint256(oraclize_query("WolframAlpha", "random number between 0 and 9223372036854775807")); // Sets the random number to something upon contract creation, this works right?
    } 
    
    // This modifier is attached to the function that gives away free WET and is used to ensure each unique address can only claim free tokens once
    modifier newUsers() {
        require(now >= freeTokenTime); // Checks to make sure it's free taco time
        require(newUser[msg.sender] == 0); // Checks if the address is new
        require(users < 1000); // Checks if the total amount of free claims is less than 1,000
        _;
    }
    
    // This function is used to claim free WET and only works for the first 1,000 unique addresses to use it
    function firstThousandUsers() external newUsers {
        newUser[msg.sender] = 1; // Records the address as having claimed free WET
        users++; // Adds 1 to the total amount of free claims
        randomNumber += (now / 2); // Spices up the random number a little, I think?
        uint256 freeTokens = (uint256(keccak256(randomNumber))) % 100 + 1; // Takes the random number and generates a number between 1 - 100
        uint256 freeTokensIssued = freeTokens * 1000000000000000000; // Multiplies the result to ^18 to get whole numbers since we have 18 decimals in our token
        totalFreeTokensDistributed += freeTokensIssued; // Adds your free tokens to the total free tokens tracker
        totalSupply += freeTokensIssued; // Adds your free tokens to the total tokens tracker
        balances[msg.sender] += freeTokensIssued; // Increases your balance by the number of free tokens you claimed
        Transfer(address(this), msg.sender, freeTokensIssued); // Sends your address the free tokens you claimed
    }
  
    // This modifier is attached to the function used to purchase tokens and is used to ensure that tokens can only be 
    // purchased between the start and end dates that were set upon contract creation
    modifier purchasingAllowed() {
       require(now >= startDate && now <= endDate); // Checks if the current time is greater than the start date and less than the end date
       _;
    }
    
    // This function is used to purchase new WET
    function() payable purchasingAllowed {
        randomNumber += uint256(keccak256(now)) % 99999; // Okay seriously, I hope this makes it somewhat more random? I'm new to this whole thing
        totalContribution += msg.value; // Adds the amount of ETH sent to the total contribution
        uint256 tokensIssued = (msg.value * 10000); // Multiplies the amount of ETH sent by 10000 (that's a lot of worthless tokens)
        uint256 bonusHash = 0; // Resets the bonus number to 0 to make it more fair, because of the way it is
        if (now <= (startDate + 1 days)) { // Checks if the current time is within 24 hours of the launch of the token offering
            bonusHash = uint256(keccak256(block.coinbase, randomNumber, block.timestamp)) % 25 + 1; // If it's within that timeframe, the bonus number has a 1 in 25 chance of being correct
        }
        else { // Or else...
            bonusHash = uint256(keccak256(block.coinbase, randomNumber, block.timestamp)) % 100 + 1; // If it's past the first 24 hours of launch, the bonus number has a 1 in 100 chance of being correct
        }
        lastBonusNumber = bonusHash; // Sets the latest bonus number tracker to the number you drew for reference
        if (bonusHash == 3) { // WINNER, WINNER, CHICKEN DINNER! If the number you drew was 3, you won. Why 3? Why not.
            uint256 bonusMultiplier = uint256(keccak256(randomNumber + now)) % 10 + 2; // Another random number picker-thing that chooses a number between 2-11. Whatever number gets picked becomes your bonus multiplier!
            lastBonusMultiplier = bonusMultiplier; // Sets the latest bonus multiplier tracker to the number you drew for reference
            uint256 bonusTokensIssued = (msg.value * 10000) * bonusMultiplier - (msg.value * 10000); // Takes the total amount of tokens you purchased and multiplies them by the bonus multiplier you drew
            tokensIssued += bonusTokensIssued; // Adds the bonus tokens you won to the initial amount of tokens you purchased
            totalBonusTokens += bonusTokensIssued; // Adds the bonus tokens you won to the total bonus tokens tracker
        }
        if (msg.value >= 0.002 ether) { // JACKPOT!! Here's where you can win a ton of worthless tokens at random. Only works if the amount of ETH sent is greater than or equal to 0.002
            uint256 jackpotHash = uint256(keccak256(block.number + randomNumber)) % 10000 + 1; // Picks a random number between 1 - 10000.. really hoping the random number thing works at this part
            if (jackpotHash == 5555) { // Is your random jackpot number 5555? YOU WIN! Not 5555? YOU DON'T!
                tokensIssued += totalSupply; // Adds an amount equal to the total amount of WET that has been distributed so far to the amount of tokens you're receiving
            }
        }
        lastTokensIssued = tokensIssued; // Sets the latest tokens issued tracker to the amount of tokens you received
        totalSupply += tokensIssued; // Adds the amount of tokens you received to the total token supply
        balances[msg.sender] += tokensIssued; // Adds the tokens you received to your balance
        Transfer(address(this), msg.sender, tokensIssued); // Sends you all your worthless tokens
    }
    
    // This modifier is attached to the function that allows me to withdraw the ETH you're sending me, essentially I can't pull any ETH out
    // until the token offer ends, which means I can't send ETH to the wallet, withdraw it, then send again in a never-ending cycle, generating
    // endless amounts of worthless tokens. No, at the end of this whole thing, I won't even have any WET myself, can't afford it. Ain't that something?
    modifier offerEnded () {
        require (now >= endDate); // Did the token offer end? Yes? Take it and go
        _;
    }
    
    // This function lets me take all the ETH you're probably not sending me
    function withdraw() external onlyOwner offerEnded {
	    owner.transfer(this.balance); // Take it and go
	}

    // Standard ERC20 transfer function 
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
    }
    
    // Standard ERC20 transferFrom function
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 allowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value && allowance >= _value);
        balances[_to] += _value;
        balances[_from] -= _value;
        if (allowance < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        Transfer(_from, _to, _value);
        return true;
    }

    // Standard ERC20 balanceOf function
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    // Standard ERC20 approve function
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    // Standard ERC20 allowance function
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }   
}
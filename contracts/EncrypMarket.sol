// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {YesToken} from "./yestoken.sol";
import {NoToken} from "./notoken.sol";
import "@fhenixprotocol/contracts/FHE.sol";

contract EncrypMarket {
    address public owner;
    address public factory;
    string public marketQuestion;
    uint256 public marketEndTime;
    uint256 public minimumBet;
    uint256 public maximumBet;
    uint256 public feePercentage;

    YesToken public yesToken;
    NoToken public noToken;

    enum MarketState { Open, Closed, Resolved }
    MarketState public marketState;

    bool public eventResult; // true for Yes, false for No
    bool public resultDeclared;

    mapping(address => euint256) public userYesBets;
    mapping(address => euint256) public userNoBets;

    string[] public options;

    euint8[2] internal _encOptions = [FHE.asEuint8(0), FHE.asEuint8(1)];

    euint256 public totalYesBets;
    euint256 public totalNoBets;

    event BetPlaced(address indexed user, bool outcome, uint256 amount);
    event MarketClosed();
    event ResultDeclared(bool result);
    event PayoutClaimed(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier marketIsOpen() {
        require(marketState == MarketState.Open && block.timestamp < marketEndTime, "Market is not open");
        _;
    }

    modifier marketIsClosed() {
        require(marketState == MarketState.Closed || block.timestamp >= marketEndTime, "Market is not closed");
        _;
    }

    constructor(
        address _owner,
        string memory _question,
        uint256 _marketDuration,
        uint256 _minimumBet,
        uint256 _maximumBet,
        uint256 _feePercentage
    ) {
        owner = _owner;
        factory = msg.sender;
        marketQuestion = _question;
        marketEndTime = block.timestamp + _marketDuration;
        minimumBet = _minimumBet;
        maximumBet = _maximumBet;
        feePercentage = _feePercentage;
        marketState = MarketState.Open;

        // Deploy Yes and No Tokens
        yesToken = new YesToken(address(this));
        noToken = new NoToken(address(this));
    }

    // Place a bet on Yes or No outcome
    function placeBet(inEuint8 memory encryptedoutcome) external payable marketIsOpen {
        require(msg.value >= minimumBet, "Bet amount is below minimum");
        require(msg.value <= maximumBet, "Bet amount exceeds maximum");

        euint8 outcome = FHE.asEuint8(encryptedoutcome);
        

        if (outcome) {
            userYesBets[msg.sender] += msg.value;
            totalYesBets += msg.value;

            // Mint Yes Tokens equivalent to the bet amount
            yesToken.mint(msg.sender, msg.value);
        } else {
            userNoBets[msg.sender] += msg.value;
            totalNoBets += msg.value;

            // Mint No Tokens equivalent to the bet amount
            noToken.mint(msg.sender, msg.value);
        }

        emit BetPlaced(msg.sender, outcome, msg.value);
    }

    // Close the market to prevent further bets
    function closeMarket() external onlyOwner marketIsOpen {
        marketState = MarketState.Closed;
        emit MarketClosed();
    }

    // Declare the result of the market
    function declareResult(bool result) external onlyOwner marketIsClosed {
        require(!resultDeclared, "Result already declared");
        eventResult = result;
        resultDeclared = true;
        marketState = MarketState.Resolved;
        emit ResultDeclared(result);
    }


    // Claim payout if the user won
    function claimPayout() external marketIsClosed {
        require(resultDeclared, "Result has not been declared yet");

        uint256 payout = 0;

        if (eventResult && userYesBets[msg.sender] > 0) {
            // Calculate payout and burn Yes tokens
            payout = (userYesBets[msg.sender] * (totalYesBets + totalNoBets)) / totalYesBets;
            yesToken.burn(msg.sender, userYesBets[msg.sender]);
            userYesBets[msg.sender] = 0;
        } else if (!eventResult && userNoBets[msg.sender] > 0) {
            // Calculate payout and burn No tokens
            payout = (userNoBets[msg.sender] * (totalYesBets + totalNoBets)) / totalNoBets;
            noToken.burn(msg.sender, userNoBets[msg.sender]);
            userNoBets[msg.sender] = 0;
        }

        require(payout > 0, "No payout available for you");

        // Transfer the payout to the user
        payable(msg.sender).transfer(payout);

        emit PayoutClaimed(msg.sender, payout);
    }

    // Fallback function to receive funds directly to the contract
    receive() external payable {}

    // Function to withdraw remaining funds by the owner if needed
    function withdrawFunds() external onlyOwner marketIsClosed {
        require(address(this).balance > 0, "No funds to withdraw");
        payable(owner).transfer(address(this).balance);
    }
}
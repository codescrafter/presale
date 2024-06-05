// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// This Solidity contract implements a presale for an ERC20 token.
// It allows the owner to set the price and timeline for the token sale and manage a
// whitelist of addresses permitted to purchase tokens. Participants can buy tokens with
// ETH during the sale period, while the owner can deposit tokens for sale,
// update the sale parameters, and withdraw the collected funds and unsold tokens.

contract Presale is Ownable, ReentrancyGuard {
    IERC20 public token; // token that is available for sale
    uint256 public price; // Number of tokens per 1 wei
    uint256 public startTime; // Start time of the token sale
    uint256 public endTime; // End time of the token sale
    uint256 public amountCollected; // Funds raised
    mapping(address => bool) public whitelist;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event SaleTimeUpdated(uint256 startTime, uint256 endTime);
    event PriceUpdated(uint256 newPrice);
    event AddressWhitelisted(address indexed account);
    event AddressWhitelistedMultiple(address[] accounts);
    event AddressRemovedFromWhitelist(address indexed account);

    modifier onlyWhileOpen() {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Token sale is not open"
        );
        _;
    }

    constructor(
        IERC20 _token,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime
    ) Ownable(msg.sender) {
        require(_startTime > block.timestamp, "Start time must be in future");
        require(_startTime < _endTime, "Start time must be before end time");
        require(_price > 0, "Price must be greater than 0");
        require(address(_token) != address(0)); // address must be valid

        token = _token;
        price = _price;
        startTime = _startTime;
        endTime = _endTime;
    }

    // Function to deposit ERC20 tokens into the contract by the owner
    function depositTokens(uint256 amount) external onlyOwner {
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Token deposit failed"
        );
    }

    // Function to purchase tokens with ETH
    function buyTokens() public payable onlyWhileOpen nonReentrant {
        require(msg.value > 0, "Amount must be greater than zero");
        require(whitelist[msg.sender], "Address not whitelisted");

        uint256 tokenAmount = msg.value * price;
        uint256 contractTokenBalance = token.balanceOf(address(this));

        require(
            contractTokenBalance >= tokenAmount,
            "Insufficient token balance in contract"
        );

        amountCollected += msg.value;
        require(
            token.transfer(msg.sender, tokenAmount),
            "Token transfer failed"
        );

        emit TokensPurchased(msg.sender, tokenAmount, msg.value);
    }

    // Function to withdraw ETH from the contract by the owner
    function withdrawFunds() external onlyOwner {
        uint256 collectedFunds = address(this).balance;
        // check if no funds are collected
        require(collectedFunds > 0, "No funds to withdraw");
        // withdraw funds
        (bool sent, ) = payable(msg.sender).call{value: collectedFunds}("");
        require(sent, "Failed to withdraw funds");
    }

    // Function to update the token sale price
    function updatePrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be greater than 0");
        price = newPrice;
        emit PriceUpdated(newPrice);
    }

    // Function to add an address to the whitelist
    function addToWhitelist(address account) external onlyOwner {
        whitelist[account] = true;
        emit AddressWhitelisted(account);
    }

    // Function to add list of addresses to whitelist
    function addManyToWhitelist(
        address[] calldata accounts
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = true;
        }
        emit AddressWhitelistedMultiple(accounts);
    }

    // Function to remove an address from the whitelist
    function removeFromWhitelist(address account) external onlyOwner {
        whitelist[account] = false;
        emit AddressRemovedFromWhitelist(account);
    }

    // Function to update the sale timeline
    function updateSaleTime(
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        require(_startTime > block.timestamp, "Start time must be in future");
        require(_startTime < _endTime, "Start time must be before end time");
        startTime = _startTime;
        endTime = _endTime;
        emit SaleTimeUpdated(_startTime, _endTime);
    }

    // Function to withdraw any remaining ERC20 tokens by the owner
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(
            token.balanceOf(address(this)) >= amount,
            "Insufficient token balance in contract"
        );
        require(token.transfer(msg.sender, amount), "Token transfer failed");
    }

    // Fallback function to prevent accidental ETH transfers
    receive() external payable {
        revert("ETH transfers not allowed");
    }

    fallback() external payable {
        revert("Function does not exist");
    }
}

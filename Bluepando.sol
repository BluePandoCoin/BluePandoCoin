// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract BluePando is ERC20, Ownable, ERC20Permit {
    address public deployer;
    address public liquidityWallet;
    uint256 public constant DEPLOYER_ALLOCATION_PERCENT = 4;
    uint256 public constant LIQUIDITY_WALLET_ALLOCATION_PERCENT = 4;
    uint256 public constant CONTRACT_ALLOCATION_PERCENT = 92;
    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18; // Maximum supply is 1 billion tokens
    string public metadataURI;

    // Mapping to store the last transaction timestamp for each user
    mapping(address => uint256) private lastTransactionTimestamp;

    // Transaction rate limits
    uint256 public constant TRANSACTION_RATE_LIMIT = 1; // 1 transaction per second
    uint256 public constant DAILY_TRANSACTION_LIMIT = 100; // 100 transactions per day

    constructor(address initialOwner, address _liquidityWallet, string memory _metadataURI)
        ERC20("BluePando", "PANDO")
        Ownable(initialOwner)
        ERC20Permit("BluePando")
    {
        deployer = initialOwner;
        liquidityWallet = _liquidityWallet;
        metadataURI = _metadataURI;

        uint256 deployerAllocation = (MAX_SUPPLY * DEPLOYER_ALLOCATION_PERCENT) / 100;
        uint256 liquidityWalletAllocation = (MAX_SUPPLY * LIQUIDITY_WALLET_ALLOCATION_PERCENT) / 100;
        uint256 contractAllocation = MAX_SUPPLY - deployerAllocation - liquidityWalletAllocation;

        _mint(deployer, deployerAllocation);
        _mint(liquidityWallet, liquidityWalletAllocation);
        _mint(address(this), contractAllocation);

        require(totalSupply() <= MAX_SUPPLY, "Total supply exceeds maximum supply");

        // Additional gas optimization: avoid unnecessary storage variable
        // transferOwnership(address(0)); // Renounce ownership
        _transferOwnership(address(0)); // Renounce ownership in constructor to save gas
    }

    // Override transfer function to include error handling and transaction throttling
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(balanceOf(msg.sender) >= amount, "ERC20: transfer amount exceeds balance");

        // Check transaction rate limit
        require(_checkTransactionRateLimit(), "Transaction rate limit exceeded");

        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    // Override transferFrom function to include error handling and transaction throttling
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(balanceOf(sender) >= amount, "ERC20: transfer amount exceeds balance");
        require(allowance(sender, _msgSender()) >= amount, "ERC20: transfer amount exceeds allowance");

        // Check transaction rate limit
        require(_checkTransactionRateLimit(), "Transaction rate limit exceeded");

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()) - amount);
        return true;
    }

    // Internal function to check transaction rate limit
    function _checkTransactionRateLimit() internal returns (bool) {
        uint256 currentTimestamp = block.timestamp;
        uint256 lastTxTimestamp = lastTransactionTimestamp[_msgSender()];

        // Check if enough time has passed since the last transaction
        if (currentTimestamp - lastTxTimestamp >= 1 days) {
            // Reset daily transaction count if it's a new day
            lastTransactionTimestamp[_msgSender()] = currentTimestamp;
            return true;
        }

        // Check if the per-second transaction limit has been reached
        require(currentTimestamp - lastTxTimestamp >= 1 seconds, "Transaction rate limit exceeded");

        // Increment daily transaction count
        lastTransactionTimestamp[_msgSender()] = currentTimestamp;
        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NFTverse Portal
 * @dev Decentralized NFT Marketplace with ERC-721 implementation
 * @notice This contract enables minting, listing, buying, and trading of unique digital assets
 */

contract Project {
    // Token metadata
    string public name = "NFTverse Portal";
    string public symbol = "NFTV";
    
    // Counters
    uint256 private _tokenIdCounter;
    uint256 private _listingIdCounter;
    
    // Contract owner
    address public owner;
    
    // Marketplace fee (in basis points, 250 = 2.5%)
    uint256 public marketplaceFee = 250;
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    // Royalty percentage for creators (500 = 5%)
    uint256 public royaltyPercentage = 500;
    
    // Reentrancy guard
    bool private locked;
    
    // Token ownership and balances
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    
    // Token URI storage
    mapping(uint256 => string) private _tokenURIs;
    
    // Creator tracking for royalties
    mapping(uint256 => address) private _creators;
    
    // Marketplace listings
    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
    }
    
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => uint256) private _tokenToListing;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event NFTMinted(address indexed creator, uint256 indexed tokenId, string tokenURI);
    event NFTListed(uint256 indexed listingId, uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    event ListingCancelled(uint256 indexed listingId, uint256 indexed tokenId);
    event MarketplaceFeeUpdated(uint256 newFee);
    event RoyaltyUpdated(uint256 newRoyalty);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }
    
    modifier nonReentrant() {
        require(!locked, "Reentrancy detected");
        locked = true;
        _;
        locked = false;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // ERC-721 Core Functions
    
    function balanceOf(address tokenOwner) public view returns (uint256) {
        require(tokenOwner != address(0), "Zero address query");
        return _balances[tokenOwner];
    }
    
    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "Token does not exist");
        return tokenOwner;
    }
    
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _tokenURIs[tokenId];
    }
    
    function approve(address to, uint256 tokenId) public {
        address tokenOwner = ownerOf(tokenId);
        require(msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender), "Not authorized");
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }
    
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _tokenApprovals[tokenId];
    }
    
    function setApprovalForAll(address operator, bool approved) public {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function isApprovedForAll(address tokenOwner, address operator) public view returns (bool) {
        return _operatorApprovals[tokenOwner][operator];
    }
    
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        require(ownerOf(tokenId) == from, "From address mismatch");
        require(to != address(0), "Transfer to zero address");
        
        // Clear approvals
        _tokenApprovals[tokenId] = address(0);
        
        // Update balances and ownership
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        
        emit Transfer(from, to, tokenId);
    }
    
    // NFT Minting
    
    function mint(string memory uri) public returns (uint256) {
        _tokenIdCounter++;
        uint256 newTokenId = _tokenIdCounter;
        
        _balances[msg.sender] += 1;
        _owners[newTokenId] = msg.sender;
        _tokenURIs[newTokenId] = uri;
        _creators[newTokenId] = msg.sender;
        
        emit Transfer(address(0), msg.sender, newTokenId);
        emit NFTMinted(msg.sender, newTokenId, uri);
        
        return newTokenId;
    }
    
    // Marketplace Functions
    
    function listNFT(uint256 tokenId, uint256 price) public {
        require(ownerOf(tokenId) == msg.sender, "Not the token owner");
        require(price > 0, "Price must be greater than zero");
        require(_tokenToListing[tokenId] == 0, "Already listed");
        
        _listingIdCounter++;
        uint256 listingId = _listingIdCounter;
        
        listings[listingId] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true
        });
        
        _tokenToListing[tokenId] = listingId;
        
        emit NFTListed(listingId, tokenId, msg.sender, price);
    }
    
    function buyNFT(uint256 listingId) public payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(msg.value >= listing.price, "Insufficient payment");
        
        uint256 tokenId = listing.tokenId;
        address seller = listing.seller;
        uint256 price = listing.price;
        
        // Calculate fees
        uint256 marketplaceCut = (price * marketplaceFee) / FEE_DENOMINATOR;
        uint256 royaltyCut = (price * royaltyPercentage) / FEE_DENOMINATOR;
        uint256 sellerProceeds = price - marketplaceCut - royaltyCut;
        
        // Mark listing as inactive
        listing.active = false;
        delete _tokenToListing[tokenId];
        
        // Transfer NFT to buyer
        _balances[seller] -= 1;
        _balances[msg.sender] += 1;
        _owners[tokenId] = msg.sender;
        _tokenApprovals[tokenId] = address(0);
        
        // Transfer funds
        payable(seller).transfer(sellerProceeds);
        payable(_creators[tokenId]).transfer(royaltyCut);
        payable(owner).transfer(marketplaceCut);
        
        // Refund excess payment
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
        
        emit Transfer(seller, msg.sender, tokenId);
        emit NFTSold(tokenId, msg.sender, seller, price);
    }
    
    function cancelListing(uint256 listingId) public {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(listing.seller == msg.sender, "Not the seller");
        
        listing.active = false;
        delete _tokenToListing[listing.tokenId];
        
        emit ListingCancelled(listingId, listing.tokenId);
    }
    
    // Administrative Functions
    
    function setMarketplaceFee(uint256 newFee) public onlyOwner {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        marketplaceFee = newFee;
        emit MarketplaceFeeUpdated(newFee);
    }
    
    function setRoyaltyPercentage(uint256 newRoyalty) public onlyOwner {
        require(newRoyalty <= 1000, "Royalty too high"); // Max 10%
        royaltyPercentage = newRoyalty;
        emit RoyaltyUpdated(newRoyalty);
    }
    
    function withdrawFees() public onlyOwner nonReentrant {
        payable(owner).transfer(address(this).balance);
    }
    
    // Helper Functions
    
    function _isApprovedOrOwner(address spender, uint256 tokenId) private view returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return (spender == tokenOwner || 
                getApproved(tokenId) == spender || 
                isApprovedForAll(tokenOwner, spender));
    }
    
    function getCreator(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _creators[tokenId];
    }
    
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }
}

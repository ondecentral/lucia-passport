// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PassportNFT is ERC721, ERC721Enumerable, Ownable {
    mapping(uint256 => string) private _tokenURIs;
    uint256 private _tokenIdCounter;
    address public rewardSystem;

    constructor() ERC721("PassportNFT", "PPTNFT") Ownable(msg.sender) {
        _tokenIdCounter = 1;
    }

    // Required overrides for ERC721Enumerable
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Function to mint a new Passport NFT
    function mintPassport(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;
        _safeMint(to, tokenId);
        _tokenURIs[tokenId] = uri;
    }

    // Function to get tokenURI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    // Function to update metadata (tokenURI) of a Passport NFT
    function updateTokenURI(uint256 tokenId, string memory newUri) public onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token ID does not exist");
        _tokenURIs[tokenId] = newUri;
    }

    // Function to burn a Passport NFT
    function burnPassport(uint256 tokenId) public onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token ID does not exist");
        _burn(tokenId);
        delete _tokenURIs[tokenId];
    }

    function setRewardSystem(address _rewardSystem) external onlyOwner {
        rewardSystem = _rewardSystem;
    }
}
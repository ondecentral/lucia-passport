// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PassportNFT is ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter;
    mapping(uint256 => bool) private _mintedTokens; // To track minted tokens

    constructor() ERC721("PassportNFT", "PPTNFT") Ownable(msg.sender){
        _tokenIdCounter = 1;
    }

    // Function to mint a new Passport NFT
    function mintPassport(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter += 1;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _mintedTokens[tokenId] = true; // Mark the tokenId as minted
    }

    // Custom exists function to replace _exists
    function _tokenExists(uint256 tokenId) internal view returns (bool) {
        return _mintedTokens[tokenId];
    }

    // Function to update metadata (tokenURI) of a Passport NFT
    function updateTokenURI(uint256 tokenId, string memory newUri) public onlyOwner {
        require(_tokenExists(tokenId), "Token ID does not exist");
        _setTokenURI(tokenId, newUri);
    }

    // Function to burn a Passport NFT
    function burnPassport(uint256 tokenId) public onlyOwner {
        require(_tokenExists(tokenId), "Token ID does not exist");
        _burn(tokenId);
        delete _mintedTokens[tokenId]; // Clear the tokenId from the minted list
    }
}
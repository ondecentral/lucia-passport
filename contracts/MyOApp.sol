// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract RewardSystem is Ownable, OApp {
    IERC721Enumerable public passportNFT; // The NFT contract for passports
    mapping(uint256 => uint256) public passportPoints; // Points associated with each passport
    mapping(address => uint256) public localPoints; // Local points for the current network
    uint16[] public authorizedChainIds; // Authorized chains for syncing points

    enum ActionType { Staking, Vesting, Farming, Swapping }
    mapping(ActionType => uint256) public actionPoints; // Points assigned to each action type

    event PointsAdded(uint256 indexed passportId, uint256 points, ActionType actionType);
    event SyncPoints(uint256 indexed passportId, uint256 points);
    
    constructor(address _endpoint, address _delegate, IERC721Enumerable _passportNFT) 
        OApp(_endpoint, _delegate) 
        Ownable(msg.sender) 
    {
        passportNFT = _passportNFT; // Initialize the passport NFT contract

        // Initialize action points
        actionPoints[ActionType.Staking] = 5;
        actionPoints[ActionType.Vesting] = 10;
        actionPoints[ActionType.Farming] = 15;
        actionPoints[ActionType.Swapping] = 20;

        // Set the authorized chains based on your LayerZero config
        authorizedChainIds.push(uint16(1)); // Example Chain ID for Sepolia
        authorizedChainIds.push(uint16(2)); // Example Chain ID for Amoy
    }

    // Function for users to perform an action and earn points
    function performAction(ActionType _actionType) external payable {
        require(passportNFT.balanceOf(msg.sender) > 0, "Not a passport holder");
        uint256 passportId = passportNFT.tokenOfOwnerByIndex(msg.sender, 0); // Get user's passport token ID
        uint256 points = actionPoints[_actionType];
        passportPoints[passportId] += points; // Update passport points
        localPoints[msg.sender] += points; // Update local points for the current network

        emit PointsAdded(passportId, points, _actionType);
        syncPointsAcrossChains(passportId, passportPoints[passportId]); // Sync points across authorized chains
    }

    // Replace estimateTotalFees with quoteFee from OApp
    function quoteFee(uint16 _dstEid, uint256 _passportId, uint256 _points) public view returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(_passportId, _points);
        return _quote(_dstEid, payload, "", false);
    }

    // Modify syncPointsAcrossChains to use proper fee handling
    function syncPointsAcrossChains(uint256 _passportId, uint256 _points) internal {
        bytes memory payload = abi.encode(_passportId, _points);
        
        uint256 totalFee = 0;
        // First calculate total fees needed
        for (uint i = 0; i < authorizedChainIds.length; i++) {
            MessagingFee memory fee = _quote(authorizedChainIds[i], payload, "", false);
            totalFee += fee.nativeFee;
        }
        
        require(msg.value >= totalFee, "Insufficient value for cross-chain messages");

        // Send messages to all chains
        for (uint i = 0; i < authorizedChainIds.length; i++) {
            uint16 dstEid = authorizedChainIds[i];
            MessagingFee memory fee = _quote(dstEid, payload, "", false);
            _lzSend(dstEid, payload, "", fee, payable(msg.sender));
        }

        // Refund excess fees
        uint256 excess = msg.value - totalFee;
        if (excess > 0) {
            (bool success, ) = msg.sender.call{value: excess}("");
            require(success, "Failed to refund excess value");
        }

        emit SyncPoints(_passportId, _points);
    }

    // Internal function to handle incoming messages from another chain
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (uint256 passportId, uint256 points) = abi.decode(payload, (uint256, uint256));
        passportPoints[passportId] += points; // Update points upon receipt
    }

    // Function to check total points for a specific passport ID
    function checkTotalPoints(uint256 _passportId) external view returns (uint256) {
        require(passportNFT.ownerOf(_passportId) == msg.sender, "Not a passport holder");
        return passportPoints[_passportId] + localPoints[msg.sender];
    }

    // Function to check passport ID associated with the caller's address across networks
    function checkPassportAcrossNetworks() external view returns (uint256) {
        for (uint i = 0; i < authorizedChainIds.length; i++) {
            if (passportNFT.balanceOf(msg.sender) > 0) {
                return passportNFT.tokenOfOwnerByIndex(msg.sender, 0); // Return passport ID
            }
        }
        return 0; // No passport found
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import { RewardSystem } from "../../contracts/MyOApp.sol";
import { PassportNFT } from "../../contracts/PassportNFT.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MockPassportNFT is ERC721Enumerable {
    constructor() ERC721("PassportNFT", "PNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract RewardSystemTest is Test {
    RewardSystem rewardSystem;
    MockPassportNFT passportNFT;
    address user = address(0x123);
    address nonHolder = address(0x456);
    struct Origin {
        uint16 chainId;
        address addr;
    }
    function setUp() public {
        // Mock PassportNFT and RewardSystem setup
        passportNFT = new MockPassportNFT();
        passportNFT.mint(user, 1);
        
        rewardSystem = new RewardSystem(
            address(0), // Mock LayerZero endpoint
            address(0), // Mock LayerZero delegate
            passportNFT
        );
    }

    // Test case 1: Check initial setup and configuration
    function testInitialSetup() public {
        assertEq(rewardSystem.passportNFT(), address(passportNFT), "Incorrect passportNFT address");
        assertEq(rewardSystem.actionPoints(RewardSystem.ActionType.Staking), 5, "Incorrect Staking points");
        assertEq(rewardSystem.actionPoints(RewardSystem.ActionType.Vesting), 10, "Incorrect Vesting points");
        assertEq(rewardSystem.authorizedChainIds(0), 1, "Incorrect chain ID");
    }

    // Test case 2: Verify points accumulation per action
    function testPerformAction_AccumulatesPoints() public {
        vm.prank(user);
        rewardSystem.performAction(RewardSystem.ActionType.Staking);

        uint256 passportId = passportNFT.tokenOfOwnerByIndex(user, 0);
        assertEq(rewardSystem.passportPoints(passportId), 5, "Incorrect passport points for Staking");
        assertEq(rewardSystem.localPoints(user), 5, "Incorrect local points for Staking");

        vm.prank(user);
        rewardSystem.performAction(RewardSystem.ActionType.Vesting);

        assertEq(rewardSystem.passportPoints(passportId), 15, "Incorrect passport points after Vesting");
        assertEq(rewardSystem.localPoints(user), 15, "Incorrect local points after Vesting");
    }

    // Test case 3: Verify syncing of points across chains
    function testSyncPointsAcrossChains() public {
        vm.deal(user, 1 ether); // Provide funds for cross-chain fee
        vm.prank(user);
        rewardSystem.performAction(RewardSystem.ActionType.Farming);

        uint256 passportId = passportNFT.tokenOfOwnerByIndex(user, 0);
        uint256 points = rewardSystem.passportPoints(passportId);

        vm.expectEmit(true, true, false, true);
        emit rewardSystem.SyncPoints(passportId, points);

        // Check cross-chain syncing
        vm.prank(user);
        rewardSystem.syncPointsAcrossChains(passportId, points);
    }

    // Test case 4: Check total points calculation
    function testCheckTotalPoints() public {
        vm.prank(user);
        rewardSystem.performAction(RewardSystem.ActionType.Swapping);

        uint256 passportId = passportNFT.tokenOfOwnerByIndex(user, 0);
        uint256 totalPoints = rewardSystem.checkTotalPoints(passportId);

        assertEq(totalPoints, 20, "Incorrect total points for Swapping action");
    }

    // Test case 5: Verify that non-passport holders cannot perform actions
    function testNonPassportHolderCannotPerformAction() public {
        vm.prank(nonHolder);
        vm.expectRevert("Not a passport holder");
        rewardSystem.performAction(RewardSystem.ActionType.Staking);
    }

    // Test case 6: Verify event logging for points addition
    function testEventPointsAdded() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, true);
        emit rewardSystem.PointsAdded(1, 5, RewardSystem.ActionType.Staking);

        rewardSystem.performAction(RewardSystem.ActionType.Staking);
    }

    // Test case 7: Check if points are correctly synced when received
    function testReceivePoints() public {
        vm.prank(user);
        rewardSystem.performAction(RewardSystem.ActionType.Farming);

        uint256 passportId = passportNFT.tokenOfOwnerByIndex(user, 0);
        uint256 points = rewardSystem.passportPoints(passportId);
        
        bytes memory payload = abi.encode(passportId, points);
        
        // Simulate receiving points
        rewardSystem._lzReceive(Origin({ chainId: 1, addr: user }), 0, payload, address(0), "");
        assertEq(rewardSystem.passportPoints(passportId), points * 2, "Points not correctly updated after receive");
    }

    // Test case 8: Verify burning a passport and that points are not retained
    function testBurnPassport() public {
        vm.prank(user);
        passportNFT.burn(1);

        vm.prank(user);
        vm.expectRevert("Not a passport holder");
        rewardSystem.performAction(RewardSystem.ActionType.Staking);
    }

    // Test case 9: Ensure actions cannot exceed maximum allowable points (if applicable)
    function testActionPointsLimit() public {
        vm.prank(user);
        rewardSystem.performAction(RewardSystem.ActionType.Staking);
        rewardSystem.performAction(RewardSystem.ActionType.Staking);
        rewardSystem.performAction(RewardSystem.ActionType.Staking);

        uint256 passportId = passportNFT.tokenOfOwnerByIndex(user, 0);
        assertEq(rewardSystem.passportPoints(passportId), 15, "Incorrect passport points exceeding limit");
    }
}

const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('PassportNFT and RewardSystem Tests', function () {
    const eidA = 1; // Sepolia Chain ID
    const eidB = 2; // Amoy Chain ID
    let RewardSystem, PassportNFT, EndpointV2Mock;
    let owner, user1, user2, user3, endpointOwner;
    let rewardSystemA, rewardSystemB, mockEndpointV2A, mockEndpointV2B, passportNFT;

    before(async function () {
        [owner, user1, user2, user3, endpointOwner] = await ethers.getSigners();
        RewardSystem = await ethers.getContractFactory('RewardSystem');
        PassportNFT = await ethers.getContractFactory('PassportNFT');
        EndpointV2Mock = await ethers.getContractFactory('EndpointV2Mock');
    });

    beforeEach(async function () {
        // Deploy PassportNFT with explicit owner
        const PassportNFT = await ethers.getContractFactory("PassportNFT");
        passportNFT = await PassportNFT.connect(owner).deploy();
        await passportNFT.deployed();

        // Deploy mock endpoints
        const MockEndpointV2 = await ethers.getContractFactory("EndpointV2Mock");
        mockEndpointV2A = await MockEndpointV2.connect(owner).deploy(eidA);
        mockEndpointV2B = await MockEndpointV2.connect(owner).deploy(eidB);

        // Deploy RewardSystem with explicit owner
        const RewardSystem = await ethers.getContractFactory("RewardSystem");
        rewardSystemA = await RewardSystem.connect(owner).deploy(
            mockEndpointV2A.address,
            owner.address,
            passportNFT.address
        );
        rewardSystemB = await RewardSystem.connect(owner).deploy(
            mockEndpointV2B.address,
            owner.address,
            passportNFT.address
        );

        // Verify ownership
        expect(await passportNFT.owner()).to.equal(owner.address);
        expect(await rewardSystemA.owner()).to.equal(owner.address);
        expect(await rewardSystemB.owner()).to.equal(owner.address);

        // Setup endpoints
        await mockEndpointV2A.setDestLzEndpoint(rewardSystemB.address, mockEndpointV2B.address);
        await mockEndpointV2B.setDestLzEndpoint(rewardSystemA.address, mockEndpointV2A.address);
        await mockEndpointV2A.setDefaultFee(ethers.utils.parseEther("0.01"));
        await mockEndpointV2B.setDefaultFee(ethers.utils.parseEther("0.01"));

        // Setup peer relationships
        const peerA = ethers.utils.hexZeroPad(rewardSystemA.address, 32);
        const peerB = ethers.utils.hexZeroPad(rewardSystemB.address, 32);
        await rewardSystemA.setPeer(eidA, peerA);
        await rewardSystemA.setPeer(eidB, peerB);
        await rewardSystemB.setPeer(eidA, peerA);
        await rewardSystemB.setPeer(eidB, peerB);

        // Change these lines
        await passportNFT.connect(owner).setRewardSystem(rewardSystemA.address);
        await passportNFT.connect(owner).setRewardSystem(rewardSystemB.address);
    });

    describe('PassportNFT Tests', function () {
        describe('Basic Functionality', function () {
            it('should initialize with correct name and symbol', async function () {
                expect(await passportNFT.name()).to.equal("PassportNFT");
                expect(await passportNFT.symbol()).to.equal("PPTNFT");
            });

            it('should start with token counter at 1', async function () {
                await passportNFT.mintPassport(user1.address, "ipfs://1");
                expect(await passportNFT.ownerOf(1)).to.equal(user1.address);
            });
        });

        describe('Minting', function () {
            it('should only allow owner to mint', async function () {
                await expect(
                    passportNFT.connect(user2).mintPassport(user2.address, "ipfs://test")
                ).to.be.revertedWithCustomError(passportNFT, "OwnableUnauthorizedAccount")
                .withArgs(user2.address);
            });

            it('should mint with correct URI', async function () {
                await passportNFT.connect(owner).mintPassport(user1.address, "ipfs://test");
                expect(await passportNFT.tokenURI(1)).to.equal("ipfs://test");
            });

            it('should increment token IDs correctly', async function () {
                await passportNFT.connect(owner).mintPassport(user1.address, "ipfs://1");
                await passportNFT.connect(owner).mintPassport(user2.address, "ipfs://2");
                expect(await passportNFT.ownerOf(1)).to.equal(user1.address);
                expect(await passportNFT.ownerOf(2)).to.equal(user2.address);
            });
        });

        describe('URI Management', function () {
            beforeEach(async function () {
                // Use owner to mint for setup
                await passportNFT.connect(owner).mintPassport(user1.address, "ipfs://original");
            });

            it('should update URI correctly', async function () {
                // Owner should be able to update URI
                await passportNFT.connect(owner).updateTokenURI(1, "ipfs://updated");
                expect(await passportNFT.tokenURI(1)).to.equal("ipfs://updated");
            });

            it('should only allow owner to update URI', async function () {
                // Non-owner (user1) should not be able to update URI
                await expect(
                    passportNFT.connect(user1).updateTokenURI(1, "ipfs://hack")
                ).to.be.revertedWithCustomError(passportNFT, "OwnableUnauthorizedAccount")
                .withArgs(user1.address);
            });

            it('should revert URI update for non-existent token', async function () {
                // Even owner cannot update non-existent token
                await expect(
                    passportNFT.connect(owner).updateTokenURI(999, "ipfs://fail")
                ).to.be.revertedWith("Token ID does not exist");
            });
        });

        describe('Burning', function () {
            beforeEach(async function () {
                // Use owner to mint for setup
                await passportNFT.connect(owner).mintPassport(user1.address, "ipfs://burn");
            });

            it('should burn passport correctly', async function () {
                // Owner should be able to burn
                await passportNFT.connect(owner).burnPassport(1);
                await expect(passportNFT.ownerOf(1)).to.be.reverted;
            });

            it('should only allow owner to burn', async function () {
                // Non-owner (user1) should not be able to burn
                await expect(
                    passportNFT.connect(user1).burnPassport(1)
                ).to.be.revertedWithCustomError(passportNFT, "OwnableUnauthorizedAccount")
                .withArgs(user1.address);
            });

            it('should revert burning non-existent token', async function () {
                // Even owner cannot burn non-existent token
                await expect(
                    passportNFT.connect(owner).burnPassport(999)
                ).to.be.revertedWith("Token ID does not exist");
            });
        });

        describe('Enumerable Features', function () {
            beforeEach(async function () {
                // Use owner to mint for setup
                await passportNFT.connect(owner).mintPassport(user1.address, "ipfs://1");
                await passportNFT.connect(owner).mintPassport(user1.address, "ipfs://2");
            });

            it('should track total supply correctly', async function () {
                expect(await passportNFT.totalSupply()).to.equal(2);
            });

            it('should enumerate tokens correctly', async function () {
                expect(await passportNFT.tokenOfOwnerByIndex(user1.address, 0)).to.equal(1);
                expect(await passportNFT.tokenOfOwnerByIndex(user1.address, 1)).to.equal(2);
            });
        });
    });

    describe('RewardSystem Tests', function () {
        describe('Initialization', function () {
            it('should initialize with correct action points', async function () {
                expect(await rewardSystemA.actionPoints(0)).to.equal(5);  // Staking
                expect(await rewardSystemA.actionPoints(1)).to.equal(10); // Vesting
                expect(await rewardSystemA.actionPoints(2)).to.equal(15); // Farming
                expect(await rewardSystemA.actionPoints(3)).to.equal(20); // Swapping
            });

            it('should initialize with correct authorized chains', async function () {
                expect(await rewardSystemA.authorizedChainIds(0)).to.equal(1);
                expect(await rewardSystemA.authorizedChainIds(1)).to.equal(2);
            });
        });

        describe('Action Performance', function () {
            beforeEach(async function () {
                // Mint passport for testing
                await passportNFT.connect(owner).mintPassport(user1.address, "ipfs://test");
                
                // Set reasonable default fees for testing
                await mockEndpointV2A.setDefaultFee(ethers.utils.parseEther("0.01"));
                await mockEndpointV2B.setDefaultFee(ethers.utils.parseEther("0.01"));
                
                // Set up peer relationships
                const peerA = ethers.utils.hexZeroPad(rewardSystemA.address, 32);
                const peerB = ethers.utils.hexZeroPad(rewardSystemB.address, 32);
                await rewardSystemA.setPeer(eidB, peerB);
                await rewardSystemB.setPeer(eidA, peerA);

                // Grant necessary permissions
                await passportNFT.connect(owner).setRewardSystem(rewardSystemA.address);
                await passportNFT.connect(owner).setRewardSystem(rewardSystemB.address);
            });

            it('should perform all action types correctly', async function () {
                const fee = ethers.utils.parseEther("0.05");
                
                const actions = [
                    { type: 0, points: 5 },  // Staking
                    { type: 1, points: 10 }, // Vesting
                    { type: 2, points: 15 }, // Farming
                    { type: 3, points: 20 }  // Swapping
                ];

                let expectedPoints = 0;
                for (const action of actions) {
                    await rewardSystemA.connect(user1).performAction(action.type, { value: fee });
                    expectedPoints += action.points;
                    
                    // Check points on chain A
                    const pointsA = await rewardSystemA.passportPoints(1);
                    expect(pointsA).to.equal(expectedPoints);
                    
                    // Check points on chain B (should be synced)
                    const pointsB = await rewardSystemB.passportPoints(1);
                    expect(pointsB).to.equal(expectedPoints);
                }
            });

            it('should revert with insufficient fee', async function () {
                const lowFee = ethers.utils.parseEther("0.001");
                await expect(
                    rewardSystemA.connect(user1).performAction(0, { value: lowFee })
                ).to.be.revertedWithCustomError(mockEndpointV2A, "InsufficientFee");
            });
        });

        describe('Cross-Chain Functionality', function () {
            beforeEach(async function () {
                await passportNFT.mintPassport(user1.address, "ipfs://test");
                await mockEndpointV2A.setDefaultFee(ethers.utils.parseEther("0.01"));
                await mockEndpointV2B.setDefaultFee(ethers.utils.parseEther("0.01"));
            });

            it('should sync points across chains', async function () {
                const fee = ethers.utils.parseEther("0.05");
                
                // Perform action on chain A
                await rewardSystemA.connect(user1).performAction(0, { value: fee });
                
                // Simulate the cross-chain message
                const payload = ethers.utils.defaultAbiCoder.encode(
                    ["uint256", "uint256"],
                    [1, 5] // tokenId, points
                );

                const origin = {
                    srcEid: eidA,
                    sender: ethers.utils.hexZeroPad(rewardSystemA.address, 32),
                    nonce: 1
                };

                // Manually receive message on chain B
                await rewardSystemB._lzReceive(
                    origin,
                    ethers.constants.HashZero,
                    payload,
                    endpointOwner.address,
                    "0x"
                );

                // Verify points on both chains
                const pointsA = await rewardSystemA.passportPoints(1);
                const pointsB = await rewardSystemB.passportPoints(1);
                expect(pointsA).to.equal(5);
                expect(pointsB).to.equal(5);
            });

            it('should quote fees correctly', async function () {
                const fee = await rewardSystemA.quoteFee(
                    eidB,
                    1, // tokenId
                    5  // points
                );
                expect(fee.nativeFee).to.equal(ethers.utils.parseEther("0.01"));
            });
        });

        describe('Point Checking', function () {
            beforeEach(async function () {
                await passportNFT.mintPassport(user1.address, "ipfs://test");
            });

            it('should track total points correctly', async function () {
                const fee = ethers.utils.parseEther("0.05");
                
                // Perform two actions
                await rewardSystemA.connect(user1).performAction(0, { value: fee }); // 5 points
                await rewardSystemA.connect(user1).performAction(1, { value: fee }); // 10 points

                // Wait for transactions to be mined
                await ethers.provider.getBlock('latest');

                const totalPoints = await rewardSystemA.checkTotalPoints(1);
                expect(totalPoints).to.be.at.least(15);
            });

            it('should check passport across networks', async function () {
                const passportId = await rewardSystemA.connect(user1).checkPassportAcrossNetworks();
                expect(passportId).to.equal(1);
            });

            it('should return 0 for non-passport holders', async function () {
                const passportId = await rewardSystemA.connect(user2).checkPassportAcrossNetworks();
                expect(passportId).to.equal(0);
            });
        });

        describe('Edge Cases', function () {
            it('should handle multiple passports per user', async function () {
                await passportNFT.mintPassport(user1.address, "ipfs://1");
                await passportNFT.mintPassport(user1.address, "ipfs://2");
                
                const fee = ethers.utils.parseEther("0.01");
                await rewardSystemA.connect(user1).performAction(0, { value: fee });
                
                // Should use first passport for points
                expect(await rewardSystemA.passportPoints(1)).to.equal(5);
                expect(await rewardSystemA.passportPoints(2)).to.equal(0);
            });

            it('should handle passport transfers correctly', async function () {
                await passportNFT.mintPassport(user1.address, "ipfs://test");
                const fee = ethers.utils.parseEther("0.01");
                await rewardSystemA.connect(user1).performAction(0, { value: fee });
                
                // Transfer passport
                await passportNFT.connect(user1).transferFrom(user1.address, user2.address, 1);
                
                // Original points should remain with passport
                expect(await rewardSystemA.passportPoints(1)).to.equal(5);
                
                // New owner should be able to earn points
                await rewardSystemA.connect(user2).performAction(0, { value: fee });
                expect(await rewardSystemA.passportPoints(1)).to.equal(10);
            });
        });
    });
});

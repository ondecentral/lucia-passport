import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, ContractFactory } from 'ethers'
import { deployments, ethers } from 'hardhat'

describe('RewardSystem Test', function () {
    const eidA = 1; // Mock Endpoint ID for chain A
    const eidB = 2; // Mock Endpoint ID for chain B

    let RewardSystem: ContractFactory;
    let EndpointV2Mock: ContractFactory;
    let PassportNFT: ContractFactory;
    let ownerA: SignerWithAddress;
    let ownerB: SignerWithAddress;
    let endpointOwner: SignerWithAddress;
    let rewardSystemA: Contract;
    let rewardSystemB: Contract;
    let mockEndpointV2A: Contract;
    let mockEndpointV2B: Contract;
    let passportNFT: Contract;

    before(async function () {
        RewardSystem = await ethers.getContractFactory('RewardSystem');
        PassportNFT = await ethers.getContractFactory('PassportNFT');

        const signers = await ethers.getSigners();
        ownerA = signers[0];
        ownerB = signers[1];
        endpointOwner = signers[2];

        // Deploy EndpointV2Mock from LayerZero
        const EndpointV2MockArtifact = await deployments.getArtifact('EndpointV2Mock');
        EndpointV2Mock = new ContractFactory(EndpointV2MockArtifact.abi, EndpointV2MockArtifact.bytecode, endpointOwner);
    });

    beforeEach(async function () {
        // Deploy mock LZ EndpointV2
        mockEndpointV2A = await EndpointV2Mock.deploy(eidA);
        mockEndpointV2B = await EndpointV2Mock.deploy(eidB);

        // Deploy the passport NFT contract
        passportNFT = await PassportNFT.deploy();

        // Deploy the RewardSystem contracts
        rewardSystemA = await RewardSystem.deploy(mockEndpointV2A.address, ownerA.address, passportNFT.address);
        rewardSystemB = await RewardSystem.deploy(mockEndpointV2B.address, ownerB.address, passportNFT.address);

        // Set destination endpoints
        await mockEndpointV2A.setDestLzEndpoint(rewardSystemB.address, mockEndpointV2B.address);
        await mockEndpointV2B.setDestLzEndpoint(rewardSystemA.address, mockEndpointV2A.address);
    });

    describe('Initialization', function () {
        it('should deploy RewardSystem with correct parameters', async function () {
            expect(await rewardSystemA.passportNFT()).to.equal(passportNFT.address);
            expect(await rewardSystemB.passportNFT()).to.equal(passportNFT.address);
        });
    });

    describe('Perform Action', function () {
        it('should allow passport holders to earn points', async function () {
            
            await passportNFT.mintPassport(ownerA.address, 1); // mintPassport NFT for ownerA
            await rewardSystemA.performAction(0); // Perform action
            const points = await rewardSystemA.passportPoints(1);
            expect(points).to.equal(5); // Assuming 5 points for action
        });

        it('should revert if non-passport holder tries to earn points', async function () {
            await expect(rewardSystemA.connect(ownerB).performAction(0)).to.be.rejectedWith("Not a passport holder");
        });

        it('should sync points across chains', async function () {
            await passportNFT.mintPassport(ownerA.address, 1); // mintPassport NFT for ownerA
            await rewardSystemA.performAction(0); // Perform action to earn points
            const points = await rewardSystemA.passportPoints(1);
            expect(points).to.equal(5); // Points earned
            
            // Simulate receiving the message on the second chain
            await rewardSystemB._lzReceive(
                { origin: eidA }, 
                0, 
                ethers.utils.defaultAbiCoder.encode(["uint256", "uint256"], [1, points]), 
                ownerB.address, 
                "0x"
            );

            const syncedPoints = await rewardSystemB.passportPoints(1);
            expect(syncedPoints).to.equal(5); // Points should be synced
        });
    });

    describe('Check Total Points', function () {
        it('should return correct total points for a passport holder', async function () {
            await passportNFT.mintPassport(ownerA.address, 1); // mintPassport NFT for ownerA
            await rewardSystemA.performAction(0); // Staking
            await rewardSystemA.performAction(1); // Vesting
            const totalPoints = await rewardSystemA.checkTotalPoints(1);
            expect(totalPoints).to.equal(15); // Assuming 5 + 10 points
        });

        it('should revert for non-passport holders', async function () {
            await expect(rewardSystemA.connect(ownerB).checkTotalPoints(1)).to.be.rejectedWith("Not a passport holder");
        });
    });
});

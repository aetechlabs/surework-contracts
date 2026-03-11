import { expect } from "chai";
import { ethers } from "hardhat";
import { SureWorkEscrow } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("SureWorkEscrow", function () {
  let escrow: SureWorkEscrow;
  let mockToken: any;
  let owner: SignerWithAddress;
  let client: SignerWithAddress;
  let freelancer: SignerWithAddress;
  let feeCollector: SignerWithAddress;

  const GIG_AMOUNT = ethers.parseUnits("100", 6); // 100 USDC (6 decimals)

  beforeEach(async function () {
    [owner, client, freelancer, feeCollector] = await ethers.getSigners();

    // Deploy mock ERC20 token (representing USDC)
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockToken = await MockERC20.deploy("Mock USDC", "USDC", 6);
    await mockToken.waitForDeployment();

    // Mint tokens to client
    await mockToken.mint(client.address, ethers.parseUnits("1000", 6));

    // Deploy escrow contract
    const SureWorkEscrow = await ethers.getContractFactory("SureWorkEscrow");
    escrow = await SureWorkEscrow.deploy(feeCollector.address) as any;
    await escrow.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the correct fee collector", async function () {
      expect(await escrow.feeCollector()).to.equal(feeCollector.address);
    });

    it("Should set default platform fee to 2.5%", async function () {
      expect(await escrow.platformFeePercent()).to.equal(250);
    });
  });

  describe("Gig Creation", function () {
    it("Should create a new gig", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 86400; // 24 hours from now
      
      await expect(
        escrow.connect(client).createGig(
          freelancer.address,
          await mockToken.getAddress(),
          GIG_AMOUNT,
          deadline,
          "ipfs://QmExample"
        )
      ).to.emit(escrow, "GigCreated");

      const gig = await escrow.getGig(1);
      expect(gig.client).to.equal(client.address);
      expect(gig.freelancer).to.equal(freelancer.address);
      expect(gig.amount).to.equal(GIG_AMOUNT);
    });

    it("Should fail if freelancer is zero address", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 86400;
      
      await expect(
        escrow.connect(client).createGig(
          ethers.ZeroAddress,
          await mockToken.getAddress(),
          GIG_AMOUNT,
          deadline,
          "ipfs://QmExample"
        )
      ).to.be.revertedWith("Invalid freelancer address");
    });

    it("Should fail if client tries to be freelancer", async function () {
      const deadline = Math.floor(Date.now() / 1000) + 86400;
      
      await expect(
        escrow.connect(client).createGig(
          client.address,
          await mockToken.getAddress(),
          GIG_AMOUNT,
          deadline,
          "ipfs://QmExample"
        )
      ).to.be.revertedWith("Client cannot be freelancer");
    });
  });

  describe("Gig Funding", function () {
    let gigId: number;

    beforeEach(async function () {
      const deadline = Math.floor(Date.now() / 1000) + 86400;
      await escrow.connect(client).createGig(
        freelancer.address,
        await mockToken.getAddress(),
        GIG_AMOUNT,
        deadline,
        "ipfs://QmExample"
      );
      gigId = 1;
    });

    it("Should fund a gig successfully", async function () {
      await mockToken.connect(client).approve(await escrow.getAddress(), GIG_AMOUNT);
      
      await expect(escrow.connect(client).fundGig(gigId))
        .to.emit(escrow, "GigFunded")
        .withArgs(gigId, GIG_AMOUNT);

      const gig = await escrow.getGig(gigId);
      expect(gig.status).to.equal(1); // Funded status
    });

    it("Should fail if non-client tries to fund", async function () {
      await mockToken.connect(client).approve(await escrow.getAddress(), GIG_AMOUNT);
      
      await expect(
        escrow.connect(freelancer).fundGig(gigId)
      ).to.be.revertedWith("Only client can fund");
    });
  });

  describe("Work Submission and Approval", function () {
    let gigId: number;

    beforeEach(async function () {
      const deadline = Math.floor(Date.now() / 1000) + 86400;
      await escrow.connect(client).createGig(
        freelancer.address,
        await mockToken.getAddress(),
        GIG_AMOUNT,
        deadline,
        "ipfs://QmExample"
      );
      gigId = 1;
      
      await mockToken.connect(client).approve(await escrow.getAddress(), GIG_AMOUNT);
      await escrow.connect(client).fundGig(gigId);
    });

    it("Should allow freelancer to submit work", async function () {
      await expect(escrow.connect(freelancer).submitWork(gigId))
        .to.emit(escrow, "WorkSubmitted")
        .withArgs(gigId, freelancer.address);

      const gig = await escrow.getGig(gigId);
      expect(gig.status).to.equal(2); // Submitted status
    });

    it("Should release payment on approval", async function () {
      await escrow.connect(freelancer).submitWork(gigId);
      
      const freelancerBalanceBefore = await mockToken.balanceOf(freelancer.address);
      const feeCollectorBalanceBefore = await mockToken.balanceOf(feeCollector.address);

      await expect(escrow.connect(client).approveWork(gigId))
        .to.emit(escrow, "GigCompleted");

      const platformFee = (GIG_AMOUNT * 250n) / 10000n; // 2.5%
      const freelancerPayment = GIG_AMOUNT - platformFee;

      expect(await mockToken.balanceOf(freelancer.address)).to.equal(
        freelancerBalanceBefore + freelancerPayment
      );
      expect(await mockToken.balanceOf(feeCollector.address)).to.equal(
        feeCollectorBalanceBefore + platformFee
      );
    });
  });

  describe("Dispute Resolution", function () {
    let gigId: number;

    beforeEach(async function () {
      const deadline = Math.floor(Date.now() / 1000) + 86400;
      await escrow.connect(client).createGig(
        freelancer.address,
        await mockToken.getAddress(),
        GIG_AMOUNT,
        deadline,
        "ipfs://QmExample"
      );
      gigId = 1;
      
      await mockToken.connect(client).approve(await escrow.getAddress(), GIG_AMOUNT);
      await escrow.connect(client).fundGig(gigId);
      await escrow.connect(freelancer).submitWork(gigId);
    });

    it("Should allow client to raise dispute", async function () {
      await expect(escrow.connect(client).raiseDispute(gigId))
        .to.emit(escrow, "GigDisputed")
        .withArgs(gigId, client.address);

      const gig = await escrow.getGig(gigId);
      expect(gig.status).to.equal(4); // Disputed status
    });

    it("Should allow arbiter to resolve dispute in favor of freelancer", async function () {
      await escrow.connect(client).raiseDispute(gigId);
      
      await expect(escrow.connect(owner).resolveDispute(gigId, freelancer.address))
        .to.emit(escrow, "DisputeResolved");

      const gig = await escrow.getGig(gigId);
      expect(gig.status).to.equal(3); // Completed status
    });

    it("Should refund client if dispute resolved in their favor", async function () {
      await escrow.connect(client).raiseDispute(gigId);
      
      const clientBalanceBefore = await mockToken.balanceOf(client.address);
      
      await escrow.connect(owner).resolveDispute(gigId, client.address);

      expect(await mockToken.balanceOf(client.address)).to.equal(
        clientBalanceBefore + GIG_AMOUNT
      );
    });
  });
});

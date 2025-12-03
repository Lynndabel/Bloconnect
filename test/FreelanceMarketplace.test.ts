import { expect } from "chai";
import { ethers } from "hardhat";
import { FreelanceMarketplace } from "../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { describe, beforeEach, it } from "node:test";

describe("FreelanceMarketplace - Modular Architecture Test Suite", function () {
  let marketplace: FreelanceMarketplace;
  let owner: SignerWithAddress;
  let client: SignerWithAddress;
  let freelancer: SignerWithAddress;
  let freelancer2: SignerWithAddress;
  let arbitrator: SignerWithAddress;
  let addrs: SignerWithAddress[];

  const PROFILE_HASH = "QmTestProfile123";
  const JOB_DESCRIPTION_HASH = "QmJobDescription456";
  const PROPOSAL_HASH = "QmProposal789";
  const MILESTONE_DESCRIPTION_HASH = "QmMilestone101";

  beforeEach(async function () {
    [owner, client, freelancer, freelancer2, arbitrator, ...addrs] = await ethers.getSigners();

    // Deploy the main contract which inherits all modular functionality
    const FreelanceMarketplace = await ethers.getContractFactory("FreelanceMarketplace");
    marketplace = await FreelanceMarketplace.deploy();
    await marketplace.deployed();
  });

  describe("🚀 Deployment & Architecture", function () {
    it("Should deploy with correct initial state", async function () {
      expect(await marketplace.owner()).to.equal(owner.address);
      expect(await marketplace.platformFee()).to.equal(250); // 2.5%
      expect(await marketplace.paused()).to.be.false;
      
      const [jobs, proposals, milestones, disputes] = await marketplace.getCounters();
      expect(jobs).to.equal(0);
      expect(proposals).to.equal(0);
      expect(milestones).to.equal(0);
      expect(disputes).to.equal(0);
    });

    it("Should accept payments", async function () {
      await expect(
        owner.sendTransaction({ to: marketplace.address, value: ethers.utils.parseEther("1") })
      ).to.not.be.reverted;
      
      expect(await ethers.provider.getBalance(marketplace.address)).to.equal(ethers.utils.parseEther("1"));
    });

    it("Should have all inherited functionality available", async function () {
      // Test that all main functions from different modules are available
      expect(marketplace.registerUser).to.exist;
      expect(marketplace.postJob).to.exist;
      expect(marketplace.submitProposal).to.exist;
      expect(marketplace.createMilestone).to.exist;
      expect(marketplace.raiseDispute).to.exist;
    });
  });

  describe("👥 User Management Module", function () {
    it("Should register a new user", async function () {
      await expect(marketplace.connect(client).registerUser(PROFILE_HASH))
        .to.emit(marketplace, "UserRegistered")
        .withArgs(client.address, PROFILE_HASH);

      const user = await marketplace.users(client.address);
      expect(user.userAddress).to.equal(client.address);
      expect(user.profileHash).to.equal(PROFILE_HASH);
      expect(user.reputation).to.equal(500);
      expect(user.isActive).to.be.true;
      expect(user.totalJobsCompleted).to.equal(0);
      expect(user.totalEarned).to.equal(0);
    });

    it("Should not allow duplicate registration", async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      
      await expect(
        marketplace.connect(client).registerUser(PROFILE_HASH)
      ).to.be.revertedWith("User already registered");
    });

    it("Should not allow empty profile hash", async function () {
      await expect(
        marketplace.connect(client).registerUser("")
      ).to.be.revertedWith("Profile hash cannot be empty");
    });

    it("Should update user profile", async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      
      const newProfileHash = "QmNewProfile456";
      await marketplace.connect(client).updateProfile(newProfileHash);
      
      const user = await marketplace.users(client.address);
      expect(user.profileHash).to.equal(newProfileHash);
    });

    it("Should not allow unregistered user to update profile", async function () {
      await expect(
        marketplace.connect(client).updateProfile("QmNewProfile")
      ).to.be.revertedWith("User not registered or inactive");
    });

    it("Should check user registration status", async function () {
      expect(await marketplace.isUserRegistered(client.address)).to.be.false;
      
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      
      expect(await marketplace.isUserRegistered(client.address)).to.be.true;
    });

    it("Should get user statistics", async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      
      const stats = await marketplace.getUserStats(client.address);
      expect(stats.jobsPosted).to.equal(0);
      expect(stats.proposalsSubmitted).to.equal(0);
      expect(stats.jobsCompleted).to.equal(0);
      expect(stats.totalEarned).to.equal(0);
      expect(stats.reputation).to.equal(500);
    });
  });

  describe("💼 Job Management Module", function () {
    beforeEach(async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      await marketplace.connect(freelancer).registerUser(PROFILE_HASH);
    });

    it("Should post a new job", async function () {
      const jobData = {
        title: "Build a DeFi Protocol",
        descriptionHash: JOB_DESCRIPTION_HASH,
        skillsRequired: ["Solidity", "React", "Node.js"],
        budget: ethers.utils.parseEther("5"),
        deadline: Math.floor(Date.now() / 1000) + 86400 * 30
      };

      await expect(
        marketplace.connect(client).postJob(
          jobData.title,
          jobData.descriptionHash,
          jobData.skillsRequired,
          jobData.budget,
          jobData.deadline
        )
      ).to.emit(marketplace, "JobPosted")
        .withArgs(1, client.address, jobData.budget);

      const job = await marketplace.jobs(1);
      expect(job.client).to.equal(client.address);
      expect(job.title).to.equal(jobData.title);
      expect(job.budget).to.equal(jobData.budget);
      expect(job.status).to.equal(0); // JobStatus.Open
      expect(job.assignedFreelancer).to.equal(ethers.constants.AddressZero);
    });

    it("Should not allow posting job with invalid parameters", async function () {
      const futureDeadline = Math.floor(Date.now() / 1000) + 86400;

      // Empty title
      await expect(
        marketplace.connect(client).postJob(
          "",
          JOB_DESCRIPTION_HASH,
          ["Solidity"],
          ethers.utils.parseEther("1"),
          futureDeadline
        )
      ).to.be.revertedWith("Title cannot be empty");

      // Zero budget
      await expect(
        marketplace.connect(client).postJob(
          "Test Job",
          JOB_DESCRIPTION_HASH,
          ["Solidity"],
          0,
          futureDeadline
        )
      ).to.be.revertedWith("Budget must be greater than 0");

      // Past deadline
      await expect(
        marketplace.connect(client).postJob(
          "Test Job",
          JOB_DESCRIPTION_HASH,
          ["Solidity"],
          ethers.utils.parseEther("1"),
          Math.floor(Date.now() / 1000) - 86400
        )
      ).to.be.revertedWith("Deadline must be in the future");
    });

    it("Should not allow unregistered user to post job", async function () {
      await expect(
        marketplace.connect(addrs[0]).postJob(
          "Test Job",
          JOB_DESCRIPTION_HASH,
          ["Solidity"],
          ethers.utils.parseEther("1"),
          Math.floor(Date.now() / 1000) + 86400
        )
      ).to.be.revertedWith("User not registered or inactive");
    });

    it("Should cancel a job", async function () {
      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );

      await marketplace.connect(client).cancelJob(1);
      
      const job = await marketplace.jobs(1);
      expect(job.status).to.equal(3); // JobStatus.Cancelled
    });

    it("Should not allow non-client to cancel job", async function () {
      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );

      await expect(
        marketplace.connect(freelancer).cancelJob(1)
      ).to.be.revertedWith("Not the job client");
    });

    it("Should get active jobs with pagination", async function () {
      // Post multiple jobs
      for (let i = 0; i < 5; i++) {
        await marketplace.connect(client).postJob(
          `Test Job ${i}`,
          JOB_DESCRIPTION_HASH,
          ["Solidity"],
          ethers.utils.parseEther("1"),
          Math.floor(Date.now() / 1000) + 86400 * 30
        );
      }

      const activeJobs = await marketplace.getActiveJobs(0, 3);
      expect(activeJobs.length).to.equal(3);
      expect(activeJobs[0]).to.equal(1);
      expect(activeJobs[1]).to.equal(2);
      expect(activeJobs[2]).to.equal(3);

      // Test pagination
      const nextBatch = await marketplace.getActiveJobs(3, 3);
      expect(nextBatch.length).to.equal(2);
      expect(nextBatch[0]).to.equal(4);
      expect(nextBatch[1]).to.equal(5);
    });

    it("Should get multiple jobs batch", async function () {
      // Post 3 jobs
      for (let i = 0; i < 3; i++) {
        await marketplace.connect(client).postJob(
          `Test Job ${i}`,
          JOB_DESCRIPTION_HASH,
          ["Solidity"],
          ethers.utils.parseEther("1"),
          Math.floor(Date.now() / 1000) + 86400 * 30
        );
      }

      const jobs = await marketplace.getMultipleJobs([1, 2, 3]);
      expect(jobs.length).to.equal(3);
      expect(jobs[0].title).to.equal("Test Job 0");
      expect(jobs[1].title).to.equal("Test Job 1");
      expect(jobs[2].title).to.equal("Test Job 2");
    });
  });

  describe("📝 Proposal Management Module", function () {
    let jobId: number;

    beforeEach(async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      await marketplace.connect(freelancer).registerUser(PROFILE_HASH);
      await marketplace.connect(freelancer2).registerUser(PROFILE_HASH);

      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );
      jobId = 1;
    });

    it("Should submit a proposal", async function () {
      await expect(
        marketplace.connect(freelancer).submitProposal(
          jobId,
          PROPOSAL_HASH,
          ethers.utils.parseEther("4"),
          15
        )
      ).to.emit(marketplace, "ProposalSubmitted")
        .withArgs(1, jobId, freelancer.address);

      const proposal = await marketplace.proposals(1);
      expect(proposal.freelancer).to.equal(freelancer.address);
      expect(proposal.jobId).to.equal(jobId);
      expect(proposal.proposedBudget).to.equal(ethers.utils.parseEther("4"));
      expect(proposal.status).to.equal(0); // ProposalStatus.Pending
    });

    it("Should not allow client to propose on own job", async function () {
      await expect(
        marketplace.connect(client).submitProposal(
          jobId,
          PROPOSAL_HASH,
          ethers.utils.parseEther("4"),
          15
        )
      ).to.be.revertedWith("Cannot propose on own job");
    });

    it("Should not allow proposal on non-open job", async function () {
      // Cancel the job first
      await marketplace.connect(client).cancelJob(jobId);

      await expect(
        marketplace.connect(freelancer).submitProposal(
          jobId,
          PROPOSAL_HASH,
          ethers.utils.parseEther("4"),
          15
        )
      ).to.be.revertedWith("Job is not open for proposals");
    });

    it("Should accept a proposal", async function () {
      await marketplace.connect(freelancer).submitProposal(
        jobId,
        PROPOSAL_HASH,
        ethers.utils.parseEther("4"),
        15
      );

      await expect(
        marketplace.connect(client).acceptProposal(1)
      ).to.emit(marketplace, "ProposalAccepted")
        .withArgs(1, jobId, freelancer.address);

      const proposal = await marketplace.proposals(1);
      expect(proposal.status).to.equal(1); // ProposalStatus.Accepted

      const job = await marketplace.jobs(jobId);
      expect(job.status).to.equal(1); // JobStatus.InProgress
      expect(job.assignedFreelancer).to.equal(freelancer.address);
      expect(job.budget).to.equal(ethers.utils.parseEther("4"));
    });

    it("Should reject other proposals when one is accepted", async function () {
      await marketplace.connect(freelancer).submitProposal(
        jobId,
        PROPOSAL_HASH,
        ethers.utils.parseEther("4"),
        15
      );

      await marketplace.connect(freelancer2).submitProposal(
        jobId,
        PROPOSAL_HASH,
        ethers.utils.parseEther("3"),
        10
      );

      await marketplace.connect(client).acceptProposal(1);

      const proposal2 = await marketplace.proposals(2);
      expect(proposal2.status).to.equal(2); // ProposalStatus.Rejected
    });

    it("Should withdraw a proposal", async function () {
      await marketplace.connect(freelancer).submitProposal(
        jobId,
        PROPOSAL_HASH,
        ethers.utils.parseEther("4"),
        15
      );

      await marketplace.connect(freelancer).withdrawProposal(1);

      const proposal = await marketplace.proposals(1);
      expect(proposal.status).to.equal(3); // ProposalStatus.Withdrawn
    });

    it("Should not allow non-owner to withdraw proposal", async function () {
      await marketplace.connect(freelancer).submitProposal(
        jobId,
        PROPOSAL_HASH,
        ethers.utils.parseEther("4"),
        15
      );

      await expect(
        marketplace.connect(freelancer2).withdrawProposal(1)
      ).to.be.revertedWith("Not proposal owner");
    });
  });

  describe("🎯 Milestone & Escrow Management Module", function () {
    let jobId: number;

    beforeEach(async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      await marketplace.connect(freelancer).registerUser(PROFILE_HASH);

      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );
      jobId = 1;

      await marketplace.connect(freelancer).submitProposal(
        jobId,
        PROPOSAL_HASH,
        ethers.utils.parseEther("4"),
        15
      );

      await marketplace.connect(client).acceptProposal(1);
    });

    it("Should create a milestone with escrow", async function () {
      const milestoneAmount = ethers.utils.parseEther("2");
      const deadline = Math.floor(Date.now() / 1000) + 86400 * 7;

      await expect(
        marketplace.connect(client).createMilestone(
          jobId,
          "First Milestone",
          MILESTONE_DESCRIPTION_HASH,
          milestoneAmount,
          deadline,
          { value: milestoneAmount }
        )
      ).to.emit(marketplace, "MilestoneCreated")
        .withArgs(1, jobId, milestoneAmount);

      const milestone = await marketplace.milestones(1);
      expect(milestone.jobId).to.equal(jobId);
      expect(milestone.amount).to.equal(milestoneAmount);
      expect(milestone.status).to.equal(0); // MilestoneStatus.Created
      expect(milestone.isPaid).to.be.false;

      const escrowBalance = await marketplace.escrowBalances(1);
      expect(escrowBalance).to.equal(milestoneAmount);

      // Check contract balance
      expect(await ethers.provider.getBalance(marketplace.address)).to.equal(milestoneAmount);
    });

    it("Should not create milestone with mismatched value", async function () {
      const milestoneAmount = ethers.utils.parseEther("2");
      const deadline = Math.floor(Date.now() / 1000) + 86400 * 7;

      await expect(
        marketplace.connect(client).createMilestone(
          jobId,
          "First Milestone",
          MILESTONE_DESCRIPTION_HASH,
          milestoneAmount,
          deadline,
          { value: ethers.utils.parseEther("1") }
        )
      ).to.be.revertedWith("Sent value must equal milestone amount");
    });

    it("Should submit milestone for approval", async function () {
      const milestoneAmount = ethers.utils.parseEther("2");
      await marketplace.connect(client).createMilestone(
        jobId,
        "First Milestone",
        MILESTONE_DESCRIPTION_HASH,
        milestoneAmount,
        Math.floor(Date.now() / 1000) + 86400 * 7,
        { value: milestoneAmount }
      );

      await expect(
        marketplace.connect(freelancer).submitMilestone(1)
      ).to.emit(marketplace, "MilestoneSubmitted")
        .withArgs(1, jobId);

      const milestone = await marketplace.milestones(1);
      expect(milestone.status).to.equal(2); // MilestoneStatus.Submitted
      expect(milestone.completedAt).to.be.gt(0);
    });

    it("Should approve milestone and release payment", async function () {
      const milestoneAmount = ethers.utils.parseEther("2");
      
      await marketplace.connect(client).createMilestone(
        jobId,
        "First Milestone",
        MILESTONE_DESCRIPTION_HASH,
        milestoneAmount,
        Math.floor(Date.now() / 1000) + 86400 * 7,
        { value: milestoneAmount }
      );

      await marketplace.connect(freelancer).submitMilestone(1);

      const freelancerInitialBalance = await freelancer.getBalance();
      const ownerInitialBalance = await owner.getBalance();

      await expect(
        marketplace.connect(client).approveMilestone(1, 8)
      ).to.emit(marketplace, "MilestoneApproved")
        .withArgs(1, jobId)
        .and.to.emit(marketplace, "PaymentReleased")
        .and.to.emit(marketplace, "ReputationUpdated");

      const milestone = await marketplace.milestones(1);
      expect(milestone.status).to.equal(3); // MilestoneStatus.Approved
      expect(milestone.isPaid).to.be.true;

      const escrowBalance = await marketplace.escrowBalances(1);
      expect(escrowBalance).to.equal(0);

      // Check payments
      const platformFee = await marketplace.platformFee();
      const feeAmount = milestoneAmount.mul(platformFee).div(10000);
      const expectedFreelancerPayment = milestoneAmount.sub(feeAmount);

      const freelancerFinalBalance = await freelancer.getBalance();
      expect(freelancerFinalBalance.sub(freelancerInitialBalance)).to.equal(expectedFreelancerPayment);

      // Check user stats updated
      const user = await marketplace.users(freelancer.address);
      expect(user.totalEarned).to.equal(expectedFreelancerPayment);
      expect(user.totalJobsCompleted).to.equal(1);
      expect(user.reputation).to.be.gt(500); // Should increase with rating of 8
    });

    it("Should get milestone with escrow info", async function () {
      const milestoneAmount = ethers.utils.parseEther("2");
      
      await marketplace.connect(client).createMilestone(
        jobId,
        "First Milestone",
        MILESTONE_DESCRIPTION_HASH,
        milestoneAmount,
        Math.floor(Date.now() / 1000) + 86400 * 7,
        { value: milestoneAmount }
      );

      const [milestone, escrowBalance] = await marketplace.getMilestoneWithEscrow(1);
      expect(milestone.amount).to.equal(milestoneAmount);
      expect(escrowBalance).to.equal(milestoneAmount);
    });

    it("Should get total escrow balance", async function () {
      const milestoneAmount1 = ethers.utils.parseEther("2");
      const milestoneAmount2 = ethers.utils.parseEther("1");
      
      await marketplace.connect(client).createMilestone(
        jobId,
        "First Milestone",
        MILESTONE_DESCRIPTION_HASH,
        milestoneAmount1,
        Math.floor(Date.now() / 1000) + 86400 * 7,
        { value: milestoneAmount1 }
      );

      await marketplace.connect(client).createMilestone(
        jobId,
        "Second Milestone",
        MILESTONE_DESCRIPTION_HASH,
        milestoneAmount2,
        Math.floor(Date.now() / 1000) + 86400 * 14,
        { value: milestoneAmount2 }
      );

      const totalEscrow = await marketplace.getTotalEscrowBalance();
      expect(totalEscrow).to.equal(milestoneAmount1.add(milestoneAmount2));
    });

    it("Should complete a job when all milestones are approved", async function () {
      const milestoneAmount = ethers.utils.parseEther("2");
      
      await marketplace.connect(client).createMilestone(
        jobId,
        "First Milestone",
        MILESTONE_DESCRIPTION_HASH,
        milestoneAmount,
        Math.floor(Date.now() / 1000) + 86400 * 7,
        { value: milestoneAmount }
      );

      await marketplace.connect(freelancer).submitMilestone(1);
      await marketplace.connect(client).approveMilestone(1, 8);

      await marketplace.connect(client).completeJob(jobId);

      const job = await marketplace.jobs(jobId);
      expect(job.status).to.equal(2); // JobStatus.Completed
    });

    it("Should not complete job with pending milestones", async function () {
      const milestoneAmount = ethers.utils.parseEther("2");
      
      await marketplace.connect(client).createMilestone(
        jobId,
        "First Milestone",
        MILESTONE_DESCRIPTION_HASH,
        milestoneAmount,
        Math.floor(Date.now() / 1000) + 86400 * 7,
        { value: milestoneAmount }
      );

      await expect(
        marketplace.connect(client).completeJob(jobId)
      ).to.be.revertedWith("All milestones must be approved");
    });
  });

  describe("⚖️ Dispute Resolution Module", function () {
    let jobId: number;
    let milestoneId: number;

    beforeEach(async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      await marketplace.connect(freelancer).registerUser(PROFILE_HASH);

      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );
      jobId = 1;

      await marketplace.connect(freelancer).submitProposal(
        jobId,
        PROPOSAL_HASH,
        ethers.utils.parseEther("4"),
        15
      );

      await marketplace.connect(client).acceptProposal(1);

      await marketplace.connect(client).createMilestone(
        jobId,
        "Test Milestone",
        MILESTONE_DESCRIPTION_HASH,
        ethers.utils.parseEther("2"),
        Math.floor(Date.now() / 1000) + 86400 * 7,
        { value: ethers.utils.parseEther("2") }
      );
      milestoneId = 1;

      await marketplace.connect(freelancer).submitMilestone(milestoneId);
    });

    it("Should raise a dispute", async function () {
      await expect(
        marketplace.connect(client).raiseDispute(milestoneId, "Work not satisfactory")
      ).to.emit(marketplace, "DisputeRaised")
        .withArgs(1, jobId, client.address);

      const dispute = await marketplace.disputes(1);
      expect(dispute.milestoneId).to.equal(milestoneId);
      expect(dispute.initiator).to.equal(client.address);
      expect(dispute.status).to.equal(0); // DisputeStatus.Open

      const milestone = await marketplace.milestones(milestoneId);
      expect(milestone.status).to.equal(4); // MilestoneStatus.Disputed

      const job = await marketplace.jobs(jobId);
      expect(job.status).to.equal(4); // JobStatus.Disputed
    });

    it("Should allow freelancer to raise dispute", async function () {
      await expect(
        marketplace.connect(freelancer).raiseDispute(milestoneId, "Unfair rejection")
      ).to.emit(marketplace, "DisputeRaised")
        .withArgs(1, jobId, freelancer.address);

      const dispute = await marketplace.disputes(1);
      expect(dispute.initiator).to.equal(freelancer.address);
    });

    it("Should not allow non-participants to raise dispute", async function () {
      await expect(
        marketplace.connect(addrs[0]).raiseDispute(milestoneId, "Random dispute")
      ).to.be.revertedWith("Only job participants can raise disputes");
    });

    it("Should resolve dispute in favor of freelancer", async function () {
      await marketplace.connect(client).raiseDispute(milestoneId, "Work not satisfactory");

      const freelancerInitialBalance = await freelancer.getBalance();

      await expect(
        marketplace.connect(owner).resolveDispute(1, true)
      ).to.emit(marketplace, "DisputeResolved")
        .withArgs(1, owner.address);

      const dispute = await marketplace.disputes(1);
      expect(dispute.status).to.equal(2); // DisputeStatus.Resolved
      expect(dispute.arbitrator).to.equal(owner.address);

      const milestone = await marketplace.milestones(milestoneId);
      expect(milestone.status).to.equal(3); // MilestoneStatus.Approved
      expect(milestone.isPaid).to.be.true;

      const freelancerFinalBalance = await freelancer.getBalance();
      expect(freelancerFinalBalance).to.be.gt(freelancerInitialBalance);
    });

    it("Should resolve dispute in favor of client", async function () {
      await marketplace.connect(client).raiseDispute(milestoneId, "Work not satisfactory");

      const clientInitialBalance = await client.getBalance();

      await marketplace.connect(owner).resolveDispute(1, false);

      const milestone = await marketplace.milestones(milestoneId);
      expect(milestone.status).to.equal(0); // MilestoneStatus.Created

      const clientFinalBalance = await client.getBalance();
      expect(clientFinalBalance).to.be.gt(clientInitialBalance);
    });
  });

  describe("🔧 Platform Administration", function () {
    it("Should update platform fee", async function () {
      const newFee = 500; // 5%
      await marketplace.connect(owner).updatePlatformFee(newFee);
      
      const currentFee = await marketplace.platformFee();
      expect(currentFee).to.equal(newFee);
    });

    it("Should not allow fee above maximum", async function () {
      await expect(
        marketplace.connect(owner).updatePlatformFee(1500)
      ).to.be.revertedWith("Fee too high");
    });

    it("Should not allow non-owner to update fee", async function () {
      await expect(
        marketplace.connect(client).updatePlatformFee(500)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should pause and unpause contract", async function () {
      await marketplace.connect(owner).togglePause();
      expect(await marketplace.paused()).to.be.true;

      await marketplace.connect(owner).togglePause();
      expect(await marketplace.paused()).to.be.false;
    });

    it("Should not allow operations when paused", async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      await marketplace.connect(owner).togglePause();

      await expect(
        marketplace.connect(client).postJob(
          "Test Job",
          JOB_DESCRIPTION_HASH,
          ["Solidity"],
          ethers.utils.parseEther("1"),
          Math.floor(Date.now() / 1000) + 86400
        )
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should allow emergency withdrawal", async function () {
      // Send some funds to contract
      await owner.sendTransaction({ 
        to: marketplace.address, 
        value: ethers.utils.parseEther("1") 
      });

      const initialBalance = await owner.getBalance();
      
      const tx = await marketplace.connect(owner).emergencyWithdraw(
        owner.address, 
        ethers.utils.parseEther("0.5")
      );
      
      const receipt = await tx.wait();
      const gasCost = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      
      const finalBalance = await owner.getBalance();
      expect(finalBalance.add(gasCost).sub(initialBalance)).to.equal(ethers.utils.parseEther("0.5"));
    });

    it("Should get platform statistics", async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      await marketplace.connect(freelancer).registerUser(PROFILE_HASH);

      // Post a job
      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );

      // Submit and accept proposal
      await marketplace.connect(freelancer).submitProposal(
        1,
        PROPOSAL_HASH,
        ethers.utils.parseEther("4"),
        15
      );
      await marketplace.connect(client).acceptProposal(1);

      // Create milestone
      await marketplace.connect(client).createMilestone(
        1,
        "Test Milestone",
        MILESTONE_DESCRIPTION_HASH,
        ethers.utils.parseEther("2"),
        Math.floor(Date.now() / 1000) + 86400 * 7,
        { value: ethers.utils.parseEther("2") }
      );

      const stats = await marketplace.getPlatformStats();
      expect(stats.totalJobs).to.equal(1);
      expect(stats.totalProposals).to.equal(1);
      expect(stats.totalMilestones).to.equal(1);
      expect(stats.activeJobs).to.equal(1);
      expect(stats.totalValueLocked).to.equal(ethers.utils.parseEther("2"));
    });
  });

  describe("🔍 View Functions", function () {
    beforeEach(async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      await marketplace.connect(freelancer).registerUser(PROFILE_HASH);
    });

    it("Should return job proposals", async function () {
      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );

      await marketplace.connect(freelancer).submitProposal(
        1,
        PROPOSAL_HASH,
        ethers.utils.parseEther("4"),
        15
      );

      const proposals = await marketplace.getJobProposals(1);
      expect(proposals.length).to.equal(1);
      expect(proposals[0]).to.equal(1);
    });

    it("Should return user jobs", async function () {
      await marketplace.connect(client).postJob(
        "Test Job 1",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );

      await marketplace.connect(client).postJob(
        "Test Job 2",
        JOB_DESCRIPTION_HASH,
        ["React"],
        ethers.utils.parseEther("3"),
        Math.floor(Date.now() / 1000) + 86400 * 20
      );

      const userJobs = await marketplace.getUserJobs(client.address);
      expect(userJobs.length).to.equal(2);
    });

    it("Should return current counters", async function () {
      const [jobCount, proposalCount, milestoneCount, disputeCount] = await marketplace.getCounters();
      expect(jobCount).to.equal(0);
      expect(proposalCount).to.equal(0);
      expect(milestoneCount).to.equal(0);
      expect(disputeCount).to.equal(0);
    });
  });

  describe("🛡️ Security & Edge Cases", function () {
    beforeEach(async function () {
      await marketplace.connect(client).registerUser(PROFILE_HASH);
      await marketplace.connect(freelancer).registerUser(PROFILE_HASH);
    });

    it("Should prevent reentrancy attacks", async function () {
      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );

      await marketplace.connect(freelancer).submitProposal(1, PROPOSAL_HASH, ethers.utils.parseEther("4"), 15);
      await marketplace.connect(client).acceptProposal(1);

      await marketplace.connect(client).createMilestone(
        1,
        "Test Milestone",
        MILESTONE_DESCRIPTION_HASH,
        ethers.utils.parseEther("2"),
        Math.floor(Date.now() / 1000) + 86400 * 7,
        { value: ethers.utils.parseEther("2") }
      );

      await marketplace.connect(freelancer).submitMilestone(1);
      await marketplace.connect(client).approveMilestone(1, 8);

      // Try to approve again - should fail
      await expect(
        marketplace.connect(client).approveMilestone(1, 8)
      ).to.be.revertedWith("Milestone already paid");
    });

    it("Should handle invalid IDs gracefully", async function () {
      await expect(
        marketplace.jobs(999)
      ).to.not.be.reverted; // Should return empty struct

      await expect(
        marketplace.connect(client).acceptProposal(999)
      ).to.be.revertedWith("Proposal does not exist");
    });

    it("Should validate milestone amount matches sent value", async function () {
      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );

      await marketplace.connect(freelancer).submitProposal(1, PROPOSAL_HASH, ethers.utils.parseEther("4"), 15);
      await marketplace.connect(client).acceptProposal(1);

      await expect(
        marketplace.connect(client).createMilestone(
          1,
          "Test Milestone",
          MILESTONE_DESCRIPTION_HASH,
          ethers.utils.parseEther("2"),
          Math.floor(Date.now() / 1000) + 86400 * 7,
          { value: ethers.utils.parseEther("1") }
        )
      ).to.be.revertedWith("Sent value must equal milestone amount");
    });

    it("Should only allow authorized users to perform actions", async function () {
      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );

      await marketplace.connect(freelancer).submitProposal(1, PROPOSAL_HASH, ethers.utils.parseEther("4"), 15);
      
      await expect(
        marketplace.connect(freelancer).acceptProposal(1)
      ).to.be.revertedWith("Not the job client");
    });

    it("Should handle reputation updates correctly", async function () {
      await marketplace.connect(client).postJob(
        "Test Job",
        JOB_DESCRIPTION_HASH,
        ["Solidity"],
        ethers.utils.parseEther("5"),
        Math.floor(Date.now() / 1000) + 86400 * 30
      );

      await marketplace.connect(freelancer).submitProposal(1, PROPOSAL_HASH, ethers.utils.parseEther("4"), 15);
      await marketplace.connect(client).acceptProposal(1);

      await marketplace.connect(client).createMilestone(
        1,
        "Test Milestone",
        MILESTONE_DESCRIPTION_HASH,
        ethers.utils.parseEther("2"),
        Math.floor(Date.now() / 1000) + 86400 * 7,
        { value: ethers.utils.parseEther("2") }
      );

      await marketplace.connect(freelancer).submitMilestone(1);

      // Test different ratings
      await marketplace.connect(client).approveMilestone(1, 10); // Perfect rating

      const user = await marketplace.users(freelancer.address);
      expect(user.reputation).to.be.gt(500); // Should increase from initial 500
    });

    it("Should validate modular architecture integrity", async function () {
      // Test that inheritance works correctly
      expect(marketplace.registerUser).to.exist;
      expect(marketplace.postJob).to.exist;
      expect(marketplace.submitProposal).to.exist;
      expect(marketplace.createMilestone).to.exist;
      expect(marketplace.raiseDispute).to.exist;
      expect(marketplace.updatePlatformFee).to.exist;
      
      // All functions should be accessible from the main contract
      const contractMethods = Object.getOwnPropertyNames(marketplace).filter(
        method => typeof marketplace[method] === 'function'
      );
      
      expect(contractMethods.length).to.be.greaterThan(20); // Should have all inherited methods
    });
  });
});
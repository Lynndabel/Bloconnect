// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title FreelanceMarketplace
 * @dev Main contract for decentralized freelance platform
 */
contract FreelanceMarketplace is ReentrancyGuard, Pausable, Ownable {
    using Counters for Counters.Counter;

    // Counters
    Counters.Counter private _jobIds;
    Counters.Counter private _proposalIds;
    Counters.Counter private _milestoneIds;
    Counters.Counter private _disputeIds;

    // Platform fee (in basis points, e.g., 250 = 2.5%)
    uint256 public platformFee = 250;
    uint256 private constant MAX_PLATFORM_FEE = 1000; // 10% max

    // Structs
    struct User {
        address userAddress;
        string profileHash; // IPFS hash for profile data
        uint256 reputation; // Score out of 1000
        uint256 totalJobsCompleted;
        uint256 totalEarned;
        bool isActive;
        uint256 createdAt;
    }

    struct Job {
        uint256 jobId;
        address client;
        string title;
        string descriptionHash; // IPFS hash
        string[] skillsRequired;
        uint256 budget;
        uint256 deadline;
        JobStatus status;
        address assignedFreelancer;
        uint256 createdAt;
        uint256 totalMilestones;
    }

    struct Proposal {
        uint256 proposalId;
        uint256 jobId;
        address freelancer;
        string proposalHash; // IPFS hash
        uint256 proposedBudget;
        uint256 proposedDuration; // in days
        ProposalStatus status;
        uint256 createdAt;
    }

    struct Milestone {
        uint256 milestoneId;
        uint256 jobId;
        string title;
        string descriptionHash;
        uint256 amount;
        uint256 deadline;
        MilestoneStatus status;
        bool isPaid;
        uint256 createdAt;
        uint256 completedAt;
    }

    struct Dispute {
        uint256 disputeId;
        uint256 jobId;
        uint256 milestoneId;
        address initiator;
        string reason;
        DisputeStatus status;
        address arbitrator;
        uint256 createdAt;
        uint256 resolvedAt;
    }

    // Enums
    enum JobStatus { Open, InProgress, Completed, Cancelled, Disputed }
    enum ProposalStatus { Pending, Accepted, Rejected, Withdrawn }
    enum MilestoneStatus { Created, InProgress, Submitted, Approved, Disputed }
    enum DisputeStatus { Open, InProgress, Resolved, Escalated }

    // Mappings
    mapping(address => User) public users;
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => Milestone) public milestones;
    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => uint256[]) public jobMilestones; // jobId => milestoneIds
    mapping(uint256 => uint256[]) public jobProposals; // jobId => proposalIds
    mapping(address => uint256[]) public userJobs; // user => jobIds
    mapping(address => uint256[]) public userProposals; // user => proposalIds
    mapping(uint256 => uint256) public escrowBalances; // milestoneId => amount

    // Events
    event UserRegistered(address indexed user, string profileHash);
    event JobPosted(uint256 indexed jobId, address indexed client, uint256 budget);
    event ProposalSubmitted(uint256 indexed proposalId, uint256 indexed jobId, address indexed freelancer);
    event ProposalAccepted(uint256 indexed proposalId, uint256 indexed jobId, address indexed freelancer);
    event MilestoneCreated(uint256 indexed milestoneId, uint256 indexed jobId, uint256 amount);
    event MilestoneSubmitted(uint256 indexed milestoneId, uint256 indexed jobId);
    event MilestoneApproved(uint256 indexed milestoneId, uint256 indexed jobId);
    event PaymentReleased(uint256 indexed milestoneId, address indexed freelancer, uint256 amount);
    event DisputeRaised(uint256 indexed disputeId, uint256 indexed jobId, address indexed initiator);
    event DisputeResolved(uint256 indexed disputeId, address indexed resolver);
    event ReputationUpdated(address indexed user, uint256 newReputation);

    // Modifiers
    modifier onlyRegisteredUser() {
        require(users[msg.sender].isActive, "User not registered or inactive");
        _;
    }

    modifier onlyJobClient(uint256 _jobId) {
        require(jobs[_jobId].client == msg.sender, "Not the job client");
        _;
    }

    modifier onlyAssignedFreelancer(uint256 _jobId) {
        require(jobs[_jobId].assignedFreelancer == msg.sender, "Not the assigned freelancer");
        _;
    }

    modifier validJobId(uint256 _jobId) {
        require(_jobId > 0 && _jobId <= _jobIds.current(), "Invalid job ID");
        _;
    }

    modifier validMilestoneId(uint256 _milestoneId) {
        require(_milestoneId > 0 && _milestoneId <= _milestoneIds.current(), "Invalid milestone ID");
        _;
    }

    constructor() {}

    /**
     * @dev Register a new user
     * @param _profileHash IPFS hash containing user profile data
     */
    function registerUser(string memory _profileHash) external {
        require(!users[msg.sender].isActive, "User already registered");
        require(bytes(_profileHash).length > 0, "Profile hash cannot be empty");

        users[msg.sender] = User({
            userAddress: msg.sender,
            profileHash: _profileHash,
            reputation: 500, // Start with neutral reputation
            totalJobsCompleted: 0,
            totalEarned: 0,
            isActive: true,
            createdAt: block.timestamp
        });

        emit UserRegistered(msg.sender, _profileHash);
    }

    /**
     * @dev Update user profile
     * @param _profileHash New IPFS hash for profile data
     */
    function updateProfile(string memory _profileHash) external onlyRegisteredUser {
        require(bytes(_profileHash).length > 0, "Profile hash cannot be empty");
        users[msg.sender].profileHash = _profileHash;
    }

    /**
     * @dev Post a new job
     * @param _title Job title
     * @param _descriptionHash IPFS hash for job description
     * @param _skillsRequired Array of required skills
     * @param _budget Job budget in wei
     * @param _deadline Job deadline timestamp
     */
    function postJob(
        string memory _title,
        string memory _descriptionHash,
        string[] memory _skillsRequired,
        uint256 _budget,
        uint256 _deadline
    ) external onlyRegisteredUser whenNotPaused {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_descriptionHash).length > 0, "Description hash cannot be empty");
        require(_budget > 0, "Budget must be greater than 0");
        require(_deadline > block.timestamp, "Deadline must be in the future");

        _jobIds.increment();
        uint256 newJobId = _jobIds.current();

        jobs[newJobId] = Job({
            jobId: newJobId,
            client: msg.sender,
            title: _title,
            descriptionHash: _descriptionHash,
            skillsRequired: _skillsRequired,
            budget: _budget,
            deadline: _deadline,
            status: JobStatus.Open,
            assignedFreelancer: address(0),
            createdAt: block.timestamp,
            totalMilestones: 0
        });

        userJobs[msg.sender].push(newJobId);

        emit JobPosted(newJobId, msg.sender, _budget);
    }

    /**
     * @dev Submit a proposal for a job
     * @param _jobId Job ID to propose for
     * @param _proposalHash IPFS hash for proposal details
     * @param _proposedBudget Proposed budget
     * @param _proposedDuration Proposed duration in days
     */
    function submitProposal(
        uint256 _jobId,
        string memory _proposalHash,
        uint256 _proposedBudget,
        uint256 _proposedDuration
    ) external onlyRegisteredUser validJobId(_jobId) whenNotPaused {
        require(jobs[_jobId].status == JobStatus.Open, "Job is not open for proposals");
        require(jobs[_jobId].client != msg.sender, "Cannot propose on own job");
        require(_proposedBudget > 0, "Proposed budget must be greater than 0");
        require(_proposedDuration > 0, "Proposed duration must be greater than 0");

        _proposalIds.increment();
        uint256 newProposalId = _proposalIds.current();

        proposals[newProposalId] = Proposal({
            proposalId: newProposalId,
            jobId: _jobId,
            freelancer: msg.sender,
            proposalHash: _proposalHash,
            proposedBudget: _proposedBudget,
            proposedDuration: _proposedDuration,
            status: ProposalStatus.Pending,
            createdAt: block.timestamp
        });

        jobProposals[_jobId].push(newProposalId);
        userProposals[msg.sender].push(newProposalId);

        emit ProposalSubmitted(newProposalId, _jobId, msg.sender);
    }

    /**
     * @dev Accept a proposal
     * @param _proposalId Proposal ID to accept
     */
    function acceptProposal(uint256 _proposalId) external onlyRegisteredUser whenNotPaused {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.proposalId != 0, "Proposal does not exist");
        require(jobs[proposal.jobId].client == msg.sender, "Not the job client");
        require(proposal.status == ProposalStatus.Pending, "Proposal not pending");
        require(jobs[proposal.jobId].status == JobStatus.Open, "Job is not open");

        // Update proposal status
        proposal.status = ProposalStatus.Accepted;

        // Update job
        jobs[proposal.jobId].status = JobStatus.InProgress;
        jobs[proposal.jobId].assignedFreelancer = proposal.freelancer;
        jobs[proposal.jobId].budget = proposal.proposedBudget;

        // Reject all other proposals for this job
        uint256[] memory jobProposalIds = jobProposals[proposal.jobId];
        for (uint256 i = 0; i < jobProposalIds.length; i++) {
            if (jobProposalIds[i] != _proposalId && proposals[jobProposalIds[i]].status == ProposalStatus.Pending) {
                proposals[jobProposalIds[i]].status = ProposalStatus.Rejected;
            }
        }

        emit ProposalAccepted(_proposalId, proposal.jobId, proposal.freelancer);
    }

    /**
     * @dev Create a milestone for a job
     * @param _jobId Job ID
     * @param _title Milestone title
     * @param _descriptionHash IPFS hash for milestone description
     * @param _amount Milestone amount
     * @param _deadline Milestone deadline
     */
    function createMilestone(
        uint256 _jobId,
        string memory _title,
        string memory _descriptionHash,
        uint256 _amount,
        uint256 _deadline
    ) external payable onlyJobClient(_jobId) validJobId(_jobId) whenNotPaused {
        require(jobs[_jobId].status == JobStatus.InProgress, "Job not in progress");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_amount > 0, "Amount must be greater than 0");
        require(_deadline > block.timestamp, "Deadline must be in the future");
        require(msg.value == _amount, "Sent value must equal milestone amount");

        _milestoneIds.increment();
        uint256 newMilestoneId = _milestoneIds.current();

        milestones[newMilestoneId] = Milestone({
            milestoneId: newMilestoneId,
            jobId: _jobId,
            title: _title,
            descriptionHash: _descriptionHash,
            amount: _amount,
            deadline: _deadline,
            status: MilestoneStatus.Created,
            isPaid: false,
            createdAt: block.timestamp,
            completedAt: 0
        });

        jobMilestones[_jobId].push(newMilestoneId);
        escrowBalances[newMilestoneId] = _amount;
        jobs[_jobId].totalMilestones++;

        emit MilestoneCreated(newMilestoneId, _jobId, _amount);
    }

    /**
     * @dev Submit milestone for approval
     * @param _milestoneId Milestone ID
     */
    function submitMilestone(uint256 _milestoneId) 
        external 
        validMilestoneId(_milestoneId) 
        onlyAssignedFreelancer(milestones[_milestoneId].jobId) 
        whenNotPaused 
    {
        Milestone storage milestone = milestones[_milestoneId];
        require(milestone.status == MilestoneStatus.Created || milestone.status == MilestoneStatus.InProgress, "Invalid milestone status");

        milestone.status = MilestoneStatus.Submitted;
        milestone.completedAt = block.timestamp;

        emit MilestoneSubmitted(_milestoneId, milestone.jobId);
    }

    /**
     * @dev Approve milestone and release payment
     * @param _milestoneId Milestone ID
     * @param _rating Rating for freelancer (1-10)
     */
    function approveMilestone(uint256 _milestoneId, uint8 _rating) 
        external 
        validMilestoneId(_milestoneId) 
        onlyJobClient(milestones[_milestoneId].jobId) 
        nonReentrant 
        whenNotPaused 
    {
        require(_rating >= 1 && _rating <= 10, "Rating must be between 1 and 10");
        
        Milestone storage milestone = milestones[_milestoneId];
        require(milestone.status == MilestoneStatus.Submitted, "Milestone not submitted");
        require(!milestone.isPaid, "Milestone already paid");

        Job storage job = jobs[milestone.jobId];
        address freelancer = job.assignedFreelancer;
        uint256 amount = milestone.amount;

        // Calculate fees
        uint256 feeAmount = (amount * platformFee) / 10000;
        uint256 freelancerAmount = amount - feeAmount;

        // Update milestone
        milestone.status = MilestoneStatus.Approved;
        milestone.isPaid = true;

        // Update escrow
        escrowBalances[_milestoneId] = 0;

        // Update user stats
        users[freelancer].totalEarned += freelancerAmount;
        users[freelancer].totalJobsCompleted++;

        // Update reputation based on rating
        _updateReputation(freelancer, _rating);

        // Transfer payments
        payable(freelancer).transfer(freelancerAmount);
        if (feeAmount > 0) {
            payable(owner()).transfer(feeAmount);
        }

        emit MilestoneApproved(_milestoneId, milestone.jobId);
        emit PaymentReleased(_milestoneId, freelancer, freelancerAmount);
    }

    /**
     * @dev Raise a dispute for a milestone
     * @param _milestoneId Milestone ID
     * @param _reason Dispute reason
     */
    function raiseDispute(uint256 _milestoneId, string memory _reason) 
        external 
        validMilestoneId(_milestoneId) 
        whenNotPaused 
    {
        Milestone storage milestone = milestones[_milestoneId];
        Job storage job = jobs[milestone.jobId];
        
        require(
            msg.sender == job.client || msg.sender == job.assignedFreelancer,
            "Only job participants can raise disputes"
        );
        require(milestone.status == MilestoneStatus.Submitted, "Can only dispute submitted milestones");
        require(bytes(_reason).length > 0, "Reason cannot be empty");

        _disputeIds.increment();
        uint256 newDisputeId = _disputeIds.current();

        disputes[newDisputeId] = Dispute({
            disputeId: newDisputeId,
            jobId: milestone.jobId,
            milestoneId: _milestoneId,
            initiator: msg.sender,
            reason: _reason,
            status: DisputeStatus.Open,
            arbitrator: address(0),
            createdAt: block.timestamp,
            resolvedAt: 0
        });

        milestone.status = MilestoneStatus.Disputed;
        job.status = JobStatus.Disputed;

        emit DisputeRaised(newDisputeId, milestone.jobId, msg.sender);
    }

    /**
     * @dev Resolve a dispute (only owner for now, can be extended to arbitrators)
     * @param _disputeId Dispute ID
     * @param _favorFreelancer True if ruling in favor of freelancer
     */
    function resolveDispute(uint256 _disputeId, bool _favorFreelancer) 
        external 
        onlyOwner 
        nonReentrant 
    {
        Dispute storage dispute = disputes[_disputeId];
        require(dispute.status == DisputeStatus.Open, "Dispute not open");

        Milestone storage milestone = milestones[dispute.milestoneId];
        Job storage job = jobs[dispute.jobId];

        dispute.status = DisputeStatus.Resolved;
        dispute.arbitrator = msg.sender;
        dispute.resolvedAt = block.timestamp;

        if (_favorFreelancer) {
            // Release payment to freelancer
            uint256 amount = milestone.amount;
            uint256 feeAmount = (amount * platformFee) / 10000;
            uint256 freelancerAmount = amount - feeAmount;

            milestone.status = MilestoneStatus.Approved;
            milestone.isPaid = true;
            escrowBalances[dispute.milestoneId] = 0;

            users[job.assignedFreelancer].totalEarned += freelancerAmount;
            
            payable(job.assignedFreelancer).transfer(freelancerAmount);
            if (feeAmount > 0) {
                payable(owner()).transfer(feeAmount);
            }
        } else {
            // Refund to client
            milestone.status = MilestoneStatus.Created;
            escrowBalances[dispute.milestoneId] = 0;
            payable(job.client).transfer(milestone.amount);
        }

        job.status = JobStatus.InProgress;

        emit DisputeResolved(_disputeId, msg.sender);
    }

    /**
     * @dev Update user reputation based on rating
     * @param _user User address
     * @param _rating Rating received (1-10)
     */
    function _updateReputation(address _user, uint8 _rating) internal {
        User storage user = users[_user];
        uint256 currentRep = user.reputation;
        uint256 jobsCompleted = user.totalJobsCompleted;

        // Weighted average with more weight on recent ratings
        uint256 newRep = ((currentRep * jobsCompleted) + (_rating * 100)) / (jobsCompleted + 1);
        
        // Ensure reputation stays within bounds (0-1000)
        if (newRep > 1000) newRep = 1000;
        
        user.reputation = newRep;
        emit ReputationUpdated(_user, newRep);
    }

    /**
     * @dev Get job proposals
     * @param _jobId Job ID
     * @return Array of proposal IDs
     */
    function getJobProposals(uint256 _jobId) external view returns (uint256[] memory) {
        return jobProposals[_jobId];
    }

    /**
     * @dev Get job milestones
     * @param _jobId Job ID
     * @return Array of milestone IDs
     */
    function getJobMilestones(uint256 _jobId) external view returns (uint256[] memory) {
        return jobMilestones[_jobId];
    }

    /**
     * @dev Get user jobs
     * @param _user User address
     * @return Array of job IDs
     */
    function getUserJobs(address _user) external view returns (uint256[] memory) {
        return userJobs[_user];
    }

    /**
     * @dev Get user proposals
     * @param _user User address
     * @return Array of proposal IDs
     */
    function getUserProposals(address _user) external view returns (uint256[] memory) {
        return userProposals[_user];
    }

    /**
     * @dev Emergency withdrawal for stuck funds (only owner)
     * @param _to Recipient address
     * @param _amount Amount to withdraw
     */
    function emergencyWithdraw(address payable _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Invalid recipient");
        require(_amount <= address(this).balance, "Insufficient balance");
        _to.transfer(_amount);
    }

    /**
     * @dev Update platform fee (only owner)
     * @param _newFee New fee in basis points
     */
    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= MAX_PLATFORM_FEE, "Fee too high");
        platformFee = _newFee;
    }

    /**
     * @dev Pause/unpause contract (only owner)
     */
    function togglePause() external onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }

    /**
     * @dev Get current counters
     */
    function getCounters() external view returns (uint256, uint256, uint256, uint256) {
        return (_jobIds.current(), _proposalIds.current(), _milestoneIds.current(), _disputeIds.current());
    }

    /**
     * @dev Cancel a job (only client, only if no proposals accepted)
     * @param _jobId Job ID to cancel
     */
    function cancelJob(uint256 _jobId) external onlyJobClient(_jobId) validJobId(_jobId) {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.Open, "Can only cancel open jobs");
        
        job.status = JobStatus.Cancelled;
        emit JobPosted(_jobId, msg.sender, 0); // Emit with 0 budget to indicate cancellation
    }

    /**
     * @dev Withdraw a proposal (only proposal owner, only if pending)
     * @param _proposalId Proposal ID to withdraw
     */
    function withdrawProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.freelancer == msg.sender, "Not proposal owner");
        require(proposal.status == ProposalStatus.Pending, "Can only withdraw pending proposals");
        
        proposal.status = ProposalStatus.Withdrawn;
    }

    /**
     * @dev Get active (open) jobs with pagination
     * @param _offset Starting index
     * @param _limit Number of jobs to return
     * @return Array of job IDs that are open
     */
    function getActiveJobs(uint256 _offset, uint256 _limit) external view returns (uint256[] memory) {
        uint256 totalJobs = _jobIds.current();
        uint256 count = 0;
        
        // First pass: count active jobs
        for (uint256 i = 1; i <= totalJobs; i++) {
            if (jobs[i].status == JobStatus.Open) {
                count++;
            }
        }
        
        // Calculate actual limit based on offset
        uint256 startIdx = 0;
        uint256 resultSize = 0;
        
        if (_offset < count) {
            resultSize = (count - _offset) > _limit ? _limit : (count - _offset);
        }
        
        uint256[] memory activeJobIds = new uint256[](resultSize);
        uint256 currentIdx = 0;
        uint256 resultIdx = 0;
        
        // Second pass: collect active jobs with pagination
        for (uint256 i = 1; i <= totalJobs && resultIdx < resultSize; i++) {
            if (jobs[i].status == JobStatus.Open) {
                if (currentIdx >= _offset) {
                    activeJobIds[resultIdx] = i;
                    resultIdx++;
                }
                currentIdx++;
            }
        }
        
        return activeJobIds;
    }

     // Get user statistics
    
    function getUserStats(address _user) external view returns (
        uint256 jobsPosted,
        uint256 proposalsSubmitted, 
        uint256 jobsCompleted,
        uint256 totalEarned,
        uint256 reputation,
        uint256 averageRating
    ) {
        User memory user = users[_user];
        return (
            userJobs[_user].length,
            userProposals[_user].length,
            user.totalJobsCompleted,
            user.totalEarned,
            user.reputation,
            user.totalJobsCompleted > 0 ? (user.reputation * user.totalJobsCompleted) / (user.totalJobsCompleted * 10) : 0
        );
    }

     // Get platform statistics
    function getPlatformStats() external view returns (
        uint256 totalJobs,
        uint256 totalProposals,
        uint256 totalMilestones,
        uint256 totalDisputes,
        uint256 activeJobs,
        uint256 totalValueLocked,
        uint256 platformFeeCollected
    ) {
        // Count active jobs
        uint256 activeJobCount = 0;
        uint256 totalJobs_ = _jobIds.current();
        
        for (uint256 i = 1; i <= totalJobs_; i++) {
            if (jobs[i].status == JobStatus.Open || jobs[i].status == JobStatus.InProgress) {
                activeJobCount++;
            }
        }

        // Calculate total value locked in escrow
        uint256 totalLocked = 0;
        uint256 totalMilestones_ = _milestoneIds.current();
        
        for (uint256 i = 1; i <= totalMilestones_; i++) {
            totalLocked += escrowBalances[i];
        }

        return (
            totalJobs_,
            _proposalIds.current(),
            totalMilestones_,
            _disputeIds.current(),
            activeJobCount,
            totalLocked,
            address(this).balance - totalLocked // Approximate platform fees collected
        );
    }

    /**
     * @dev Check if user is registered
     * @param _user User address to check
     * @return True if user is registered and active
     */
    function isUserRegistered(address _user) external view returns (bool) {
        return users[_user].isActive;
    }

    // Get milestone details with escrow info
    function getMilestoneWithEscrow(uint256 _milestoneId) external view validMilestoneId(_milestoneId) returns (
        Milestone memory milestone,
        uint256 escrowBalance
    ) {
        return (milestones[_milestoneId], escrowBalances[_milestoneId]);
    }

    /**
     * @dev Batch get multiple jobs
     * @param jobIds Array of job IDs
     * @return Array of job data
     */
    function getMultipleJobs(uint256[] memory jobIds) external view returns (Job[] memory) {
        Job[] memory jobsData = new Job[](jobIds.length);
        
        for (uint256 i = 0; i < jobIds.length; i++) {
            if (jobIds[i] > 0 && jobIds[i] <= _jobIds.current()) {
                jobsData[i] = jobs[jobIds[i]];
            }
        }
        
        return jobsData;
    }

    /**
     * @dev Complete a job (when all milestones are done)
     * @param _jobId Job ID to complete
     */
    function completeJob(uint256 _jobId) external onlyJobClient(_jobId) validJobId(_jobId) {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.InProgress, "Job not in progress");
        
        // Check that all milestones are completed
        uint256[] memory milestoneIds = jobMilestones[_jobId];
        require(milestoneIds.length > 0, "No milestones created");
        
        for (uint256 i = 0; i < milestoneIds.length; i++) {
            Milestone memory milestone = milestones[milestoneIds[i]];
            require(milestone.status == MilestoneStatus.Approved, "All milestones must be approved");
        }
        
        job.status = JobStatus.Completed;
    }

    /**
     * @dev Get total escrow balance
     * @return Total ETH locked in escrow
     */
    function getTotalEscrowBalance() external view returns (uint256) {
        uint256 total = 0;
        uint256 totalMilestones_ = _milestoneIds.current();
        
        for (uint256 i = 1; i <= totalMilestones_; i++) {
            total += escrowBalances[i];
        }
        
        return total;
    }

    // Receive function to accept payments
    receive() external payable {}
}
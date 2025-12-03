// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title FreelanceBase
 * @dev Base contract with all structs, enums, events, and storage
 */
contract FreelanceBase is Initializable, ReentrancyGuardUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    function __FreelanceBase_init() internal onlyInitializing {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
    }
    using Counters for Counters.Counter;

    // Counters
    Counters.Counter public _jobIds;
    Counters.Counter public _proposalIds;
    Counters.Counter public _milestoneIds;
    Counters.Counter public _disputeIds;

    // Platform fee (in basis points, e.g., 250 = 2.5%)
    uint256 public platformFee = 250;
    uint256 internal constant MAX_PLATFORM_FEE = 1000; // 10% max

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
        string coverLetterHash; // IPFS hash
        uint256 proposedBudget;
        uint256 estimatedDays;
        ProposalStatus status;
        uint256 createdAt;
    }

    struct Milestone {
        uint256 milestoneId;
        uint256 jobId;
        string title;
        string descriptionHash;
        uint256 amount;
        uint256 dueDate;
        MilestoneStatus status;
        uint256 createdAt;
        uint256 completedAt;
    }

    struct Dispute {
        uint256 disputeId;
        uint256 jobId;
        address initiator;
        string reason;
        string evidenceHash;
        DisputeStatus status;
        string resolution;
        uint256 createdAt;
        uint256 resolvedAt;
    }

    // Enums
    enum JobStatus { Open, InProgress, Completed, Cancelled, Disputed }
    enum ProposalStatus { Pending, Accepted, Rejected, Withdrawn }
    enum MilestoneStatus { Pending, Submitted, Approved }
    enum DisputeStatus { Open, Resolved }

    // Mappings
    mapping(address => User) public users;
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => Milestone) public milestones;
    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => uint256[]) public jobMilestones; // jobId => milestoneIds
    mapping(uint256 => uint256[]) public jobProposals; // jobId => proposalIds
    mapping(uint256 => uint256[]) public disputesByJob; // jobId => disputeIds
    mapping(address => uint256[]) public userJobs; // user => jobIds
    mapping(address => uint256[]) public userProposals; // user => proposalIds
    mapping(uint256 => uint256) public escrowBalances; // milestoneId => amount

    // Events
    event UserRegistered(address indexed user, string profileHash);
    event JobPosted(uint256 indexed jobId, address indexed client, uint256 budget);
    event ProposalSubmitted(uint256 indexed proposalId, uint256 indexed jobId, address indexed freelancer, uint256 proposedBudget);
    event ProposalAccepted(uint256 indexed proposalId, uint256 indexed jobId, address indexed freelancer);
    event ProposalWithdrawn(uint256 indexed proposalId, uint256 indexed jobId, address indexed freelancer);
    event MilestoneCreated(uint256 indexed milestoneId, uint256 indexed jobId, uint256 amount);
    event MilestoneSubmitted(uint256 indexed milestoneId, uint256 indexed jobId, address indexed freelancer);
    event MilestoneApproved(uint256 indexed milestoneId, uint256 indexed jobId, address indexed freelancer, uint256 amount);
    event MilestoneRevisionRequested(uint256 indexed milestoneId, uint256 indexed jobId, string revisionHash);
    event DisputeRaised(uint256 indexed disputeId, uint256 indexed jobId, address indexed initiator);
    event DisputeResolved(uint256 indexed disputeId, uint256 indexed jobId, uint8 refundToClient);

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

    modifier validProposalId(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= _proposalIds.current(), "Invalid proposal ID");
        _;
    }

    modifier validMilestoneId(uint256 _milestoneId) {
        require(_milestoneId > 0 && _milestoneId <= _milestoneIds.current(), "Invalid milestone ID");
        _;
    }

    modifier validDisputeId(uint256 _disputeId) {
        require(_disputeId > 0 && _disputeId <= _disputeIds.current(), "Invalid dispute ID");
        _;
    }

    function __FreelanceBase_init() internal initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __Ownable_init();
    }

    // Receive function to accept payments
    receive() external payable {}

    // Counter functions
    function _incrementJobIds() internal {
        _jobIds.increment();
    }

    function _incrementProposalIds() internal {
        _proposalIds.increment();
    }

    function _incrementMilestoneIds() internal {
        _milestoneIds.increment();
    }

    function _incrementDisputeIds() internal {
        _disputeIds.increment();
    }

    function _getCurrentJobId() internal view returns (uint256) {
        return _jobIds.current();
    }

    function _getCurrentProposalId() internal view returns (uint256) {
        return _proposalIds.current();
    }

    function _getCurrentMilestoneId() internal view returns (uint256) {
        return _milestoneIds.current();
    }

    function _getCurrentDisputeId() internal view returns (uint256) {
        return _disputeIds.current();
    }
}
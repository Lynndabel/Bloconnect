// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Bloconnect - Artisan registry, job payment, and escrow contract
/// @notice Supports job creation, verification, cancellation, dispute resolution, and timeouts.
contract Bloconnect {
    // --- Ownership & Platform Config ---

    address public owner;
    uint256 public platformFeePercent = 5; // 5% platform fee by default
    uint256 public jobTimeoutDays = 7; // days before artisan can claim if not completed
    uint256 public disputeWindowDays = 2; // days client has to dispute claimed job

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // --- Admin Functions ---

    function setPlatformFee(uint256 feePercent) external onlyOwner {
        require(feePercent <= 50, "Fee too high");
        platformFeePercent = feePercent;
    }

    function setJobTimeout(uint256 days_) external onlyOwner {
        require(days_ > 0, "Timeout must be positive");
        jobTimeoutDays = days_;
    }

    function setDisputeWindow(uint256 days_) external onlyOwner {
        require(days_ > 0, "Dispute window must be positive");
        disputeWindowDays = days_;
    }

    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        (bool ok, ) = owner.call{value: balance}("");
        require(ok, "Transfer failed");
    }

    // --- Artisans ---

    struct Artisan {
        bool registered;
        bool verified;     // Simple verification status
        string metadataURI; // optional off-chain profile data (IPFS/URL)
    }

    mapping(address => Artisan) public artisans;

    event ArtisanRegistered(address indexed artisan, string metadataURI);
    event ArtisanUpdated(address indexed artisan, string metadataURI);
    event ArtisanVerificationUpdated(address indexed artisan, bool verified);
    event IdentityVerified(address indexed artisan, uint256 timestamp);

    /// @notice Register the caller as an artisan.
    /// @param metadataURI A URI pointing to off-chain profile data (can be empty).
    function registerArtisan(string calldata metadataURI) external {
        Artisan storage a = artisans[msg.sender];

        if (!a.registered) {
            a.registered = true;
            a.metadataURI = metadataURI;
            emit ArtisanRegistered(msg.sender, metadataURI);
        } else {
            a.metadataURI = metadataURI;
            emit ArtisanUpdated(msg.sender, metadataURI);
        }
    }

    /// @notice Set or unset the verification flag for an artisan.
    /// @dev Only the contract owner (platform admin) can call this.
    function setArtisanVerified(address artisan, bool verified) external onlyOwner {
        require(artisans[artisan].registered, "Artisan not registered");

        artisans[artisan].verified = verified;
        emit ArtisanVerificationUpdated(artisan, verified);
    }

    /// @notice Simple function for artisans to verify their identity
    /// @dev This would be called after off-chain verification is complete
    function verifyIdentity() external {
        require(artisans[msg.sender].registered, "Register as artisan first");
        require(!artisans[msg.sender].verified, "Already verified");
        
        artisans[msg.sender].verified = true;
        emit IdentityVerified(msg.sender, block.timestamp);
    }

    // --- Jobs ---

    enum JobStatus { Active, Completed, Withdrawn, ClaimedByArtisan, Disputed, Cancelled }

    struct Job {
        address client;
        address artisan;
        uint256 amount; // total amount locked
        JobStatus status;
        uint256 createdAt; // timestamp for timeout logic
        uint256 claimedAt; // timestamp when artisan claimed after timeout
        string description; // short job description
    }

    uint256 public nextJobId;
    mapping(uint256 => Job) public jobs;
    uint256 public accumulatedFees; // platform fees waiting to be withdrawn

    event JobCreated(
        uint256 indexed jobId,
        address indexed client,
        address indexed artisan,
        uint256 amount,
        string description
    );
    event JobCompleted(uint256 indexed jobId);
    event JobCancelled(uint256 indexed jobId, address indexed cancelledBy);
    event JobWithdrawn(uint256 indexed jobId, address indexed artisan, uint256 amountAfterFee, uint256 platformFee);
    event JobClaimedAfterTimeout(uint256 indexed jobId, address indexed artisan, uint256 claimedAt);
    event JobDisputedByCLient(uint256 indexed jobId, address indexed client);
    event JobFinalizedAfterDispute(uint256 indexed jobId, address indexed artisan, uint256 amountAfterFee, uint256 platformFee);

    /// @notice Create and fund a job for a verified artisan.
    /// @dev The artisan must be registered and verified. Sent ETH becomes the job amount.
    /// @param artisan The artisan who will perform the job.
    /// @param description Short description of the job.
    /// @return jobId The id of the newly created job.
    function createJob(address artisan, string calldata description) external payable returns (uint256 jobId) {
        require(msg.value > 0, "No funds sent");
        require(msg.sender != artisan, "Cannot hire yourself");
        require(artisans[artisan].registered, "Artisan not registered");
        require(artisans[artisan].verified, "Artisan not verified");

        jobId = nextJobId;
        nextJobId += 1;

        jobs[jobId] = Job({
            client: msg.sender,
            artisan: artisan,
            amount: msg.value,
            status: JobStatus.Active,
            createdAt: block.timestamp,
            claimedAt: 0,
            description: description
        });

        emit JobCreated(jobId, msg.sender, artisan, msg.value, description);
    }

    /// @notice Mark a job as completed by the client.
    /// @dev Only the client who created the job can mark it completed.
    function completeJob(uint256 jobId) external {
        Job storage job = jobs[jobId];
        require(job.client != address(0), "Job does not exist");
        require(msg.sender == job.client, "Not job client");
        require(job.status == JobStatus.Active, "Job not active");

        job.status = JobStatus.Completed;
        emit JobCompleted(jobId);
    }

    /// @notice Cancel an active job and refund the client.
    /// @dev Client can cancel anytime. Artisan can only cancel after timeout.
    function cancelJob(uint256 jobId) external {
        Job storage job = jobs[jobId];
        require(job.client != address(0), "Job does not exist");
        require(job.status == JobStatus.Active, "Job not active");

        bool isClient = msg.sender == job.client;
        bool isArtisanAfterTimeout = msg.sender == job.artisan && 
            (block.timestamp >= job.createdAt + (jobTimeoutDays * 1 days));

        require(isClient || isArtisanAfterTimeout, "Cannot cancel this job");

        job.status = JobStatus.Cancelled;
        uint256 refundAmount = job.amount;
        job.amount = 0;

        (bool ok, ) = job.client.call{value: refundAmount}("");
        require(ok, "Refund failed");

        emit JobCancelled(jobId, msg.sender);
    }

    /// @notice Artisan withdraws funds for a completed job.
    /// @dev Can only be called once per job, after completion.
    /// @dev Platform fee is deducted automatically.
    function withdrawJobPayment(uint256 jobId) external {
        Job storage job = jobs[jobId];
        require(job.client != address(0), "Job does not exist");
        require(msg.sender == job.artisan, "Not job artisan");
        require(job.status == JobStatus.Completed, "Job not completed");

        job.status = JobStatus.Withdrawn;
        uint256 totalAmount = job.amount;
        job.amount = 0;

        // Calculate platform fee and artisan amount
        uint256 platformFee = (totalAmount * platformFeePercent) / 100;
        uint256 artisanAmount = totalAmount - platformFee;

        accumulatedFees += platformFee;

        (bool ok, ) = msg.sender.call{value: artisanAmount}("");
        require(ok, "Transfer failed");

        emit JobWithdrawn(jobId, msg.sender, artisanAmount, platformFee);
    }

    /// @notice Artisan can claim payment if job has timed out and not been completed.
    /// @dev Allows artisan to recover funds if client goes silent. Starts dispute window.
    function claimJobAfterTimeout(uint256 jobId) external {
        Job storage job = jobs[jobId];
        require(job.client != address(0), "Job does not exist");
        require(msg.sender == job.artisan, "Not job artisan");
        require(job.status == JobStatus.Active, "Job not active");
        require(block.timestamp >= job.createdAt + (jobTimeoutDays * 1 days), "Timeout not reached");

        job.status = JobStatus.ClaimedByArtisan;
        job.claimedAt = block.timestamp;

        emit JobClaimedAfterTimeout(jobId, msg.sender, block.timestamp);
    }

    /// @notice Client can dispute a claimed job within the dispute window.
    /// @dev Refunds the client if they dispute within the window.
    function disputeClaimedJob(uint256 jobId) external {
        Job storage job = jobs[jobId];
        require(job.client != address(0), "Job does not exist");
        require(msg.sender == job.client, "Not job client");
        require(job.status == JobStatus.ClaimedByArtisan, "Job not claimed by artisan");
        require(block.timestamp <= job.claimedAt + (disputeWindowDays * 1 days), "Dispute window closed");

        job.status = JobStatus.Disputed;
        uint256 refundAmount = job.amount;
        job.amount = 0;

        (bool ok, ) = job.client.call{value: refundAmount}("");
        require(ok, "Refund failed");

        emit JobDisputedByCLient(jobId, msg.sender);
    }

    /// @notice Artisan can finalize withdrawal after dispute window closes.
    /// @dev Only callable if no dispute was filed and window has passed.
    function finalizeClaimedJob(uint256 jobId) external {
        Job storage job = jobs[jobId];
        require(job.client != address(0), "Job does not exist");
        require(msg.sender == job.artisan, "Not job artisan");
        require(job.status == JobStatus.ClaimedByArtisan, "Job not claimed by artisan");
        require(block.timestamp > job.claimedAt + (disputeWindowDays * 1 days), "Dispute window still open");

        job.status = JobStatus.Withdrawn;
        uint256 totalAmount = job.amount;
        job.amount = 0;

        // Calculate platform fee and artisan amount
        uint256 platformFee = (totalAmount * platformFeePercent) / 100;
        uint256 artisanAmount = totalAmount - platformFee;

        accumulatedFees += platformFee;

        (bool ok, ) = msg.sender.call{value: artisanAmount}("");
        require(ok, "Transfer failed");

        emit JobFinalizedAfterDispute(jobId, msg.sender, artisanAmount, platformFee);
    }

    // --- Fallback ---

    /// @notice Accept ETH transfers (optional, for future features like direct tips).
    receive() external payable {}
}
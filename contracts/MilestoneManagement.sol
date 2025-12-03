// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ProposalManagement.sol";

/**
 * @title MilestoneManagement
 * @dev Handles milestone creation and management for jobs
 */
abstract contract MilestoneManagement is UserManagement {

    /**
     * @dev Create a milestone for a job
     * @param _jobId Job ID
     * @param _title Milestone title
     * @param _descriptionHash IPFS hash of milestone description
     * @param _amount Amount allocated for this milestone
     * @param _dueDate Due date for the milestone
     */
    function createMilestone(
        uint256 _jobId,
        string memory _title,
        string memory _descriptionHash,
        uint256 _amount,
        uint256 _dueDate
    ) external virtual onlyJobClient(_jobId) validJobId(_jobId) whenNotPaused {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.InProgress, "Job not in progress");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_descriptionHash).length > 0, "Description hash cannot be empty");
        require(_amount > 0, "Amount must be greater than 0");
        require(_dueDate > block.timestamp, "Due date must be in the future");

        // Check if total milestone amounts exceed job budget
        uint256[] memory existingMilestones = jobMilestones[_jobId];
        uint256 totalAmount = _amount;
        for (uint256 i = 0; i < existingMilestones.length; i++) {
            totalAmount += milestones[existingMilestones[i]].amount;
        }
        require(totalAmount <= job.budget, "Total milestone amounts exceed job budget");

        _incrementMilestoneIds();
        uint256 newMilestoneId = _getCurrentMilestoneId();

        milestones[newMilestoneId] = Milestone({
            milestoneId: newMilestoneId,
            jobId: _jobId,
            title: _title,
            descriptionHash: _descriptionHash,
            amount: _amount,
            dueDate: _dueDate,
            status: MilestoneStatus.Pending,
            createdAt: block.timestamp,
            completedAt: 0
        });

        jobMilestones[_jobId].push(newMilestoneId);
        job.totalMilestones++;

        emit MilestoneCreated(newMilestoneId, _jobId, _amount);
    }

    /**
     * @dev Fund a milestone by depositing the required amount into escrow
     * @param _milestoneId Milestone ID to fund
     */
    function fundMilestone(uint256 _milestoneId) external payable virtual onlyJobClient(milestones[_milestoneId].jobId) validMilestoneId(_milestoneId) whenNotPaused {
        Milestone storage milestone = milestones[_milestoneId];
        require(milestone.status == MilestoneStatus.Pending, "Milestone not pending");
        require(msg.value == milestone.amount, "Incorrect funding amount");
        require(escrowBalances[_milestoneId] == 0, "Milestone already funded");

        escrowBalances[_milestoneId] = msg.value;
        _totalValueLocked += msg.value;
    }

    /**
     * @dev Submit a milestone for review
     * @param _milestoneId Milestone ID
     * @param _submissionHash IPFS hash of milestone submission
     */
    function submitMilestone(
        uint256 _milestoneId,
        string memory _submissionHash
    ) external virtual validMilestoneId(_milestoneId) whenNotPaused {
        Milestone storage milestone = milestones[_milestoneId];
        Job storage job = jobs[milestone.jobId];

        require(msg.sender == job.assignedFreelancer, "Only assigned freelancer can submit");
        require(milestone.status == MilestoneStatus.Pending, "Milestone not pending");
        require(bytes(_submissionHash).length > 0, "Submission hash cannot be empty");

        milestone.status = MilestoneStatus.Submitted;
        emit MilestoneSubmitted(_milestoneId, milestone.jobId, msg.sender);
    }

    /**
     * @dev Approve a submitted milestone
     * @param _milestoneId Milestone ID
     */
    function approveMilestone(uint256 _milestoneId) external virtual validMilestoneId(_milestoneId) whenNotPaused {
        Milestone storage milestone = milestones[_milestoneId];
        Job storage job = jobs[milestone.jobId];

        require(msg.sender == job.client, "Only job client can approve");
        require(milestone.status == MilestoneStatus.Submitted, "Milestone not submitted");

        require(escrowBalances[_milestoneId] == milestone.amount, "Milestone not funded");

        // Calculate fees and payout
        uint256 feeAmount = (milestone.amount * platformFee) / 10000;
        uint256 freelancerPayout = milestone.amount - feeAmount;

        // Update stats
        _totalValueLocked -= milestone.amount;
        _platformFeeCollected += feeAmount;
        _updateUserStats(job.assignedFreelancer, freelancerPayout, false);

        // Mark as approved and transfer funds
        milestone.status = MilestoneStatus.Approved;
        milestone.completedAt = block.timestamp;
        escrowBalances[_milestoneId] = 0;

        payable(job.assignedFreelancer).transfer(freelancerPayout);

        emit MilestoneApproved(_milestoneId, milestone.jobId, job.assignedFreelancer, freelancerPayout);
    }

    /**
     * @dev Request revision for a submitted milestone
     * @param _milestoneId Milestone ID
     * @param _revisionHash IPFS hash of revision details
     */
    function requestMilestoneRevision(
        uint256 _milestoneId,
        string memory _revisionHash
    ) external virtual validMilestoneId(_milestoneId) whenNotPaused {
        Milestone storage milestone = milestones[_milestoneId];
        Job storage job = jobs[milestone.jobId];

        require(msg.sender == job.client, "Only job client can request revision");
        require(milestone.status == MilestoneStatus.Submitted, "Milestone not submitted");
        require(bytes(_revisionHash).length > 0, "Revision hash cannot be empty");

        milestone.status = MilestoneStatus.Pending;
        emit MilestoneRevisionRequested(_milestoneId, milestone.jobId, _revisionHash);
    }

    /**
     * @dev Get milestone details
     * @param _milestoneId Milestone ID
     * @return Milestone data
     */
    function getMilestone(uint256 _milestoneId) external view returns (Milestone memory) {
        require(_milestoneId > 0 && _milestoneId <= _getCurrentMilestoneId(), "Invalid milestone ID");
        return milestones[_milestoneId];
    }

    /**
     * @dev Batch get multiple milestones
     * @param milestoneIds Array of milestone IDs
     * @return Array of milestone data
     */
    function getMultipleMilestones(uint256[] memory milestoneIds) external view virtual returns (Milestone[] memory) {
        Milestone[] memory milestonesData = new Milestone[](milestoneIds.length);
        
        for (uint256 i = 0; i < milestoneIds.length; i++) {
            if (milestoneIds[i] > 0 && milestoneIds[i] <= _getCurrentMilestoneId()) {
                milestonesData[i] = milestones[milestoneIds[i]];
            }
        }
        
        return milestonesData;
    }
}
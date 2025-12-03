// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MilestoneManagement.sol";

/**
 * @title DisputeManagement
 * @dev Handles dispute creation and resolution for jobs
 */
abstract contract DisputeManagement is FreelanceBase {

    /**
     * @dev Raise a dispute for a job
     * @param _jobId Job ID
     * @param _reason Reason for dispute
     * @param _evidenceHash IPFS hash of evidence
     */
    function raiseDispute(
        uint256 _jobId,
        string memory _reason,
        string memory _evidenceHash
    ) external virtual validJobId(_jobId) whenNotPaused {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.client || msg.sender == job.assignedFreelancer, "Not authorized");
        require(job.status == JobStatus.InProgress, "Job not in progress");
        require(bytes(_reason).length > 0, "Reason cannot be empty");
        require(bytes(_evidenceHash).length > 0, "Evidence hash cannot be empty");

        // Check if there's already an active dispute
        uint256[] memory jobDisputes = disputesByJob[_jobId];
        for (uint256 i = 0; i < jobDisputes.length; i++) {
            if (disputes[jobDisputes[i]].status == DisputeStatus.Open) {
                revert("Active dispute exists");
            }
        }

        _incrementDisputeIds();
        uint256 newDisputeId = _getCurrentDisputeId();

        disputes[newDisputeId] = Dispute({
            disputeId: newDisputeId,
            jobId: _jobId,
            initiator: msg.sender,
            reason: _reason,
            evidenceHash: _evidenceHash,
            status: DisputeStatus.Open,
            resolution: "",
            createdAt: block.timestamp,
            resolvedAt: 0
        });

        disputesByJob[_jobId].push(newDisputeId);
        job.status = JobStatus.Disputed;

        emit DisputeRaised(newDisputeId, _jobId, msg.sender);
    }

    /**
     * @dev Resolve a dispute (admin only)
     * @param _disputeId Dispute ID
     * @param _resolution Resolution details
     * @param _refundToClient Percentage of remaining funds to refund to client (0-100)
     */
    function resolveDispute(
        uint256 _disputeId,
        string memory _resolution,
        uint8 _refundToClient
    ) external virtual onlyOwner validDisputeId(_disputeId) whenNotPaused {
        require(_refundToClient <= 100, "Invalid refund percentage");
        require(bytes(_resolution).length > 0, "Resolution cannot be empty");

        Dispute storage dispute = disputes[_disputeId];
        require(dispute.status == DisputeStatus.Open, "Dispute not open");

        Job storage job = jobs[dispute.jobId];
        uint256[] memory jobMilestoneIds = jobMilestones[dispute.jobId];

        // Calculate total remaining funds
        uint256 remainingFunds = 0;
        for (uint256 i = 0; i < jobMilestoneIds.length; i++) {
            Milestone memory milestone = milestones[jobMilestoneIds[i]];
            if (milestone.status != MilestoneStatus.Approved) {
                remainingFunds += milestone.amount;
            }
        }

        if (remainingFunds > 0) {
            // Calculate amounts
            uint256 clientRefund = (remainingFunds * _refundToClient) / 100;
            uint256 freelancerPayment = remainingFunds - clientRefund;

            // Process payments
            if (clientRefund > 0) {
                payable(job.client).transfer(clientRefund);
            }
            if (freelancerPayment > 0) {
                payable(job.assignedFreelancer).transfer(freelancerPayment);
            }
        }

        // Update dispute and job status
        dispute.status = DisputeStatus.Resolved;
        dispute.resolution = _resolution;
        dispute.resolvedAt = block.timestamp;
        job.status = JobStatus.Completed;

        emit DisputeResolved(_disputeId, dispute.jobId, _refundToClient);
    }

    /**
     * @dev Get dispute details
     * @param _disputeId Dispute ID
     * @return Dispute data
     */
    function getDispute(uint256 _disputeId) external view virtual returns (Dispute memory) {
        require(_disputeId > 0 && _disputeId <= _getCurrentDisputeId(), "Invalid dispute ID");
        return disputes[_disputeId];
    }

    /**
     * @dev Get disputes for a job
     * @param _jobId Job ID
     * @return Array of dispute IDs
     */
    function getJobDisputes(uint256 _jobId) external view virtual returns (uint256[] memory) {
        return disputesByJob[_jobId];
    }

    /**
     * @dev Batch get multiple disputes
     * @param disputeIds Array of dispute IDs
     * @return Array of dispute data
     */
    function getMultipleDisputes(uint256[] memory disputeIds) external view virtual returns (Dispute[] memory) {
        Dispute[] memory disputesData = new Dispute[](disputeIds.length);
        
        for (uint256 i = 0; i < disputeIds.length; i++) {
            if (disputeIds[i] > 0 && disputeIds[i] <= _getCurrentDisputeId()) {
                disputesData[i] = disputes[disputeIds[i]];
            }
        }
        
        return disputesData;
    }
}
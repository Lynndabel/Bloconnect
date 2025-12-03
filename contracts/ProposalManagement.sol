// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./JobManagement.sol";

/**
 * @title ProposalManagement
 * @dev Handles proposal creation and management for jobs
 */
abstract contract ProposalManagement is FreelanceBase {

    /**
     * @dev Submit a proposal for a job
     * @param _jobId Job ID to propose for
     * @param _coverLetterHash IPFS hash of cover letter
     * @param _proposedBudget Proposed budget in wei
     * @param _estimatedDays Estimated days to complete
     */
    function submitProposal(
        uint256 _jobId,
        string memory _coverLetterHash,
        uint256 _proposedBudget,
        uint256 _estimatedDays
    ) external virtual onlyRegisteredUser whenNotPaused validJobId(_jobId) {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.Open, "Job not open for proposals");
        require(job.client != msg.sender, "Cannot propose to own job");
        require(_proposedBudget > 0, "Budget must be greater than 0");
        require(_estimatedDays > 0, "Estimated days must be greater than 0");
        require(bytes(_coverLetterHash).length > 0, "Cover letter hash cannot be empty");

        // Check if freelancer already has a proposal for this job
        uint256[] memory userProposalIds = userProposals[msg.sender];
        for (uint256 i = 0; i < userProposalIds.length; i++) {
            if (proposals[userProposalIds[i]].jobId == _jobId) {
                revert("Already submitted proposal for this job");
            }
        }

        _incrementProposalIds();
        uint256 newProposalId = _getCurrentProposalId();

        proposals[newProposalId] = Proposal({
            proposalId: newProposalId,
            jobId: _jobId,
            freelancer: msg.sender,
            coverLetterHash: _coverLetterHash,
            proposedBudget: _proposedBudget,
            estimatedDays: _estimatedDays,
            status: ProposalStatus.Pending,
            createdAt: block.timestamp
        });

        jobProposals[_jobId].push(newProposalId);
        userProposals[msg.sender].push(newProposalId);

        emit ProposalSubmitted(newProposalId, _jobId, msg.sender, _proposedBudget);
    }

    /**
     * @dev Accept a proposal (only job client)
     * @param _proposalId Proposal ID to accept
     */
    function acceptProposal(uint256 _proposalId) external virtual validProposalId(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        Job storage job = jobs[proposal.jobId];

        require(msg.sender == job.client, "Only job client can accept proposals");
        require(job.status == JobStatus.Open, "Job not open");
        require(proposal.status == ProposalStatus.Pending, "Proposal not pending");

        // Update job status and assign freelancer
        job.status = JobStatus.InProgress;
        job.assignedFreelancer = proposal.freelancer;

        // Update proposal status
        proposal.status = ProposalStatus.Accepted;

        // Reject all other proposals
        uint256[] memory otherProposals = jobProposals[proposal.jobId];
        for (uint256 i = 0; i < otherProposals.length; i++) {
            if (otherProposals[i] != _proposalId) {
                proposals[otherProposals[i]].status = ProposalStatus.Rejected;
            }
        }

        emit ProposalAccepted(_proposalId, proposal.jobId, proposal.freelancer);
    }

    /**
     * @dev Withdraw a proposal (only proposal creator, only if pending)
     * @param _proposalId Proposal ID to withdraw
     */
    function withdrawProposal(uint256 _proposalId) external virtual validProposalId(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(msg.sender == proposal.freelancer, "Only proposal creator can withdraw");
        require(proposal.status == ProposalStatus.Pending, "Can only withdraw pending proposals");

        proposal.status = ProposalStatus.Withdrawn;
        emit ProposalWithdrawn(_proposalId, proposal.jobId, msg.sender);
    }

    /**
     * @dev Get proposals for a job
     * @param _jobId Job ID
     * @return Array of proposal IDs
     */
    function getJobProposals(uint256 _jobId) external view virtual returns (uint256[] memory) {
        return jobProposals[_jobId];
    }



    /**
     * @dev Batch get multiple proposals
     * @param proposalIds Array of proposal IDs
     * @return Array of proposal data
     */
    function getMultipleProposals(uint256[] memory proposalIds) external view virtual returns (Proposal[] memory) {
        Proposal[] memory proposalsData = new Proposal[](proposalIds.length);
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (proposalIds[i] > 0 && proposalIds[i] <= _getCurrentProposalId()) {
                proposalsData[i] = proposals[proposalIds[i]];
            }
        }
        
        return proposalsData;
    }
}
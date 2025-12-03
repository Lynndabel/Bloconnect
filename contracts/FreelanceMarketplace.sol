// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DisputeManagement.sol";

/**
 * @title FreelanceMarketplace
 * @dev Main contract for decentralized freelance platform
 * Inherits all functionality from modular contracts
 */
contract FreelanceMarketplace is
    UserManagement,
    JobManagement,
    ProposalManagement,
    MilestoneManagement,
    DisputeManagement
{

    constructor() initializer {
        __FreelanceBase_init();
    }

    /**
     * @dev Get current counters
     */
    function getCounters() external view returns (uint256, uint256, uint256, uint256) {
        return (_getCurrentJobId(), _getCurrentProposalId(), _getCurrentMilestoneId(), _getCurrentDisputeId());
    }

    /**
     * @dev Get platform statistics
     */
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
        uint256 totalJobs_ = _getCurrentJobId();
        
        for (uint256 i = 1; i <= totalJobs_; i++) {
            if (jobs[i].status == JobStatus.Open || jobs[i].status == JobStatus.InProgress) {
                activeJobCount++;
            }
        }

        // Calculate total value locked in escrow
        uint256 totalLocked = 0;
        uint256 totalMilestones_ = _getCurrentMilestoneId();
        
        for (uint256 i = 1; i <= totalMilestones_; i++) {
            totalLocked += escrowBalances[i];
        }

        return (
            totalJobs_,
            _getCurrentProposalId(),
            totalMilestones_,
            _getCurrentDisputeId(),
            activeJobCount,
            totalLocked,
            address(this).balance - totalLocked 
        );
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
}
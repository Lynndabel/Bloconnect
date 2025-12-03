// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./UserManagement.sol";

/**
 * @title JobManagement
 * @dev Handles job posting and basic job operations
 */
abstract contract JobManagement is FreelanceBase {

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
    ) external virtual onlyRegisteredUser whenNotPaused {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_descriptionHash).length > 0, "Description hash cannot be empty");
        require(_budget > 0, "Budget must be greater than 0");
        require(_deadline > block.timestamp, "Deadline must be in the future");

        _incrementJobIds();
        uint256 newJobId = _getCurrentJobId();

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

        _activeJobCount++;

        emit JobPosted(newJobId, msg.sender, _budget);
    }

    /**
     * @dev Cancel a job (only client, only if no proposals accepted)
     * @param _jobId Job ID to cancel
     */
    function cancelJob(uint256 _jobId) external virtual onlyJobClient(_jobId) validJobId(_jobId) {
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.Open, "Can only cancel open jobs");
        
        job.status = JobStatus.Cancelled;
        _activeJobCount--;
        emit JobPosted(_jobId, msg.sender, 0); // Emit with 0 budget to indicate cancellation
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
        _activeJobCount--;
    }

    /**
     * @dev Get active (open) jobs with pagination
     * @param _offset Starting index
     * @param _limit Number of jobs to return
     * @return Array of job IDs that are open
     */
    function getActiveJobs(uint256 _offset, uint256 _limit) external view returns (uint256[] memory) {
        uint256 totalJobs = _getCurrentJobId();
        uint256 count = 0;
        
        // First pass: count active jobs
        for (uint256 i = 1; i <= totalJobs; i++) {
            if (jobs[i].status == JobStatus.Open) {
                count++;
            }
        }
        
        // Calculate actual limit based on offset
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

    /**
     * @dev Batch get multiple jobs
     * @param jobIds Array of job IDs
     * @return Array of job data
     */
    function getMultipleJobs(uint256[] memory jobIds) external view virtual returns (Job[] memory) {
        Job[] memory jobsData = new Job[](jobIds.length);
        
        for (uint256 i = 0; i < jobIds.length; i++) {
            if (jobIds[i] > 0 && jobIds[i] <= _getCurrentJobId()) {
                jobsData[i] = jobs[jobIds[i]];
            }
        }
        
        return jobsData;
    }

    /**
     * @dev Get job milestones
     * @param _jobId Job ID
     * @return Array of milestone IDs
     */
    function getJobMilestones(uint256 _jobId) external view returns (uint256[] memory) {
        return jobMilestones[_jobId];
    }
}
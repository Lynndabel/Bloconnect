// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FreelanceBase.sol";

/**
 * @title UserManagement
 * @dev Handles user registration and profile management
 */
abstract contract UserManagement is FreelanceBase {

    event ReputationUpdated(address indexed user, uint256 newReputation);

    /**
     * @dev Register a new user
     * @param _profileHash IPFS hash containing user profile data
     */
    function registerUser(string memory _profileHash) external virtual {
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
    function updateProfile(string memory _profileHash) external virtual onlyRegisteredUser {
        require(bytes(_profileHash).length > 0, "Profile hash cannot be empty");
        users[msg.sender].profileHash = _profileHash;
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
     * @dev Internal function to update user's job stats
     * @param _user The user to update
     * @param _amountEarned The amount earned from the milestone/job
     * @param _jobCompleted A flag to indicate if a job was completed
     */
    function _updateUserStats(address _user, uint256 _amountEarned, bool _jobCompleted) internal {
        User storage user = users[_user];
        require(user.isActive, "User is not active");

        user.totalEarned += _amountEarned;
        if (_jobCompleted) {
            user.totalJobsCompleted++;
        }
    }

    /**
     * @dev Check if user is registered
     * @param _user User address to check
     * @return True if user is registered and active
     */
    function isUserRegistered(address _user) external view virtual returns (bool) {
        return users[_user].isActive;
    }

    /**
     * @dev Get user statistics
     */
    function getUserStats(address _user) external view virtual returns (
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
    function getUserProposals(address _user) external view virtual returns (uint256[] memory) {
        return userProposals[_user];
    }
}
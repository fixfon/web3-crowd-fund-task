// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// We are importing the OpenZeppelin ERC20 contract to use 1 token in our campaign contract
import "./IERC20.sol";

contract CrowdFund {
    // Campaign struct to store the campaign details
    struct Campaign {
        address creator;
        uint256 goal;
        uint32 startAt;
        uint32 endAt;
        uint256 totalContribution;
        bool claimed;
    }

    // Event list to be emitted after every function call.
    event LaunchCampaign(
        uint256 id,
        address indexed creator,
        uint256 goal,
        uint32 startAt,
        uint32 endAt
    );

    event CancelCampaign(uint256 id);

    event ContributeToCampaign(
        uint256 indexed id,
        address indexed contributor,
        uint256 amount
    );

    event WithdrawFromCampaign(
        uint256 indexed id,
        address indexed contributor,
        uint256 amount
    );

    event ClaimFunds(uint256 indexed id, uint256 amount);

    event Refund(
        uint256 indexed id,
        address indexed contributor,
        uint256 amount
    );

    // We are storing token address in a variable to use it in the contract
    IERC20 public immutable token;
    uint256 public campaignId;
    // We are storing all the campaigns in a mapping
    mapping(uint256 => Campaign) public campaignList;
    // We are storing all the contributions in a nested mapping with campaign ids.
    mapping(uint256 => mapping(address => uint256)) public contributionList;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function launchCampaign(
        uint256 _goal,
        uint32 _startAt,
        uint32 _endAt
    ) external {
        // Variable check for inputs
        require(_startAt >= block.timestamp, "startAt must be in the future");
        require(_endAt >= _startAt, "endAt must be after startAt");
        require(_endAt <= block.timestamp + 90 days, "Max endAt is 90 days");
        require(_goal > 0, "Goal must be greater than 0");

        // Incrase campaign number and create campaign in campaignList
        campaignId += 1;
        campaignList[campaignId] = Campaign({
            creator: msg.sender,
            goal: _goal,
            startAt: _startAt,
            endAt: _endAt,
            totalContribution: 0,
            claimed: false
        });

        emit LaunchCampaign(campaignId, msg.sender, _goal, _startAt, _endAt);
    }

    function cancelCampaign(uint256 _id) external {
        // We are storing the specific campaign in memory since we are not going to change the campaignList
        Campaign memory campaign = campaignList[_id];
        require(campaign.creator == msg.sender, "Only creator can cancel");
        require(block.timestamp < campaign.startAt, "Campaign already started");

        delete campaignList[_id];
        emit CancelCampaign(_id);
    }

    function contributeToCampaign(uint256 _id, uint256 _amount) external {
        // We are storing the specific campaign in storage because we are going to change the total amount.
        Campaign storage campaign = campaignList[_id];
        require(block.timestamp >= campaign.startAt, "Campaign not started");
        require(block.timestamp <= campaign.endAt, "Campaign already ended");

        campaign.totalContribution += _amount;
        contributionList[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit ContributeToCampaign(_id, msg.sender, _amount);
    }

    function withdrawFromCampaign(uint256 _id, uint256 _amount) external {
        Campaign storage campaign = campaignList[_id];
        require(block.timestamp >= campaign.startAt, "Campaign not started");
        require(block.timestamp <= campaign.endAt, "Campaign already ended");

        uint256 callerContribution = contributionList[_id][msg.sender];
        require(callerContribution >= _amount, "Not enough contribution");

        contributionList[_id][msg.sender] -= _amount;
        campaign.totalContribution -= _amount;
        token.transfer(msg.sender, _amount);

        emit WithdrawFromCampaign(_id, msg.sender, _amount);
    }

    function claimFunds(uint256 _id) external {
        Campaign storage campaign = campaignList[_id];
        require(msg.sender == campaign.creator, "Only creator can claim.");
        require(block.timestamp > campaign.endAt, "Campaign not ended yet.");
        require(
            campaign.totalContribution >= campaign.goal,
            "Goal not reached. That is why you can not withdraw contributions."
        );
        require(!campaign.claimed, "Funds already claimed.");

        campaign.claimed = true;
        token.transfer(msg.sender, campaign.totalContribution);

        emit ClaimFunds(_id, campaign.totalContribution);
    }

    function getRefund(uint256 _id) external {
        // If a campaign was not successful, we are going to refund the contributions to the contributors.
        Campaign storage campaign = campaignList[_id];
        require(block.timestamp > campaign.endAt, "Campaign not ended yet.");
        require(
            campaign.totalContribution < campaign.goal,
            "Goal reached. That is why you can not get refund."
        );

        uint256 callerContribution = contributionList[_id][msg.sender];
        require(callerContribution > 0, "No contribution to refund.");

        contributionList[_id][msg.sender] = 0;
        campaign.totalContribution -= callerContribution;
        token.transfer(msg.sender, callerContribution);

        emit Refund(_id, msg.sender, callerContribution);
    }
}

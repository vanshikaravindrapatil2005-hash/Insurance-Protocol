
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract InsuranceProtocol {
    // State variables
    address public owner;
    uint256 public totalPremiums;
    uint256 public totalClaims;
    uint256 public nextPolicyId;
    uint256 public nextClaimId;
    
    // Structs
    struct Policy {
        uint256 policyId;
        address policyholder;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        string policyType; // "auto", "health", "property", etc.
    }
    
    struct Claim {
        uint256 claimId;
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string description;
        uint256 submissionTime;
        ClaimStatus status;
        uint256 payoutAmount;
    }
    
    enum ClaimStatus {
        Pending,
        Approved,
        Rejected,
        Paid
    }
    
    // Mappings
    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    mapping(address => uint256[]) public userClaims;
    
    // Events
    event PolicyPurchased(uint256 indexed policyId, address indexed policyholder, uint256 premiumAmount, uint256 coverageAmount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, address indexed claimant, uint256 claimAmount);
    event ClaimProcessed(uint256 indexed claimId, ClaimStatus status, uint256 payoutAmount);
    event PremiumCollected(address indexed policyholder, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validPolicy(uint256 _policyId) {
        require(_policyId < nextPolicyId, "Invalid policy ID");
        require(policies[_policyId].isActive, "Policy is not active");
        _;
    }
    
    modifier onlyPolicyholder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "Only policyholder can perform this action");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        nextPolicyId = 1;
        nextClaimId = 1;
    }
    
    // Core Function 1: Purchase Insurance Policy
    function purchasePolicy(
        uint256 _coverageAmount,
        uint256 _durationInDays,
        string memory _policyType
    ) external payable returns (uint256) {
        require(msg.value > 0, "Premium amount must be greater than 0");
        require(_coverageAmount > 0, "Coverage amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(_coverageAmount >= msg.value * 10, "Coverage amount too low for premium");
        
        uint256 policyId = nextPolicyId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (_durationInDays * 1 days);
        
        policies[policyId] = Policy({
            policyId: policyId,
            policyholder: msg.sender,
            premiumAmount: msg.value,
            coverageAmount: _coverageAmount,
            startTime: startTime,
            endTime: endTime,
            isActive: true,
            policyType: _policyType
        });
        
        userPolicies[msg.sender].push(policyId);
        totalPremiums += msg.value;
        
        emit PolicyPurchased(policyId, msg.sender, msg.value, _coverageAmount);
        emit PremiumCollected(msg.sender, msg.value);
        
        return policyId;
    }
    
    // Core Function 2: Submit Insurance Claim
    function submitClaim(
        uint256 _policyId,
        uint256 _claimAmount,
        string memory _description
    ) external validPolicy(_policyId) onlyPolicyholder(_policyId) returns (uint256) {
        Policy storage policy = policies[_policyId];
        
        require(block.timestamp >= policy.startTime, "Policy has not started yet");
        require(block.timestamp <= policy.endTime, "Policy has expired");
        require(_claimAmount > 0, "Claim amount must be greater than 0");
        require(_claimAmount <= policy.coverageAmount, "Claim amount exceeds coverage");
        require(bytes(_description).length > 0, "Claim description is required");
        
        uint256 claimId = nextClaimId++;
        
        claims[claimId] = Claim({
            claimId: claimId,
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            description: _description,
            submissionTime: block.timestamp,
            status: ClaimStatus.Pending,
            payoutAmount: 0
        });
        
        userClaims[msg.sender].push(claimId);
        
        emit ClaimSubmitted(claimId, _policyId, msg.sender, _claimAmount);
        
        return claimId;
    }
    
    // Core Function 3: Process Claims (Admin function)
    function processClaim(
        uint256 _claimId,
        bool _approve,
        uint256 _payoutAmount
    ) external onlyOwner {
        require(_claimId < nextClaimId, "Invalid claim ID");
        
        Claim storage claim = claims[_claimId];
        require(claim.status == ClaimStatus.Pending, "Claim already processed");
        
        if (_approve) {
            require(_payoutAmount > 0, "Payout amount must be greater than 0");
            require(_payoutAmount <= claim.claimAmount, "Payout exceeds claim amount");
            require(address(this).balance >= _payoutAmount, "Insufficient contract balance");
            
            claim.status = ClaimStatus.Approved;
            claim.payoutAmount = _payoutAmount;
            
            // Transfer payout to claimant
            payable(claim.claimant).transfer(_payoutAmount);
            totalClaims += _payoutAmount;
            
            claim.status = ClaimStatus.Paid;
        } else {
            claim.status = ClaimStatus.Rejected;
        }
        
        emit ClaimProcessed(_claimId, claim.status, claim.payoutAmount);
    }
    
    // View functions
    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory) {
        require(_policyId < nextPolicyId, "Invalid policy ID");
        return policies[_policyId];
    }
    
    function getClaimDetails(uint256 _claimId) external view returns (Claim memory) {
        require(_claimId < nextClaimId, "Invalid claim ID");
        return claims[_claimId];
    }
    
    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }
    
    function getUserClaims(address _user) external view returns (uint256[] memory) {
        return userClaims[_user];
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function isPolicyValid(uint256 _policyId) external view returns (bool) {
        if (_policyId >= nextPolicyId) return false;
        Policy storage policy = policies[_policyId];
        return policy.isActive && block.timestamp >= policy.startTime && block.timestamp <= policy.endTime;
    }
    
    // Emergency functions
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    function deactivatePolicy(uint256 _policyId) external onlyOwner {
        require(_policyId < nextPolicyId, "Invalid policy ID");
        policies[_policyId].isActive = false;
    }
    
    // Fallback function to receive Ether
    receive() external payable {
        totalPremiums += msg.value;
    }
}

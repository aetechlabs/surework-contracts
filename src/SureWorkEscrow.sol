// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SureWorkEscrow
 * @dev Decentralized escrow contract for securing freelance gig payments
 * @notice This contract holds stablecoins in escrow until work is completed
 */
contract SureWorkEscrow is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");

    enum GigStatus {
        Created,
        Funded,
        Submitted,
        Completed,
        Disputed,
        Cancelled,
        Refunded
    }

    struct Gig {
        uint256 gigId;
        address client;
        address freelancer;
        address paymentToken; // Stablecoin address (USDC, USDT, etc.)
        uint256 amount;
        uint256 deadline;
        GigStatus status;
        string metadataURI; // IPFS hash or API endpoint for gig details
        uint256 createdAt;
        uint256 fundedAt;
        uint256 completedAt;
    }

    // State variables
    uint256 private gigCounter;
    mapping(uint256 => Gig) public gigs;
    mapping(address => uint256[]) public clientGigs;
    mapping(address => uint256[]) public freelancerGigs;

    // Platform fee (in basis points, 100 = 1%)
    uint256 public platformFeePercent = 250; // 2.5%
    address public feeCollector;
    uint256 public totalFeesCollected;

    // Events
    event GigCreated(
        uint256 indexed gigId,
        address indexed client,
        address indexed freelancer,
        uint256 amount,
        address paymentToken
    );
    event GigFunded(uint256 indexed gigId, uint256 amount);
    event WorkSubmitted(uint256 indexed gigId, address indexed freelancer);
    event GigCompleted(uint256 indexed gigId, uint256 amountPaid, uint256 fee);
    event GigDisputed(uint256 indexed gigId, address indexed initiator);
    event DisputeResolved(
        uint256 indexed gigId,
        address winner,
        uint256 amount
    );
    event GigCancelled(uint256 indexed gigId);
    event PlatformFeeUpdated(uint256 newFeePercent);

    constructor(address _feeCollector) {
        require(_feeCollector != address(0), "Invalid fee collector");
        feeCollector = _feeCollector;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ARBITER_ROLE, msg.sender);
    }

    /**
     * @dev Create a new gig escrow agreement
     * @param _freelancer Address of the freelancer
     * @param _paymentToken Stablecoin address for payment
     * @param _amount Payment amount in token's smallest unit
     * @param _deadline Unix timestamp for gig completion
     * @param _metadataURI Off-chain metadata reference
     */
    function createGig(
        address _freelancer,
        address _paymentToken,
        uint256 _amount,
        uint256 _deadline,
        string memory _metadataURI
    ) external returns (uint256) {
        require(_freelancer != address(0), "Invalid freelancer address");
        require(_freelancer != msg.sender, "Client cannot be freelancer");
        require(_amount > 0, "Amount must be greater than 0");
        require(_deadline > block.timestamp, "Deadline must be in future");

        gigCounter++;
        uint256 gigId = gigCounter;

        gigs[gigId] = Gig({
            gigId: gigId,
            client: msg.sender,
            freelancer: _freelancer,
            paymentToken: _paymentToken,
            amount: _amount,
            deadline: _deadline,
            status: GigStatus.Created,
            metadataURI: _metadataURI,
            createdAt: block.timestamp,
            fundedAt: 0,
            completedAt: 0
        });

        clientGigs[msg.sender].push(gigId);
        freelancerGigs[_freelancer].push(gigId);

        emit GigCreated(gigId, msg.sender, _freelancer, _amount, _paymentToken);
        return gigId;
    }

    /**
     * @dev Fund an existing gig with tokens
     * @param _gigId The ID of the gig to fund
     */
    function fundGig(uint256 _gigId) external nonReentrant {
        Gig storage gig = gigs[_gigId];
        require(gig.gigId != 0, "Gig does not exist");
        require(gig.client == msg.sender, "Only client can fund");
        require(gig.status == GigStatus.Created, "Gig already funded");

        IERC20 token = IERC20(gig.paymentToken);
        require(
            token.balanceOf(msg.sender) >= gig.amount,
            "Insufficient balance"
        );

        gig.status = GigStatus.Funded;
        gig.fundedAt = block.timestamp;

        token.safeTransferFrom(msg.sender, address(this), gig.amount);

        emit GigFunded(_gigId, gig.amount);
    }

    /**
     * @dev Freelancer marks work as submitted
     * @param _gigId The ID of the gig
     */
    function submitWork(uint256 _gigId) external {
        Gig storage gig = gigs[_gigId];
        require(gig.gigId != 0, "Gig does not exist");
        require(gig.freelancer == msg.sender, "Only freelancer can submit");
        require(gig.status == GigStatus.Funded, "Gig not funded");

        gig.status = GigStatus.Submitted;

        emit WorkSubmitted(_gigId, msg.sender);
    }

    /**
     * @dev Client approves work and releases payment to freelancer
     * @param _gigId The ID of the gig to approve
     */
    function approveWork(uint256 _gigId) external nonReentrant {
        Gig storage gig = gigs[_gigId];
        require(gig.gigId != 0, "Gig does not exist");
        require(gig.client == msg.sender, "Only client can approve");
        require(
            gig.status == GigStatus.Submitted || gig.status == GigStatus.Funded,
            "Invalid gig status"
        );

        gig.status = GigStatus.Completed;
        gig.completedAt = block.timestamp;

        _releaseFunds(_gigId);
    }

    /**
     * @dev Internal function to calculate and release funds
     * @param _gigId The ID of the gig
     */
    function _releaseFunds(uint256 _gigId) private {
        Gig storage gig = gigs[_gigId];
        IERC20 token = IERC20(gig.paymentToken);

        uint256 platformFee = (gig.amount * platformFeePercent) / 10000;
        uint256 freelancerPayment = gig.amount - platformFee;

        totalFeesCollected += platformFee;

        token.safeTransfer(gig.freelancer, freelancerPayment);
        if (platformFee > 0) {
            token.safeTransfer(feeCollector, platformFee);
        }

        emit GigCompleted(_gigId, freelancerPayment, platformFee);
    }

    /**
     * @dev Raise a dispute for a gig
     * @param _gigId The ID of the gig to dispute
     */
    function raiseDispute(uint256 _gigId) external {
        Gig storage gig = gigs[_gigId];
        require(gig.gigId != 0, "Gig does not exist");
        require(
            msg.sender == gig.client || msg.sender == gig.freelancer,
            "Not authorized"
        );
        require(
            gig.status == GigStatus.Funded ||
                gig.status == GigStatus.Submitted,
            "Cannot dispute at this stage"
        );

        gig.status = GigStatus.Disputed;

        emit GigDisputed(_gigId, msg.sender);
    }

    /**
     * @dev Admin/Arbiter resolves a dispute
     * @param _gigId The ID of the disputed gig
     * @param _winner Address to receive the funds (client or freelancer)
     */
    function resolveDispute(uint256 _gigId, address _winner)
        external
        onlyRole(ARBITER_ROLE)
        nonReentrant
    {
        Gig storage gig = gigs[_gigId];
        require(gig.gigId != 0, "Gig does not exist");
        require(gig.status == GigStatus.Disputed, "Gig not disputed");
        require(
            _winner == gig.client || _winner == gig.freelancer,
            "Invalid winner"
        );

        IERC20 token = IERC20(gig.paymentToken);

        if (_winner == gig.freelancer) {
            gig.status = GigStatus.Completed;
            gig.completedAt = block.timestamp;
            _releaseFunds(_gigId);
        } else {
            // Refund client
            gig.status = GigStatus.Refunded;
            token.safeTransfer(gig.client, gig.amount);
        }

        emit DisputeResolved(_gigId, _winner, gig.amount);
    }

    /**
     * @dev Cancel an unfunded gig
     * @param _gigId The ID of the gig to cancel
     */
    function cancelGig(uint256 _gigId) external {
        Gig storage gig = gigs[_gigId];
        require(gig.gigId != 0, "Gig does not exist");
        require(gig.client == msg.sender, "Only client can cancel");
        require(gig.status == GigStatus.Created, "Can only cancel unfunded gigs");

        gig.status = GigStatus.Cancelled;

        emit GigCancelled(_gigId);
    }

    /**
     * @dev Update platform fee percentage
     * @param _newFeePercent New fee in basis points
     */
    function setPlatformFee(uint256 _newFeePercent)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_newFeePercent <= 1000, "Fee cannot exceed 10%");
        platformFeePercent = _newFeePercent;
        emit PlatformFeeUpdated(_newFeePercent);
    }

    /**
     * @dev Update fee collector address
     * @param _newFeeCollector New fee collector address
     */
    function setFeeCollector(address _newFeeCollector)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_newFeeCollector != address(0), "Invalid address");
        feeCollector = _newFeeCollector;
    }

    /**
     * @dev Get gig details
     * @param _gigId The ID of the gig
     */
    function getGig(uint256 _gigId) external view returns (Gig memory) {
        return gigs[_gigId];
    }

    /**
     * @dev Get all gigs for a client
     * @param _client Client address
     */
    function getClientGigs(address _client)
        external
        view
        returns (uint256[] memory)
    {
        return clientGigs[_client];
    }

    /**
     * @dev Get all gigs for a freelancer
     * @param _freelancer Freelancer address
     */
    function getFreelancerGigs(address _freelancer)
        external
        view
        returns (uint256[] memory)
    {
        return freelancerGigs[_freelancer];
    }
}

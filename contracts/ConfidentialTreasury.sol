// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint64, externalEuint64 } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/// @title Confidential DAO Treasury — Private Governance Spending with FHEVM
/// @notice DAO treasury balance and spending amounts are encrypted (euint64).
/// @dev Votes are public for simplicity; spending amounts remain confidential.
contract ConfidentialTreasury is SepoliaConfig {
    address public owner;
    uint256 public quorum; // minimal YES votes required
    euint64 private _treasury; // encrypted treasury balance

    struct Proposal {
        address recipient;
        euint64 encAmount;       // encrypted requested spend
        uint256 yesVotes;
        uint256 deadline;
        bool executed;
        euint64 executedEnc;     // encrypted actually executed (0 on fail-closed)
    }

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public voted;
    mapping(address => bool) public isMember;

    event MemberAdded(address member);
    event MemberRemoved(address member);
    event Deposit(); // amount hidden
    event ProposalCreated(uint256 indexed id, address indexed recipient);
    event Voted(uint256 indexed id, address indexed voter);
    event Executed(uint256 indexed id, address indexed recipient); // amount hidden

    error NotOwner();
    error NotMember();
    error PastDeadline();
    error AlreadyVoted();
    error AlreadyExecuted();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    modifier onlyMember() {
        if (!isMember[msg.sender]) revert NotMember();
        _;
    }

    constructor(address[] memory initialMembers, uint256 minQuorum) {
        owner = msg.sender;
        quorum = minQuorum;
        for (uint256 i = 0; i < initialMembers.length; i++) {
            isMember[initialMembers[i]] = true;
            emit MemberAdded(initialMembers[i]);
        }
        // By default allow the owner to decrypt the treasury after updates
        FHE.allowThis(_treasury);
        FHE.allow(_treasury, owner);
    }

    /* ----------------------- DAO membership (simple) ----------------------- */

    function addMember(address m) external onlyOwner {
        isMember[m] = true;
        emit MemberAdded(m);
    }

    function removeMember(address m) external onlyOwner {
        isMember[m] = false;
        emit MemberRemoved(m);
    }

    /* -------------------------- Treasury operations ------------------------ */

    /// @notice Increase treasury by an encrypted amount.
    function depositEncrypted(externalEuint64 encryptedAmt, bytes calldata inputProof) external onlyOwner {
        euint64 amt = FHE.fromExternal(encryptedAmt, inputProof);
        _treasury = FHE.add(_treasury, amt);

        FHE.allowThis(_treasury);
        FHE.allow(_treasury, owner);

        emit Deposit();
    }

    /// @notice Read the encrypted treasury balance (only decryptable by owner).
    function getTreasury() external view returns (euint64) {
        return _treasury;
    }

    /* ---------------------------- Governance flow -------------------------- */

    /// @notice Create a spend proposal with an encrypted amount.
    function createProposal(
        address recipient,
        externalEuint64 encryptedAmt,
        bytes calldata inputProof,
        uint256 votingPeriodSec
    ) external onlyMember returns (uint256 id) {
        euint64 enc = FHE.fromExternal(encryptedAmt, inputProof);

        Proposal memory p;
        p.recipient = recipient;
        p.encAmount = enc;
        p.deadline = block.timestamp + votingPeriodSec;
        p.executed = false;

        proposals.push(p);
        id = proposals.length - 1;

        // Let the contract and the recipient read the encrypted amount
        FHE.allowThis(proposals[id].encAmount);
        FHE.allow(proposals[id].encAmount, recipient);

        emit ProposalCreated(id, recipient);
    }

    function voteYes(uint256 id) external onlyMember {
        Proposal storage p = proposals[id];
        if (block.timestamp > p.deadline) revert PastDeadline();
        if (voted[id][msg.sender]) revert AlreadyVoted();

        voted[id][msg.sender] = true;
        p.yesVotes += 1;

        emit Voted(id, msg.sender);
    }

    /// @notice Execute proposal if quorum reached. Fail-closed if amount > treasury.
    function execute(uint256 id) external {
        Proposal storage p = proposals[id];
        if (p.executed) revert AlreadyExecuted();
        if (block.timestamp <= p.deadline && p.yesVotes < quorum) revert PastDeadline(); // require quorum or after deadline

        // toSpend = encAmount if encAmount <= treasury else 0
        euint64 toSpend = FHE.select(FHE.le(p.encAmount, _treasury), p.encAmount, FHE.asEuint64(0));

        // update treasury
        _treasury = FHE.sub(_treasury, toSpend);

        // store encrypted executed amount
        p.executedEnc = toSpend;
        p.executed = true;

        // Access control — allow recipient & owner to decrypt executedEnc and treasury
        FHE.allowThis(_treasury);
        FHE.allow(_treasury, owner);

        FHE.allowThis(p.executedEnc);
        FHE.allow(p.executedEnc, p.recipient);
        FHE.allow(p.executedEnc, owner);

        emit Executed(id, p.recipient);
    }

    /// @notice Read encrypted executed amount for a proposal (recipient/owner can decrypt).
    function getExecutedAmount(uint256 id) external view returns (euint64) {
        return proposals[id].executedEnc;
    }

    /// @notice Read encrypted requested amount for a proposal (recipient can decrypt).
    function getRequestedAmount(uint256 id) external view returns (euint64) {
        return proposals[id].encAmount;
    }
}

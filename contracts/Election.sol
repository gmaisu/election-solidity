// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ElectionVote.sol";
import "./Whitelist.sol";

contract Election is WhitelistStorage {
    uint8 private round;
    uint256 private airdropPerPerson;
    uint256 private previousRoundAirdropPerPerson;

    mapping(uint8 => mapping(address => uint256)) public givenVotes; // round=>voter=>givenVotes
    mapping(address => uint256) public candidateVotes; // candidate=>receivedVotes

    mapping(address => uint8) public winners;
    mapping(uint8 => uint256) public missed;

    mapping(uint8 => uint256) public roundDurationDays;

    uint256 public communitySize;
    uint256 public winnersOfRound;

    uint256 private roundStartedAt;

    ElectionVote public voteToken;
    IERC20 public carrotickToken;

    event Winner(address candidate, uint8 round);
    event RoundFinished(uint8 round, uint256 missed);
    event Vote(address voter, address candidate, uint256 amount, uint8 round);

    constructor(address _carrotickToken, address _signer, address[] memory _winners) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(SIGNER_ROLE, _signer);

        round = 1;
        airdropPerPerson = 50_000;
        previousRoundAirdropPerPerson = airdropPerPerson;
        winnersOfRound = 0;
        communitySize = 0;
        roundStartedAt = block.timestamp;

        voteToken = new ElectionVote();
        carrotickToken = IERC20(_carrotickToken);

        roundDurationDays[1] = 7 days;
        roundDurationDays[2] = 7 days;
        roundDurationDays[3] = 30 days;
        roundDurationDays[4] = 30 days;
        roundDurationDays[5] = 60 days;
        roundDurationDays[6] = 60 days;
        roundDurationDays[7] = 80 days;
        roundDurationDays[8] = 100 days;
        roundDurationDays[9] = 300 days;
        roundDurationDays[10] = 360 days;

        for (uint i = 0; i < _winners.length; i++) {
            _addWinner(_winners[i]);
        }
    }

    function getRound() public view returns (uint8) {
        return round;
    }

    function getCandidateQuantity() public view returns (uint256) {
        return 2 ** round + missed[round - 1];
    }

    function getAirdropPerPerson() public view returns (uint256) {
        return airdropPerPerson;
    }

    function getMaxElectionVotes() public view returns (uint256) {
        return previousRoundAirdropPerPerson - getAirdropPerPerson();
    }

    function getRequiredVotesForCandidate() public view returns (uint256) {
        return (getMaxElectionVotes() * communitySize) / getCandidateQuantity();
    }

    function _getNextRoundAirdropPerPerson() internal view returns (uint256) {
        return (airdropPerPerson * 10) / 15;
    }

    function vote(address candidate, uint256 amount) external {
        _beforeVote();
        _vote(_msgSender(), candidate, amount);
    }

    function multipleVotes(address[] memory candidates, uint256[] memory amounts) external {
        _beforeVote();

        for (uint i = 0; i < candidates.length; i++) {
            _vote(_msgSender(), candidates[i], amounts[i]);
        }
    }

    function _vote(address voter, address candidate, uint256 amount) internal {
        require(givenVotes[round][voter] + amount <= getMaxElectionVotes(), "Voting limit exceeded for round");
        require(winners[candidate] == 0, "Candidate is already winner");
        require(whitelisted[candidate], "Candidate is not whitelisted");

        uint256 requiredVotes = getRequiredVotesForCandidate();
        if (candidateVotes[candidate] + amount > requiredVotes) {
            if (candidateVotes[candidate] >= requiredVotes) {
                amount = 0;
            } else {
                amount = requiredVotes - candidateVotes[candidate];
            }
        }
        if (amount > 0) {
            _calculateVotes(voter, candidate, amount);
        }
        if (candidateVotes[candidate] == requiredVotes) {
            _addWinner(candidate);
        }
    }

    function _calculateVotes(address voter, address candidate, uint256 amount) internal {
        voteToken.burn(voter, amount);
        carrotickToken.transfer(voter, amount);

        givenVotes[round][voter] += amount;
        candidateVotes[candidate] += amount;

        emit Vote(voter, candidate, amount, round);
    }

    function _addWinner(address account) internal {
        winners[account] = round;
        winnersOfRound += 1;

        voteToken.mint(account, getAirdropPerPerson());

        if (winnersOfRound == getCandidateQuantity()) {
            _updateRound();
        }

        emit Winner(account, winners[account]);
    }

    function _beforeVote() internal {
        if (block.timestamp >= roundStartedAt + roundDurationDays[round]) {
            _startNewRound();
        }

        require(winners[_msgSender()] > 0 && winners[_msgSender()] < round, "Sender is not allowed to vote");
    }

    function _updateAirdropPerPerson() internal {
        previousRoundAirdropPerPerson = airdropPerPerson;
        airdropPerPerson = (airdropPerPerson * 10) / 15;
    }

    function _updateRound() internal {
        uint8 currentRound = round;

        _updateAirdropPerPerson();
        communitySize += winnersOfRound;
        winnersOfRound = 0;
        roundStartedAt = block.timestamp;
        round = currentRound + 1;

        emit RoundFinished(currentRound, missed[currentRound]);
    }

    function _startNewRound() internal {
        missed[round] = getCandidateQuantity() - winnersOfRound;
        _updateRound();
    }

}

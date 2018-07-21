pragma solidity ^0.4.22;

import './RotoBasic.sol';

contract RotoManager is RotoBasic {
  
    constructor() public {
      owner = msg.sender;
      emergency = false;
      manager = this;
    }

    /**
        @dev - In the event that their submissions were successful, this function will return the tokens to the user, and distribute ether rewards were applicable
        @param _user The user's address, the ether the've won,
        @return - returns whether the Roto was sucessfully transferred
     */
    function releaseRoto(address _user, bytes32 _tournamentID, uint256 _etherReward) public onlyOwner stopInEmergency returns(bool successful){
        Tournament storage tournament = tournaments[_tournamentID];
        require(tournament.open==true);

        Stake storage user_stake = tournament.stakes[_user][_tournamentID];
        uint256 initial_stake = user_stake.amount;

        require(initial_stake > 0);
        require(user_stake.resolved == false);
        require(manager.balance > _etherReward);
        //Redistributes roto back to the user, and marks the stake as successful and completed
        user_stake.amount = 0;
        assert(token.releaseRoto(_user, initial_stake)); // calls the token contract releaseRoto function to handle the token accounting
        
        user_stake.resolved = true;
        user_stake.successful = true;

        if(_etherReward > 0) {
          _user.transfer(_etherReward);
        }

        emit StakeReleased(_tournamentID, _user, _etherReward, initial_stake);
        
        return true;
    }
    /**
        @dev - If the user did not stake ROTO, but they still had a successful submission, then RotoHive will reward the user with an amount of ROTO respective to their performance.
        @param _user address, which the ROTO will be sent to
        @param _rotoReward amount of ROTO that the user has won
        @return - a boolean value determining whether the operation was successful
    
     */
    function rewardRoto(address _user, bytes32 _tournamentID, uint256 _rotoReward) public onlyOwner stopInEmergency returns(bool successful) {
      Tournament storage tournament = tournaments[_tournamentID];
      require(tournament.open==true);

      Stake storage user_stake = tournament.stakes[_user][_tournamentID];
      uint256 initial_stake = user_stake.amount;
      
      require(initial_stake==0);
      require(user_stake.resolved == false);

      assert(token.rewardRoto(_user, _rotoReward));

      user_stake.resolved = true;
      user_stake.successful = true;

      emit SubmissionRewarded(_tournamentID, _user, _rotoReward);

      return true;
    }

    /**
        @dev - For unsuccessful submission, the Roto will initially sent back to the contract.
        @param _user address, the address of the user who's stake was unsuccessful
        @param _tournamentID 32byte hex, the tournament which the stake belongs to
        @return - whether the roto was successfully destroyed
     */
    function destroyRoto(address _user, bytes32 _tournamentID) public onlyOwner stopInEmergency returns(bool successful) {
        Tournament storage tournament = tournaments[_tournamentID];
        require(tournament.open==true);

        Stake storage user_stake = tournament.stakes[_user][_tournamentID];

        uint256 initial_stake = user_stake.amount;

        require(initial_stake > 0);
        require(user_stake.resolved == false);

        user_stake.amount = 0;
        user_stake.resolved = true;
        user_stake.successful = false;

        assert(token.destroyRoto(_user, initial_stake));

        emit StakeDestroyed(_tournamentID, _user, initial_stake);

        return true;
    }

    /**
        @dev - The public method which will allow user's to stake their Roto alongside their submissions
        @param _value the amount of Roto being staked, the id of that stake, and the id of the tournament
        @return - whether the staking request was successful
     */
    function stake(uint256 _value, bytes32 _tournamentID) public stopInEmergency returns(bool successful) {
        return _stake(msg.sender, _tournamentID, _value);
    }

    /**
        @dev - The internal method to process the request to stake Roto as a part of the Tournament Submission
        @param _staker the user who's staking roto, the ID of the tournament, the amount of roto the user's staking, the staking tag
        @return - whether the withdraw operation was successful
     */
    function _stake(address _staker, bytes32 _tournamentID, uint256 _value) internal returns(bool successful) {
        Tournament storage tournament = tournaments[_tournamentID];

        //The User can't submit after tournament closure and the tournament must have begun
        require((tournament.open==true));

        Stake storage user_stake = tournament.stakes[_staker][_tournamentID];
        
        require(user_stake.amount==0); // Users can only stake once
        require(_value>0); // Users must stake at least 1 ROTO
        require(_staker != roto && _staker != owner); //RotoHive can't stake in 
        
        //Users must have the necessary balances to submit their stake
        assert(token.canStake(_staker, _value));

        user_stake.amount = _value;
        assert(token.stakeRoto(_staker,_value));

        emit StakeProcessed(_staker, user_stake.amount, _tournamentID);

        return true;
    }

    /**
        @dev - Allows RotoHive to create this week's RotoHive Tournament
        @param _tournamentID 32byte hex, the ID which RotoHive uses to reference each tournament
        @param _etherPrize Eth, the total ether prize pool for the tournament
        @param _rotoPrize ROTO, the total ROTO prize pool for the tournament
        @return - whether the tournament was successfully created
     */
    function createTournament(bytes32 _tournamentID, uint256 _etherPrize, uint256 _rotoPrize) external payable onlyOwner returns(bool successful) {
        Tournament storage newTournament = tournaments[_tournamentID];
        require(newTournament.creationTime==0);
        
        newTournament.open = true;
        newTournament.etherPrize = _etherPrize;
        newTournament.rotoPrize = _rotoPrize;
        newTournament.creationTime = block.timestamp;

        emit TournamentCreated(_tournamentID, _etherPrize, _rotoPrize);

        return true;
    }

    /**
      @dev - closes the current tournament after the submission deadline has passed
      @param _tournamentID the tournament ID
      @return - returns whether the tournament was closed successfully
    */
    function closeTournament(bytes32 _tournamentID) external onlyOwner returns(bool successful) {
       Tournament storage tournament = tournaments[_tournamentID];
       require(tournament.open==true);

       tournament.open = false;

       emit TournamentClosed(_tournamentID);
       return true;
    }
}
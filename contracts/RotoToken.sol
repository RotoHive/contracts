pragma solidity ^0.4.22;

import "./StandardToken.sol";

contract RotoToken is StandardToken {

    string public constant name = "Roto"; // token name
    string public constant symbol = "ROTO"; // token symbol
    uint8 public constant decimals = 18; // token decimal

    uint256 public constant INITIAL_SUPPLY = 21000000 * (10 ** uint256(decimals));
    address owner;
    address roto = this;
    address manager;


  /**
   * @dev Constructor that gives msg.sender all of existing tokens.
   */

    modifier onlyOwner {
        require(msg.sender==owner);
        _;
    }

    modifier onlyManager {
      require(msg.sender==manager);
      _;
    }

    event ManagerChanged(address _contract);
    event RotoStaked(address _user, uint256 stake);
    event RotoReleased(address _user, uint256 stake);
    event RotoDestroyed(address _user, uint256 stake);
    event RotoRewarded(address _contract, address _user, uint256 reward);

    constructor() public {
        owner = msg.sender;
        totalSupply_ = INITIAL_SUPPLY;
        balances[roto] = INITIAL_SUPPLY;
        emit Transfer(0x0, roto, INITIAL_SUPPLY);
    }
    
    function() public payable {}

    
    /**
     *  @dev A function that can only be called by RotoHive, transfers Roto Tokens out of the contract.
        @param _to address, the address that the ROTO will be transferred to
        @param _value ROTO, amount to transfer
        @return - whether the Roto was transferred succesfully
     */
    function transferFromContract(address _to, uint256 _value) public onlyOwner returns(bool) {
        require(_to!=address(0));
        require(_value<=balances[roto]);

        balances[roto] = balances[roto].sub(_value);
        balances[_to] = balances[_to].add(_value);

        emit Transfer(roto, _to, _value);
        return true;
    }

    /**
        @dev updates the helper contract(which will manage the tournament) with the new version
        @param _contract address, the address of the manager contract
        @return - whether the contract was successfully set
    */
    function setManagerContract(address _contract) external onlyOwner returns(bool) {
      require(_contract!=address(0)&&_contract!=roto);
      manager = _contract;

      emit ManagerChanged(_contract);
      return true;
    }

    /**
        @dev - called by the manager contract to add back to the user their roto in the event that their submission was successful
        @param  _user address, the address of the user who submitted the rankings
        @param _value staked, the amount that the user staked alongside their submissions
        @return boolean value, whether the roto were successfully released
    */
    function releaseRoto(address _user, uint256 _value) external onlyManager returns(bool) {
        require(_user!=address(0));
        require(_value<=balances[roto]);

        balances[_user] = balances[_user].add(_value);
        emit RotoReleased(_user, _value);
        return true;
    }

    /**
        @dev - function called by manager contract to process the accounting aspects of the destroyRoto function
        @param  _user address, the address of the user who's stake will be destroyed
        @param _value ROTO, the amount that they staked
        @return - a boolean value that reflects whether the roto were successfully destroyed
    */
    function destroyRoto(address _user, uint256 _value) external onlyManager returns(bool) {
        require(_user!=address(0));
        require(_value<=balances[_user]);

        balances[roto] = balances[roto].add(_value);
        emit RotoDestroyed(_user, _value);
        return true;
    }

    /**
        @dev - called by the manager contract, runs the accounting portions of the staking process
        @param  _user address, the address of the user staking ROTO
        @param _value ROTO, the amount the user is staking
        @return - whether the staking process went successfully
    */
    function stakeRoto(address _user, uint256 _value) external onlyManager returns(bool) {
        require(_user!=address(0));
        require(_value<=balances[_user]);

        balances[_user] = balances[_user].sub(_value);
        emit RotoStaked(_user, _value);
        return true;
    }
    
    /**
      @dev - called by the manager contract, used to reward non-staked submissions by users
     */
    function rewardRoto(address _user, uint256 _value) external onlyManager returns(bool successful) {
      require(_user!=address(0));
      require(_value<=balances[roto]);

      balances[_user] = balances[_user].add(_value);
      balances[roto] = balances[roto].sub(_value);

      emit RotoRewarded(roto, _user, _value);
      return true;
    }
    /**
        @dev - to be called by the manager contract to check if a given user has enough roto to
            stake the given amount
        @param  _user address, the address of the user who's attempting to stake ROTO
        @param _value ROTO, the amount they are attempting to stake
        @return - whether the user has enough balance to stake the received amount
    */
    function canStake(address _user, uint256 _value) public view onlyManager returns(bool) {
      require(_user!=address(0));
      require(_value<=balances[_user]);

      return true;
    }

    /**
      @dev Getter function for manager
     */
    function getManager() public view returns (address _manager) {
      return manager;
    }
}
pragma solidity 0.4.24;

import "./StandardToken.sol";

contract RotoToken is StandardToken {

    string public constant name = "Roto"; // token name
    string public constant symbol = "ROTO"; // token symbol
    uint8 public constant decimals = 18; // token decimal

    uint256 public constant INITIAL_SUPPLY = 21000000 * (10 ** uint256(decimals));
    address owner;
    address roto = this;
    address manager;

    // keeps track of the ROTO currently staked in a tournament
    // the format is user address -> the tournament they staked in -> how much they staked
    mapping (address => mapping (bytes32 => uint256)) stakes;
    uint256 owner_transfer = 2000000 * (10** uint256(decimals));
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

    
    /**
     *  @dev A function that can only be called by RotoHive, transfers Roto Tokens out of the contract.
        @param _to address, the address that the ROTO will be transferred to
        @param _value ROTO, amount to transfer
        @return - whether the Roto was transferred succesfully
     */
    function transferFromContract(address _to, uint256 _value) public onlyOwner returns(bool) {
        require(_to!=address(0));
        require(_value<=balances[roto]);
        require(owner_transfer > 0);

        owner_transfer = owner_transfer.sub(_value);
        
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
      //checks that the address sent isn't the 0 address, the owner or the token contract
      require(_contract!=address(0)&&_contract!=roto);

      // requires that the address sent be a contract
      uint size;
      assembly { size := extcodesize(_contract) }
      require(size > 0);

      manager = _contract;

      emit ManagerChanged(_contract);
      return true;
    }

    /**
        @dev - called by the manager contract to add back to the user their roto in the event that their submission was successful
        @param  _user address, the address of the user who submitted the rankings
        @param _tournamentID identifier
        @return boolean value, whether the roto were successfully released
    */
    function releaseRoto(address _user, bytes32 _tournamentID) external onlyManager returns(bool) {
        require(_user!=address(0));
        uint256 value = stakes[_user][_tournamentID];
        require(value > 0);

        stakes[_user][_tournamentID] = 0;
        balances[_user] = balances[_user].add(value);

        emit RotoReleased(_user, value);
        return true;
    }

    /**
        @dev - function called by manager contract to process the accounting aspects of the destroyRoto function
        @param  _user address, the address of the user who's stake will be destroyed
        @param _tournamentID identifier
        @return - a boolean value that reflects whether the roto were successfully destroyed
    */
    function destroyRoto(address _user, bytes32 _tournamentID) external onlyManager returns(bool) {
        require(_user!=address(0));
        uint256 value = stakes[_user][_tournamentID];
        require(value > 0);

        stakes[_user][_tournamentID] = 0;
        balances[roto] = balances[roto].add(value);

        emit RotoDestroyed(_user, value);
        return true;
    }

    /**
        @dev - called by the manager contract, runs the accounting portions of the staking process
        @param  _user address, the address of the user staking ROTO
        @param _tournamentID identifier
        @param _value ROTO, the amount the user is staking
        @return - whether the staking process went successfully
    */
    function stakeRoto(address _user, bytes32 _tournamentID, uint256 _value) external onlyManager returns(bool) {
        require(_user!=address(0));
        require(_value<=balances[_user]);
        require(stakes[_user][_tournamentID] == 0);

        balances[_user] = balances[_user].sub(_value);
        stakes[_user][_tournamentID] = _value;

        emit RotoStaked(_user, _value);
        return true;
    }
    
    /**
      @dev - called by the manager contract, used to reward non-staked submissions by users
      @param _user address, the address that will receive the rewarded ROTO
      @param _value ROTO, the amount of ROTO that they'll be rewarded
     */
    function rewardRoto(address _user, uint256 _value) external onlyManager returns(bool successful) {
      require(_user!=address(0));
      require(_value<=balances[roto]);

      balances[_user] = balances[_user].add(_value);
      balances[roto] = balances[roto].sub(_value);

      emit Transfer(roto, _user, _value);
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

    /**
      @dev - sets the owner address to a new one
      @param  _newOwner address
      @return - true if the address was changed successful
     */
    function changeOwner(address _newOwner) public onlyOwner returns(bool) {
      owner = _newOwner;
    }
}
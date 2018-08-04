pragma solidity 0.4.24;

import './RotoToken.sol';
contract RotoBasic {

    mapping (bytes32 => Tournament) public tournaments;  // tournamentID
    
    //Instance and Address of the RotoToken contract
    RotoToken token;
    address roto;

    //Address of the contract owner the manager contract(this contract)
    address owner;
    address manager;

    //boolean variable that determines whether there's an emergency state
    bool emergency;

    struct Tournament {
        bool open;
        // the total ether prize and how much is left
        uint256 etherPrize;
        uint256 etherLeft;
        // the total roto prize how much is left
        uint256 rotoPrize;
        uint256 rotoLeft;
        // tournament details
        uint256 creationTime;
        mapping (address => mapping (bytes32 => Stake)) stakes;  // address of staker, to tournament ID points to a specific stake
        //counters to easily tell the # of stakes vs # of stakes resolved
        uint256 userStakes;
        uint256 stakesResolved;
    }

    struct Stake {
        uint256 amount; // Once the stake is resolved, this becomes 0
        bool successful;
        bool resolved;
    }

    modifier onlyOwner {
      require(msg.sender==owner);
      _;
    }

    modifier stopInEmergency {
      require(emergency==false);
      _;
    }

    //Tournament Creation and Processing Events
    event StakeProcessed(address indexed staker, uint256 totalAmountStaked, bytes32 indexed tournamentID);
    event StakeDestroyed(bytes32 indexed tournamentID, address indexed stakerAddress, uint256 rotoLost);
    event StakeReleased(bytes32 indexed tournamentID, address indexed stakerAddress, uint256 etherReward, uint256 rotoStaked);
    event SubmissionRewarded(bytes32 indexed tournamentID, address indexed stakerAddress, uint256 rotoReward);
    
    event TokenChanged(address _contract);
    event TournamentCreated(bytes32 indexed tournamentID, uint256 etherPrize, uint256 rotoPrize);
    event TournamentClosed(bytes32 indexed tournamentID);

    /**
       @dev - sets the token contract to used for the token accounting
       @param _contract address, the address of the token contract
       @return - true if the token contract was set successfully
    */
    function setTokenContract(address _contract) public onlyOwner returns(bool) {
      require(_contract!=address(0)&&_contract!=manager);

      // requires that the address sent be a contract
      uint size;
      assembly { size := extcodesize(_contract) }
      require(size > 0);

      roto = _contract;
      token = RotoToken(roto);

      emit TokenChanged(_contract);
      return true;
    }

    /**
        @dev - sets the state of the emegency variable to true, preventing any of the tournament processes to run
        @param _emergency boolean variable to set emergency to
        @return - true if the variable was changed successfully
    */
    function setEmergency(bool _emergency) public onlyOwner returns(bool) {
      emergency = _emergency;
      return true;
    }

}
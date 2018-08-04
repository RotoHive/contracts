const assert = require('assert')
const ganache = require('ganache-cli')
const Web3 = require('web3')

const web3 = new Web3(ganache.provider())

const compiledToken = require('../build/contracts/RotoToken.json')
const compiledManager = require('../build/contracts/RotoManager.json')

let accounts

let manager
let token
let address

// general listeners
let TournamentListener
let TokenListener

// staking related listeners
let StakeProcessedListener
let StakeReleasedListener
let SubmissionRewardedListener
let StakeDestroyedListener

// tournament info
let tournamentID
let etherPrize
let rotoPrize

describe('RotoManager Contract', async () => {

  beforeEach(async () => {
    accounts = await web3.eth.getAccounts()

    token = await new web3.eth.Contract(compiledToken.abi)
      .deploy({ data: compiledToken.bytecode })
      .send({ from: accounts[0], gas: 4500000 })

    manager = await new web3.eth.Contract(compiledManager.abi)
      .deploy({ data: compiledManager.bytecode })
      .send({ from: accounts[0], gas: 4500000 })

    await manager.methods
      .setTokenContract(token.options.address)
      .send({ from: accounts[0] })
    address = manager.options.address

    await token.methods
      .setManagerContract(manager.options.address)
      .send({ from: accounts[0] })

    // Tournament Listener
    TournamentListener = await manager.events.TournamentCreated({
      fromBlock: 0
    })

    // Token Changed
    TokenListener = await manager.events.TokenChanged({ fromBlock: 0 })

    // Stake Processed
    StakeProcessedListener = await manager.events.StakeProcessed({
      fromBlock: 0
    })

    // Stake Released
    StakeReleasedListener = await manager.events.StakeReleased({ fromBlock: 0 })

    //Submission Rewarded
    SubmissionRewardedListener = await manager.events.SubmissionRewarded({ fromBlock: 0 })

    // Stake Destroyed
    StakeDestroyedListener = await manager.events.StakeDestroyed({
      fromBlock: 0
    })

    //Creates a Tournament
    tournamentID = web3.utils.randomHex(32)
    etherPrize = await web3.utils.toWei('12')
    rotoPrize = await web3.utils.toWei('5000000')
    await manager.methods.createTournament(tournamentID, etherPrize, rotoPrize)
      .send({ from: accounts[0], gas: 1500000, value: await web3.utils.toWei('10') })

    //transfer 100 ROTO to account 1
    await token.methods.transferFromContract(accounts[1], await web3.utils.toWei('100')).send({
      from: accounts[0]
    })
  })

  it('should have deployed the contracts propertly', async () => {
    assert.ok(address)
    assert.ok(token.options.address);
  })

  it('should have 10 ether in balance', async() => {
    let balance = await web3.utils.fromWei(await web3.eth.getBalance(address));

    assert.equal('10', balance)
  })

  it('should have created a tournament', async() => {
      TournamentListener.on('data', event => {
        let returnValues = event.returnValues

        assert.equal(tournamentID, returnValues.tournamentID);
        assert.equal(etherPrize, returnValues.etherPrize)
        assert.equal(rotoPrize, returnvalues.rotoPrize)
      })
  })
  it('shoudl give account 1 100 ROTO', async() => {
      let balance = await token.methods.balanceOf(accounts[1]).call()
      balance = await web3.utils.fromWei(balance)

      assert.equal('100', balance)
  })
  it('should allow a user to stake ROTO on a tournament', async() => {

      let stake = await web3.utils.toWei('10')
      let staker = accounts[1]

      let initial_balance = await token.methods.balanceOf(staker).call()

      StakeProcessedListener.on('data', event => {
          let returnValues = event.returnValues

          assert.equal(tournamentID, returnValues.tournamentID);
          assert.equal(staker, returnValues.staker)
          assert.equal(stake, returnValues.totalAmountStaked)
      })

      const result = await manager.methods.stake(stake, tournamentID).send({ from: staker, gas: '120000' })
      console.log('Staking Gas Cost: ',result.gasUsed);
      let final_balance = await token.methods.balanceOf(staker).call()
      
      let expected_value = Number(initial_balance) - Number(stake)
      assert.equal(expected_value.toString(), final_balance)
  })

  it('should allow the owner to release staked ROTO, and give it 0 ether', async() => {
    let stake = await web3.utils.toWei('10')
    let staker = accounts[1]
    let etherReward = 0

    //gets the initial ROTO balance
    let initial_balance = await token.methods.balanceOf(staker).call()
    
    //stakes 10 ROTO in the tournament
    await manager.methods.stake(stake, tournamentID).send({ from: staker, gas: '120000' })
    
    StakeReleasedListener.on('data', event => {
      let returnValues = event.returnValues

      assert.equal(tournamentID, returnValues.tournamentID)
      assert.equal(staker, returnValues.stakerAddress)
      assert.equal(etherReward, returnValues.etherReward)
      assert.equal(stake, returnValues.rotoStaked)
    })

    
    let result = await manager.methods.releaseRoto(staker, tournamentID, etherReward).send({ from: accounts[0] ,gas: '300000'})
    console.log('Release Stake Gas Used(no ether): ', result.gasUsed)
    let final_balance = await token.methods.balanceOf(staker).call()
    
    assert.equal(initial_balance, final_balance)
  })

  it('should allow the owner to release staked ROTO, and give it 2 ether', async() => {
    let stake = await web3.utils.toWei('10')
    let staker = accounts[1]
    let etherReward = await web3.utils.toWei('2')

    //Gets initial ether and roto balance
    let initial_ether_balance = await web3.eth.getBalance(staker);
    let initial_roto_balance = await token.methods.balanceOf(staker).call()

    //stakes 10 ROTO in the tournament
    await manager.methods.stake(stake, tournamentID).send({ from: staker,  gas: '120000' })

    StakeReleasedListener.on('data', event => {
      let returnValues = event.returnValues

      assert.equal(tournamentID, returnValues.tournamentID)
      assert.equal(staker, returnValues.stakerAddress)
      assert.equal(etherReward, returnValues.etherReward)
      assert.equal(stake, returnValues.rotoStaked)
    })

    let result = await manager.methods.releaseRoto(staker, tournamentID, etherReward).send({ from: accounts[0], gas: '300000' })
    console.log('Release Stake Gas Used(with ether): ', result.gasUsed)
    //gets final ether and roto balances
    let final_ether_balance = await web3.eth.getBalance(staker)
    let final_roto_balance = await token.methods.balanceOf(staker).call()

    let expected_ether_value = Number(initial_ether_balance)
    let end_ether_value = Number(final_ether_balance)

    assert.equal(final_roto_balance, initial_roto_balance);
    assert(end_ether_value > expected_ether_value);
  })

  it('should allow the owner to destroy staked ROTO', async() => {
    let stake = await web3.utils.toWei('10')
    let staker = accounts[1]

    //gets the initial ROTO balance
    let initial_balance = await token.methods.balanceOf(staker).call()

    //stakes 10 ROTO in the tournament
    await manager.methods.stake(stake, tournamentID).send({ from: staker,  gas: '120000' })

    StakeDestroyedListener.on('data', event => {
      let returnValues = event.returnValues
      
      assert.equal(tournamentID, returnValues.tournamentID)
      assert.equal(staker, returnValues.stakerAddress)
      assert.equal(stake, returnValues.rotoLost)
    })

    let result = await manager.methods.destroyRoto(staker, tournamentID).send({ from: accounts[0], gas: '300000' })
    console.log('Destroy Stake Gas Used: ', result.gasUsed)
    let final_balance = await token.methods.balanceOf(staker).call()
    let expected = initial_balance - stake;

    assert.equal(final_balance, expected);
  })

  it('should allow the owner to reward unstaked submissions', async() => {
      let user = accounts[1]
      let rotoPrize = await web3.utils.toWei('5')
      
      //gets the initial ROTO balance
      let initial_balance = await token.methods.balanceOf(user).call()

      SubmissionRewardedListener.on('data', event => {
        let returnValues = event.returnValues
        
        assert.equal(tournamentID, returnValues.tournamentID)
        assert.equal(user, returnValues.stakerAddress)
        assert.equal(rotoPrize, returnValues.rotoReward)
      })

      let result = await manager.methods.rewardRoto(user, tournamentID, rotoPrize).send({ from: accounts[0] })
      console.log('Reward Roto Gas Used(unstaked submission): ', result.gasUsed)
      let final_balance = await token.methods.balanceOf(user).call()
      let expected = Number(initial_balance) + Number(rotoPrize)
      
      assert.equal(final_balance, expected)
  })
})
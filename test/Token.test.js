const assert = require('assert')
const ganache = require('ganache-cli')
const Web3 = require('web3')

const web3 = new Web3(ganache.provider())

const compiledToken = require('../build/contracts/RotoToken.json')
const compiledManager = require('../build/contracts/RotoManager.json')

let accounts

let token
let address

let manager
let managerAddr

let supply
let decimal

describe('RotoToken Contract', async () => {
  beforeEach(async () => {
    accounts = await web3.eth.getAccounts()
    token = await new web3.eth.Contract(compiledToken.abi)
      .deploy({ data: compiledToken.bytecode })
      .send({ from: accounts[0], gas: 4500000 })

    manager = await new web3.eth.Contract(compiledManager.abi)
      .deploy({ data: compiledManager.bytecode })
      .send({ from: accounts[0], gas: 4500000})

    await token.methods.setManagerContract(manager.options.address).send({
      from: accounts[0]
    })

    managerAddr = manager.options.address
    supply = await token.methods.totalSupply().call()
    decimal = await token.methods.decimals().call()
    address = token.options.address
  })
  it('should deploy the contract correctly', () => {
    assert.ok(address)
  })

  it('should set the total supply to 21 million', () => {
    const expected = 21000000
    assert.equal(expected, supply / 10 ** decimal)
  })

  it('should set the decimals to 18', async () => {
    const expected = 18
    assert.equal(expected, decimal)
  })

  it('should send all of the initial amount to the contract', async () => {
    let contract_balance = await token.methods
      .balanceOf(address)
      .call({ from: accounts[0] })
    assert.equal(supply, contract_balance)
  })
  it('should set the initial balance of account 1 and 2 to 0', async () => {
    const account_balance = await token.methods.balanceOf(accounts[1]).call()
    const account1_balance = await token.methods.balanceOf(accounts[1]).call()

    assert.equal(0, account1_balance)
    assert.equal(account1_balance, account_balance)
  })

  it('should set the manager contract correctly', async () => {
    const result = await token.methods.getManager().call()

    assert.equal(managerAddr, result)
  })
  it('should allow the owner to transfer ROTO from the contract', async () => {
    let withdrawal = '1000000000000000000000000'
    const result = await token.methods
      .transferFromContract(accounts[0], withdrawal)
      .send({ from: accounts[0] })
    assert(result)

    let account1_balance = await token.methods.balanceOf(accounts[0]).call()
    assert.equal(1000000, Number(account1_balance) / 10 ** decimal)
  })

  it('should transfer 500k ROTO from account 0 to account 1', async () => {
    let withdrawal = '1000000000000000000000000'
    const withdraw_result = await token.methods
      .transferFromContract(accounts[0], withdrawal)
      .send({ from: accounts[0] })
    assert(withdraw_result)

    let account_balance = await token.methods.balanceOf(accounts[0]).call()
    assert.equal(1000000, Number(account_balance) / 10 ** decimal)

    let transferAmount = '500000000000000000000000'
    const transfer_result = await token.methods
      .transfer(accounts[1], transferAmount)
      .send({ from: accounts[0] })
    assert(transfer_result)

    let account1_balance = await token.methods.balanceOf(accounts[1]).call()
    assert.equal(500000, Number(account1_balance) / 10 ** decimal)
  })

  it('should set the base allowance for a given address to 0', async () => {
    let allowance = await token.methods
      .allowance(accounts[0], accounts[1])
      .call()
    assert.equal(0, allowance)
  })
})

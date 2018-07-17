const HDWalletProvider = require('truffle-hdwallet-provider')

module.exports = {
  networks: {
    live: {
      network_id: 1
    },
    development: {
      host: 'localhost',
      port: 7545,
      network_id: '*',
      gas: 4612388
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
}

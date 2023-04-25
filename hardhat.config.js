require("@nomicfoundation/hardhat-toolbox");
require('solidity-docgen')
require('dotenv').config()
require("hardhat-contract-sizer");
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  etherscan: {
    apiKey: process.env.ETHERSCAN,
  },
  contractSizer: {
    runOnCompile: true,
  },
  networks: {
    testnet: {
      url: "http://127.0.0.1:8545",
      accounts: ["0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"]
    },
    goerli: {
      url: "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
      chainId: 5,
      accounts: [process.env.PRIVATE_KEY]
    },
    polygon: {
      url: 'https://polygon-rpc.com/',
      accounts: [process.env.PRIVATE_KEY],
      chainId: 137
    },
    ethereum: {
      url: process.env.ETHEREUMRPC,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 1
    }
  },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000,
      },
    },
  },
};

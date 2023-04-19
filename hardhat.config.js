require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-network-helpers");
require("hardhat-contract-sizer");

require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.14",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100000,
      },
    },
  },
  paths: {
    tests: "./tests",
  },
  networks: {
    mumbai: {
      url: process.env.RPC_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: "PVWC1XQW7X1RVBPDEVYGP2DGSZWZTT4WMT",
  },
  gasReporter: {
    enabled: true,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    currency: "USD",
  },
};

// npx hardhat --network mumbai run scripts/deploy.js

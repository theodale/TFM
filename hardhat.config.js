require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-network-helpers");

require("dotenv").config();

module.exports = {
  solidity: "0.8.14",
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
};

// npx hardhat --network mumbai run scripts/deploy.js

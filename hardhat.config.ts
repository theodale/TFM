// import { task, subtask } from "hardhat/config";
// import "@nomiclabs/hardhat-waffle";
// import "hardhat-contract-sizer";
// import "hardhat-log-remover";
// import "hardhat-deploy";
// import "@nomiclabs/hardhat-ethers";
// import "@nomiclabs/hardhat-etherscan";
// import "@openzeppelin/hardhat-upgrades";
// import "solidity-coverage";
// import "hardhat-gas-reporter";
// import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from "hardhat/builtin-tasks/task-names";
// import path from "path";
// import "hardhat-abi-exporter";
// import exportDeployments from "./scripts/tasks/exportDeployments";
// import { BLOCK_NUMBER } from "./constants/constants";
// import { TEST_URI } from "./scripts/helpers/getDefaultEthersProvider";
// import "@primitivefi/hardhat-dodoc";
// require("dotenv").config();

require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

module.exports = {
  solidity: "0.8.14",
};



// // Defaults to CHAINID=80001 so things will run with a mumbai testnet fork if not specified
// const CHAINID = process.env.CHAINID ? Number(process.env.CHAINID) : 80001;

// subtask(
//   TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS,
//   async (_, { config }, runSuper) => {
//     const paths = await runSuper();

//     return paths
//       .filter((solidityFilePath) => {
//         const relativePath = path.relative(
//           config.paths.sources,
//           solidityFilePath
//         );
//         return relativePath;
//       })
//       .filter(
//         (p) =>
//           !path.relative(config.paths.sources, p).startsWith("dummy_clones")
//       );
//   }
// );

// export default {
//   accounts: {
//     mnemonic: process.env.TEST_MNEMONIC,
//   },
//   paths: {
//     // sources: "contracts/infrastructure/vaults/",
//     deploy: "scripts/deploy",
//     deployments: "deployments",
//   },

//   solidity: {
//     compilers: [
//       {
//         version: "0.8.14",
//         settings: {
//           optimizer: {
//             runs: 125,
//             enabled: true,
//           },
//         },
//       },
//       {
//         version: "0.5.17",
//         settings: {
//           optimizer: {
//             runs: 125,
//             enabled: true,
//           },
//         },
//       },
//     ],
//   },
//   networks: {
//     hardhat: {
//       accounts: {
//         mnemonic: process.env.TEST_MNEMONIC,
//       },
//       hardhat: {
//         blockTime: 0,
//       },
//       chainId: CHAINID,
//       forking: {
//         url: TEST_URI[CHAINID],
//         blockNumber: BLOCK_NUMBER[CHAINID],
//         gasLimit: 8e7,
//       },
//       allowUnlimitedContractSize: true,
//       timeout: 100_000,
//     },
//     mumbai: {
//       url: process.env.MUMBAI_URI,
//       chainId: 80001,
//       gas: 2100000,
//       gasPrice: 8000000000,
//       accounts: {
//         mnemonic: process.env.MUMBAI_MNEMONIC,
//       },
//     },
//     goerli: {
//       url: process.env.GOERLI_URI,
//       chainId: 5,
//       gas: 180_000_000,
//       gasPrice: 8_000_000_000,
//       accounts: [
//         "0x24d79f019395f8bc8cc764e160d30ed6362b4bb8997747e8412a4cb1d8fa94c3",
//       ],
//     },
//     matic: {
//       url: process.env.MATIC_URI,
//       chainId: 137,
//       accounts: {
//         mnemonic: process.env.MATIC_MNEMONIC,
//       },
//     },
//     // mainnet: {
//     //   url: process.env.TEST_URI,
//     //   chainId: CHAINID,
//     //   accounts: {
//     //     mnemonic: process.env.MAINNET_MNEMONIC,
//     //   },
//     // },
//   },
//   namedAccounts: {
//     deployer: {
//       default: 0,
//       1: "0x06fd9d0Ae9052A85989D0A30c60fB11753537f9A",
//       42: "0x06fd9d0Ae9052A85989D0A30c60fB11753537f9A",
//       1337: "0x64f5A9A3FCfB275767eD76C40F83a62847b5E09E",
//       137: "0x367c3a78BB83E57115A91ACBF3ba1aEDa6755f02",
//       80001: "0x877427CCBd3061Affd5c6518bc87799B9Cf3C408",
//       5: "0xDbE6ACf2D394DBC830Ed55241d7b94aaFd2b504D",
//     },
//     owner: {
//       default: 0,
//       1: "0xAb6df2dE75a4f07D95c040DF90c7362bB5edcd90",
//       42: "0x92Dd37fbc36cB7260F0d2BD09F9672525a028fB8",
//       1337: "0x64f5A9A3FCfB275767eD76C40F83a62847b5E09E",
//       137: "0xB8C87DED8f52c6Aa1B4eb943A425440460762d2c",
//       80001: "0x877427CCBd3061Affd5c6518bc87799B9Cf3C408",
//       5: "0xDbE6ACf2D394DBC830Ed55241d7b94aaFd2b504D",
//     },
//     keeper: {
//       default: 0,
//       1: "0x65992a868F01f2D6A9c3Ce7A489AbA9E56a14637",
//       42: "0x65992a868F01f2D6A9c3Ce7A489AbA9E56a14637",
//       1337: "0x64f5A9A3FCfB275767eD76C40F83a62847b5E09E",
//       137: "0x3c86124ECfd8c36E2287Ca9b7910f1F21fF951b3",
//       80001: "0x877427CCBd3061Affd5c6518bc87799B9Cf3C408",
//       5: "0xDbE6ACf2D394DBC830Ed55241d7b94aaFd2b504D",
//     },
//     admin: {
//       default: 0,
//       1: "0x65992a868F01f2D6A9c3Ce7A489AbA9E56a14637",
//       42: "0x65992a868F01f2D6A9c3Ce7A489AbA9E56a14637",
//       1337: "0x64f5A9A3FCfB275767eD76C40F83a62847b5E09E",
//       137: "0x73eA7A15fA2a767fd4377fC0C0D533729eA4Bb6b",
//       80001: "0x2E7263d815CbB43a9647843C8a1e2F5c87F75d6A",
//       5: "0xDbE6ACf2D394DBC830Ed55241d7b94aaFd2b504D",
//     },
//     feeRecipient: {
//       default: 0,
//       1: "0x65992a868F01f2D6A9c3Ce7A489AbA9E56a14637", // Trufin DAO
//       42: "0x65992a868F01f2D6A9c3Ce7A489AbA9E56a14637",
//       1337: "0x64f5A9A3FCfB275767eD76C40F83a62847b5E09E",
//       137: "0xf1E4230e62Bc675BC41C06C7eb7d14572011e48D",
//       80001: "0x877427CCBd3061Affd5c6518bc87799B9Cf3C408",
//       5: "0xDbE6ACf2D394DBC830Ed55241d7b94aaFd2b504D",
//     },
//   },
//   abiExporter: {
//     path: "./data/abi",
//     runOnCompile: true,
//     clear: true,
//     flat: true,
//     only: [":TFM$", ":CollateralManager$", ":Utils$", ":Staker$"],
//     spacing: 2,
//     pretty: false,
//     // format: "minimal",
//   },
//   dodoc: {
//     // TODO: issue with description not being generated for parameters of functions where the function has some structs as parameters https://github.com/primitivefinance/primitive-dodoc/pull/39
//     runOnCompile: false,
//     debugMode: false,
//   },
//   mocha: {
//     timeout: 500000,
//   },
//   etherscan: {
//     apiKey: process.env.ETHERSCAN_API_KEY,
//   },
//   gasReporter: {
//     enabled: true,
//   },
// };

// task("export-deployments", "Exports deployments into JSON", exportDeployments);
// //task("verify-contracts", "Verify solidity source", verifyContracts);

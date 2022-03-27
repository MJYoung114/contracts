// const { ethers } = require("hardhat");

// let networkToUse = network.name;

// if (!!process.env.HARDHAT_FORK) {
//   networkToUse = process.env.HARDHAT_FORK;
// }

// module.exports = async (hardhatDeployArguments) => {
//   console.log("setup contracts");
//   const { getNamedAccounts, deployments } = hardhatDeployArguments;
//   const { admin } = await getNamedAccounts();

//   await deploy(TOKEN_FACTORY, {
//     from: admin,
//     log: true,
//     args: [82],
//   });
// };
// module.exports.tags = ["setup-lz-mock"];

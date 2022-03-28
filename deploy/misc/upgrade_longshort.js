const { network } = require("hardhat");
const { LONGSHORT } = require("../../helper-hardhat-config");

let networkToUse = network.name;

if (!!process.env.HARDHAT_FORK) {
  networkToUse = process.env.HARDHAT_FORK;
}

module.exports = async ({ deployments }) => {
  if (
    networkToUse != "polygon" &&
    networkToUse != "mumbai" &&
    networkToUse != "avalanche" &&
    networkToUse != "fantom-testnet"
  ) {
    throw new Error("Only run this code on polygon, mumbai or avalanche");
  }
  const { deploy } = deployments;
  const { deployer, admin } = await getNamedAccounts();
  console.log("using keys:", { deployer, admin });

  // Upgrade LongShort
  let longShortContractName = LONGSHORT;
  if (networkToUse === "mumbai" || networkToUse === "mumbai2") {
    longShortContractName = "LongShortSlave";
  } else if (networkToUse === "fantom-testnet") {
    longShortContractName = "LongShortMaster";
  }

  const longShort = await deploy(LONGSHORT, {
    contract: longShortContractName,
    from: deployer,
    log: true,
    isUups: true,
    uupsAdmin: admin,
    proxy: {
      proxyContract: "UUPSProxy",
      initializer: false,
    },
    args: [],
  });
};

module.exports.tags = ["longshort"];

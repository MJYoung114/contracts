const {
  launchSlaveMarkets,
} = require("../../deployTests/SGT_LZ_polygon");
const {
  deployMasterMarkets,
} = require("../../deployTests/SGT_LZ_fantom_testnet");
const { ethers } = require("hardhat");

const {
  STAKER,
  TEST_COLLATERAL_TOKEN,
  TREASURY,
  LONGSHORT,
  isAlphaLaunch,
  TREASURY_ALPHA,
} = require("../../helper-hardhat-config");
const { avalancheDaiAddress } = require("../config");
const { assert } = require("chai");

// const expectedMarketIndex = 4

let networkToUse = network.name;

if (!!process.env.HARDHAT_FORK) {
  networkToUse = process.env.HARDHAT_FORK;
}

module.exports = async (hardhatDeployArguments) => {
  const { getNamedAccounts, deployments } = hardhatDeployArguments;
  const { admin } = await getNamedAccounts();

  console.log("All accounts", await getNamedAccounts());

  ////////////////////////
  //Retrieve Deployments//
  ////////////////////////
  console.log("1");
  let paymentTokenAddress;

  // TEST_COLLATERAL_TOKEN = ERC20 token
  console.log("3", TEST_COLLATERAL_TOKEN);
  const paymentToken = await ethers.getContractAt(
    TEST_COLLATERAL_TOKEN,
    paymentTokenAddress
  );

  console.log("4");
  const LongShort = await deployments.get(LONGSHORT);
  console.log("5");
  const longShort = await ethers.getContractAt(LONGSHORT, LongShort.address);
  console.log("6", LongShort.address);

  let treasuryToUse = isAlphaLaunch ? TREASURY_ALPHA : TREASURY;
  console.log("7");
  const Treasury = await deployments.get(treasuryToUse);
  console.log("8");
  const treasury = await ethers.getContractAt(treasuryToUse, Treasury.address);
  console.log("9");

  const Staker = await deployments.get(STAKER);
  console.log("10");
  const staker = await ethers.getContractAt(STAKER, Staker.address);
  console.log("11");
  if (networkToUse === "mumbai" || networkToUse === "mumbai") {
    console.log("mumbai transactions");
    await launchSlaveMarkets(
      {
        staker,
        longShort: longShort.connect(admin),
        paymentToken,
        treasury,
        expectedMarketIndex
      },
      hardhatDeployArguments
    );
  } else if (networkToUse === "fantom-testnet") {
    console.log("fantom TESTNET transactions");
    await deployMasterMarkets(
      {
        staker,
        longShort: longShort.connect(admin),
        paymentToken,
        treasury,
        expectedMarketIndex
      },
      hardhatDeployArguments
    );
  } else {
    console.error("This command is only available on avalanche");
  }

  console.log("Deployment complete");
};

module.exports.tags = ["test-markets-deploy"];

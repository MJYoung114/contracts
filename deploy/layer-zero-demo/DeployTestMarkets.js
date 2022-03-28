const { launchSlaveMarkets } = require("../../deployTests/SGT_LZ_polygon");
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
const { json } = require("hardhat/internal/core/params/argumentTypes");

// const expectedMarketIndex = 4

let networkToUse = network.name;

if (!!process.env.HARDHAT_FORK) {
  networkToUse = process.env.HARDHAT_FORK;
}

module.exports = async (hardhatDeployArguments) => {
  const { getNamedAccounts, deployments } = hardhatDeployArguments;
  const { admin } = await getNamedAccounts();

  console.log("All accounts", await getNamedAccounts());

  const accounts = await ethers.getSigners();

  const adminSigner = accounts[1];

  ////////////////////////
  //Retrieve Deployments//
  ////////////////////////
  console.log("1");

  // TEST_COLLATERAL_TOKEN = ERC20 token
  let paymentTokenAddress;
  if (networkToUse == "polygon") {
    paymentTokenAddress = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";
  } else if (networkToUse === "avalanche") {
    paymentTokenAddress = avalancheDaiAddress;
  } else if (networkToUse == "mumbai") {
    paymentTokenAddress = "0x001B3B4d0F3714Ca98ba10F6042DaEbF0B1B7b6F";
  } else if (networkToUse === "fantom-testnet") {
    paymentTokenAddress = "0x5343b5bA672Ae99d627A1C87866b8E53F47Db2E6";
  } else if (networkToUse == "hardhat" || networkToUse == "ganache") {
    paymentTokenAddress = (await deployments.get(TEST_COLLATERAL_TOKEN))
      .address;
  }
  const paymentToken = await ethers.getContractAt(
    TEST_COLLATERAL_TOKEN,
    paymentTokenAddress
  );

  console.log("4");
  let longShortContractToUse = LONGSHORT;
  if (networkToUse === "mumbai" || networkToUse === "mumbai2") {
    longShortContractToUse = "LongShortSlave";
  } else if (networkToUse === "fantom-testnet") {
    longShortContractToUse = "LongShortMaster";
  }
  const LongShort = await deployments.get(longShortContractToUse);
  const longShort = await ethers.getContractAt(
    longShortContractToUse,
    LongShort.address
  );
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
    // await launchSlaveMarkets(
    //   {
    //     staker,
    //     longShort: longShort.connect(admin),
    //     paymentToken,
    //     treasury,
    //     // expectedMarketIndex
    //   },
    //   hardhatDeployArguments
    // );
    let connectedLongShort = await longShort.connect(adminSigner);

    await connectedLongShort.setYieldManager(
      1,
      "0x4c48599575aFF3C677f62611D84e4018beAcA39f"
    );
    await connectedLongShort.setYieldManager(
      2,
      "0x4c48599575aFF3C677f62611D84e4018beAcA39f"
    );
    await connectedLongShort.setYieldManager(
      3,
      "0x4c48599575aFF3C677f62611D84e4018beAcA39f"
    );
    await connectedLongShort.setupMarketCommunication(
      1,
      4002,
      "0xD2a63D68bDC7308603E6874f38042ABAF037767B",
      0 // MAKE VERY SURE THIS IS THE LATEST VALUE!
    );
    await connectedLongShort.setupMarketCommunication(
      2,
      4002,
      "0xD2a63D68bDC7308603E6874f38042ABAF037767B",
      0 // MAKE VERY SURE THIS IS THE LATEST VALUE!
    );
    await connectedLongShort.setupMarketCommunication(
      3,
      4002,
      "0xD2a63D68bDC7308603E6874f38042ABAF037767B",
      0 // MAKE VERY SURE THIS IS THE LATEST VALUE!
    );
  } else if (networkToUse === "fantom-testnet") {
    console.log("fantom TESTNET transactions");
    // await deployMasterMarkets(
    //   {
    //     staker,
    //     longShort: longShort.connect(admin),
    //     paymentToken,
    //     treasury,
    //   },
    //   hardhatDeployArguments
    // );
    let connectedLongShort = await longShort.connect(adminSigner);
    let marketUpdateIndex = await connectedLongShort.marketUpdateIndex(1);
    console.log("update index " + marketUpdateIndex);
    console.log("set 1");
    await connectedLongShort.setupMarketCommunication(
      1,
      [10009, 10009],
      [
        "0x06F4AD4CD3CC5c92dAfD97B48191B56944D6d594",
        "0x80Ada349227d6BDdb13e099521ee33C823ACD2bb",
      ]
    );
    console.log("set 1");
    await connectedLongShort.setupMarketCommunication(
      2,
      [10009, 10009],
      [
        "0x06F4AD4CD3CC5c92dAfD97B48191B56944D6d594",
        "0x80Ada349227d6BDdb13e099521ee33C823ACD2bb",
      ]
    );
    console.log("2");
    await connectedLongShort.setupMarketCommunication(
      3,
      [10009, 10009],
      [
        "0x06F4AD4CD3CC5c92dAfD97B48191B56944D6d594",
        "0x80Ada349227d6BDdb13e099521ee33C823ACD2bb",
      ]
    );
    console.log("3");
  } else {
    console.error("This command is only available on avalanche");
  }
  let connectedLongShort = await longShort.connect(adminSigner);

  await connectedLongShort.initializeMarket(
    1,
    "1000000000000000000",
    "1000000000000000000",
    "1000000000000000000"
  );
  await connectedLongShort.initializeMarket(
    2,
    "1000000000000000000",
    "1000000000000000000",
    "1000000000000000000"
  );
  await connectedLongShort.initializeMarket(
    3,
    "1000000000000000000",
    "1000000000000000000",
    "1000000000000000000"
  );

  console.log("Deployment complete");
};

module.exports.tags = ["test-markets-deploy"];

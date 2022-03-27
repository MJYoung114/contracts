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
} = require("../../../helper-hardhat-config");
const { avalancheDaiAddress } = require("../../config");
const { assert } = require("chai");

// const expectedMarketIndex = 4

let networkToUse = network.name;

if (!!process.env.HARDHAT_FORK) {
  networkToUse = process.env.HARDHAT_FORK;
}

module.exports = async (hardhatDeployArguments) => {
  throw "don't go further yet"
  console.log("setup contracts");
  const { getNamedAccounts, deployments } = hardhatDeployArguments;
  const { deployer, admin, discountSigner } = await getNamedAccounts();

  ////////////////////////
  //Retrieve Deployments//
  ////////////////////////
  console.log("1");
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

  // A hack to get the ERC20MockWithPublicMint token to work on ganache (with test transactions - codegen doesn't account for duplicate named functions)
  //    related: https://github.com/Float-Capital/monorepo/issues/1767
  paymentToken["mint"] = paymentToken["mint(address,uint256)"];

  const Gems = await deployments.get(GEMS);
  const gems = await ethers.getContractAt(GEMS, Gems.address);


  let longShortContractToUse = LONGSHORT;
  if (networkToUse === "mumbai" || networkToUse === "mumbai2") {
    longShortContractToUse = "LongShortSlave";
  } else if (networkToUse === "fantom-testnet") {
    longShortContractToUse = "LongShortMaster";
  }
  const LongShort = await deployments.get(longShortContractToUse);
  const longShort = await ethers.getContractAt(longShortContractToUse, LongShort.address);

  let treasuryToUse = isAlphaLaunch ? TREASURY_ALPHA : TREASURY;
  const Treasury = await deployments.get(treasuryToUse);
  const treasury = await ethers.getContractAt(treasuryToUse, Treasury.address);

  const TokenFactory = await deployments.get(TOKEN_FACTORY);
  const tokenFactory = await ethers.getContractAt(
    TOKEN_FACTORY,
    TokenFactory.address
  );

  const Staker = await deployments.get(STAKER);
  const staker = await ethers.getContractAt(STAKER, Staker.address);
  console.log("3", longShort.address, staker.address);

  const floatTokenToUse = isAlphaLaunch ? FLOAT_TOKEN_ALPHA : FLOAT_TOKEN;
  const FloatToken = await deployments.get(floatTokenToUse);
  const floatToken = await ethers.getContractAt(
    floatTokenToUse,
    FloatToken.address
  );
  console.log("4");

  const FloatCapital = await deployments.get(FLOAT_CAPITAL);
  const floatCapital = await ethers.getContractAt(
    FLOAT_CAPITAL,
    FloatCapital.address
  );
  console.log("5");
  // /////////////////////////
  // Initialize the contracts/
  // /////////////////////////
  await longShort.initialize(
    admin,
    tokenFactory.address,
    "0x0000000000000000000000000000000000000000",
    gems.address
  );
  console.log("6");
  if (isAlphaLaunch) {
    console.log("7");
    if (networkToUse == "avalanche") {
      console.log("8");
      await floatToken.initialize(
        "AVA Test Float",
        "avaTestFLT",
        "0x0000000000000000000000000000000000000000",
        treasury.address
      );
    } else {
      await floatToken.initialize(
        "Alpha Float",
        "alphaFLT",
        "0x0000000000000000000000000000000000000000",
        treasury.address
      );
    }
  } else {
    await floatToken.initialize(
      "Float",
      "FLT",
      "0x0000000000000000000000000000000000000000"
    );
  }
  console.log("9");
  console.log("10");

  await gems.initialize(
    admin,
    longShort.address,
    "0x0000000000000000000000000000000000000000"
  );

  // if (networkToUse === "mumbai" || networkToUse === "mumbai") {
  //   await longShort.setupMarketCommunication(
  //     1,
  //     masterChainId,
  //     address(longShortM),
  //     longShortM.latestActionIndex(1) // MAKE VERY SURE THIS IS THE LATEST VALUE!
  //   );
  // } else if (networkToUse === "fantom-testnet") {
  //   await longShort.setDestLzEndpoint(
  //     longShort.address,
  //     "0x7dcAD72640F835B0FA36EFD3D6d3ec902C7E5acf"
  //   );
  // }
};

module.exports.tags = ["test-markets-setup"];


/*
longShortS.setupMarketCommunication(
  1,
  masterChainId,
  address(longShortM),
  longShortM.latestActionIndex(1) // MAKE VERY SURE THIS IS THE LATEST VALUE!
);
uint16[] memory slaveChainIds = new uint16[](1);
slaveChainIds[0] = slaveChainId;
address[] memory longShorts = new address[](1);
longShorts[0] = address(longShortS);
longShortM.setupMarketCommunication(1, slaveChainIds, longShorts);
*/

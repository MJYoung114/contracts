open LetOps;
open DeployHelpers;

// CHAINLINK FEEDS:
//     https://docs.chain.link/docs/avalanche-price-feeds/

// SOURCE: https://docs.chain.link/docs/avalanche-price-feeds/
let avaxOraclePriceFeedAddress =
  "0xe04676B9A9A2973BCb0D1478b5E1E9098BBB7f3D"->Ethers.Utils.getAddressUnsafe;
// https://snowtrace.io/address/0x02D35d3a8aC3e1626d3eE09A78Dd87286F5E8e3a
let joeOraclePriceFeedAddress =
  "0x02D35d3a8aC3e1626d3eE09A78Dd87286F5E8e3a"->Ethers.Utils.getAddressUnsafe;
// https://snowtrace.io/address/0x36E039e6391A5E7A7267650979fdf613f659be5D
let qiOraclePriceFeedAddress =
  "0x36E039e6391A5E7A7267650979fdf613f659be5D"->Ethers.Utils.getAddressUnsafe;
// https://snowtrace.io/address/0x4F3ddF9378a4865cf4f28BE51E10AECb83B7daeE
let spellOraclePriceFeedAddress =
  "0x4F3ddF9378a4865cf4f28BE51E10AECb83B7daeE"->Ethers.Utils.getAddressUnsafe;

// qiDAI
// https://docs.benqi.fi/contracts
let benqiDaiCToken = "0x835866d37AFB8CB8F8334dCCdaf66cf01832Ff5D";
// jDAI
// https://docs.traderjoexyz.com/main/security-and-contracts/contracts
let joeDaiCToken = "0xc988c170d0E38197DC634A45bF00169C7Aa7CA19";

type allContracts = {
  staker: Staker.t,
  longShort: LongShort.t,
  paymentToken: ERC20Mock.t,
  treasury: Treasury_v0.t,
  syntheticToken: SyntheticToken.t,
  expectedMarketIndex: int,
};

let launchSlaveMarkets =
    (
      {longShort, staker, treasury, paymentToken},
      deploymentArgs: Hardhat.hardhatDeployArgument,
    ) => {
  let%AwaitThen namedAccounts = deploymentArgs.getNamedAccounts();
  let%AwaitThen loadedAccounts = Ethers.getSigners();

  let admin = loadedAccounts->Array.getUnsafe(1);

  Js.log("deploying markets");
  // let syntheticName = "Stargate Finance 3x";
  // let syntheticSymbol = "3SGT";

  // let%AwaitThen _ =
  //   deployAvalancheMarket(
  //     ~longShortInstance=longShort,
  //     ~treasuryInstance=treasury,
  //     ~stakerInstance=staker,
  //     ~deployments=deploymentArgs.deployments,
  //     ~namedAccounts,
  //     ~admin,
  //     ~paymentToken: ERC20Mock.t,
  //     ~oraclePriceFeedAddress=avaxOraclePriceFeedAddress,
  //     ~syntheticName,
  //     ~syntheticSymbol,
  //     ~fundingRateMultiplier=CONSTANTS.tenToThe18,
  //     ~marketLeverage=3,
  //     ~expectedMarketIndex=1,
  //     ~yieldManagerVariant=AaveDAI,
  //   );

  let syntheticName = "AVAX Market 2x";
  let syntheticSymbol = "2AVAX";

  let%AwaitThen _ =
    deployAvalancheMarket(
      ~longShortInstance=longShort,
      ~treasuryInstance=treasury,
      ~stakerInstance=staker,
      ~deployments=deploymentArgs.deployments,
      ~namedAccounts,
      ~admin,
      ~paymentToken: ERC20Mock.t,
      ~oraclePriceFeedAddress=avaxOraclePriceFeedAddress,
      ~syntheticName,
      ~syntheticSymbol,
      ~fundingRateMultiplier=CONSTANTS.tenToThe18,
      ~marketLeverage=2,
      ~expectedMarketIndex=2,
      ~yieldManagerVariant=AaveDAI,
    );

  let syntheticName = "Ether Market 2x";
  let syntheticSymbol = "2ETH";

  deployAvalancheMarket(
    ~longShortInstance=longShort,
    ~treasuryInstance=treasury,
    ~stakerInstance=staker,
    ~deployments=deploymentArgs.deployments,
    ~namedAccounts,
    ~admin,
    ~paymentToken: ERC20Mock.t,
    ~oraclePriceFeedAddress=avaxOraclePriceFeedAddress,
    ~syntheticName,
    ~syntheticSymbol,
    ~fundingRateMultiplier=CONSTANTS.tenToThe18,
    ~marketLeverage=2,
    ~expectedMarketIndex=3,
    ~yieldManagerVariant=AaveDAI,
  );
};

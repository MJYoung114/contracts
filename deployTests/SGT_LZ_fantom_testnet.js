// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';

var Curry = require("rescript/lib/js/curry.js");
var LetOps = require("../test/library/LetOps.js");
var TestnetDeployHelpers = require("./helpers/TestnetDeployHelpers.js");

var btcUSDPriceFeedAddress = ethers.utils.getAddress("0x65E8d79f3e8e36fE48eC31A2ae935e92F5bBF529");

var ethUSDPriceFeedAddress = ethers.utils.getAddress("0xB8C458C957a6e6ca7Cc53eD95bEA548c52AFaA24");

var fantomUsdPriceFeedAddress = ethers.utils.getAddress("0xe04676B9A9A2973BCb0D1478b5E1E9098BBB7f3D");

function deployMasterMarkets(param, deploymentArgs) {
  var treasury = param.treasury;
  var paymentToken = param.paymentToken;
  var longShort = param.longShort;
  var staker = param.staker;
  return LetOps.AwaitThen.let_(Curry._1(deploymentArgs.getNamedAccounts, undefined), (function (namedAccounts) {
                return LetOps.AwaitThen.let_(ethers.getSigners(), (function (loadedAccounts) {
                              var admin = loadedAccounts[1];
                              console.log("deploying markets");
                              return LetOps.AwaitThen.let_(TestnetDeployHelpers.deployFantomTestnetMarketUpgradeable("AVAX Market 2x", "2AVAX", longShort, staker, treasury, admin, paymentToken, fantomUsdPriceFeedAddress, deploymentArgs.deployments, namedAccounts), (function (param) {
                                            return TestnetDeployHelpers.deployFantomTestnetMarketUpgradeable("Ether Market 2x", "ETH2", longShort, staker, treasury, admin, paymentToken, btcUSDPriceFeedAddress, deploymentArgs.deployments, namedAccounts);
                                          }));
                            }));
              }));
}

exports.btcUSDPriceFeedAddress = btcUSDPriceFeedAddress;
exports.ethUSDPriceFeedAddress = ethUSDPriceFeedAddress;
exports.fantomUsdPriceFeedAddress = fantomUsdPriceFeedAddress;
exports.deployMasterMarkets = deployMasterMarkets;
/* btcUSDPriceFeedAddress Not a pure module */

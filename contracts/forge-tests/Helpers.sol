// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@float-capital/ds-test/src/test.sol";

import "../longShort/LongShortMaster.sol";
import "../longShort/LongShortSlave.sol";
import "../FloatCapital_v0.sol";
import "../Treasury_v0.sol";
import "../FloatToken.sol";
import "../staker/template/Staker.sol";
import "../MIA/SyntheticTokenUpgradeable.sol";
import "../GEMS.sol";
import "../mocks/LZEndpointMock.sol";

import "./Helpers.sol";

import "../mocks/ERC20Mock.sol";
import "../mocks/OracleManagerMock.sol";
import "../mocks/YieldManagerMock.sol";

import "hardhat/console.sol";

interface CheatCodes {
  function prank(address) external;

  function startPrank(address) external;

  function stopPrank() external;
}

contract Helpers is DSTest {
  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

  address constant DEPLOYER = address(1);
  address constant ADMIN = address(2);
  address constant DISCOUNT_SIGNER = address(3);

  //// MASTER
  LongShortMaster longShortM;
  FloatCapital_v0 floatCapitalM;
  Treasury_v0 treasuryM;
  FloatToken fltM;
  Staker stakerM;
  SyntheticTokenUpgradeableBase synthLongMarket1M;
  SyntheticTokenUpgradeableBase synthShortMarket1M;
  GEMS gemsM;
  ERC20MockWithPublicMint paymentTokenM;
  OracleManagerMock oracleManagerM;
  YieldManagerMock yieldManagerM;

  ///// SLAVE
  LongShortSlave longShortS;
  FloatCapital_v0 floatCapitalS;
  Treasury_v0 treasuryS;
  FloatToken fltS;
  Staker stakerS;
  SyntheticTokenUpgradeableBase synthLongMarket1S;
  SyntheticTokenUpgradeableBase synthShortMarket1S;
  GEMS gemsS;
  ERC20MockWithPublicMint paymentTokenS;
  OracleManagerMock oracleManagerS;
  YieldManagerMock yieldManagerS;

  LZEndpointMock endpointLZ_mock_masterChain;
  LZEndpointMock endpointLZ_mock_slaveChain;

  uint160 freshUserOffset; // using this allows each test to use fresh/new users on the current contracts
  address tempUser1;
  address tempUser2;
}

// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.12;

import "@float-capital/ds-test/src/test.sol";

import "../longShort/LongShortMaster.sol";
import "../longShort/LongShortSlave.sol";
import "../FloatCapital_v0.sol";
import "../Treasury_v0.sol";
import "../FloatToken.sol";
import "../MIA/SyntheticTokenUpgradeable.sol";
import "../GEMS.sol";

import "./Helpers.sol";

import "../mocks/ERC20Mock.sol";
import "../mocks/OracleManagerMock.sol";
import "../mocks/YieldManagerMock.sol";

import "hardhat/console.sol";

contract LongShortTest is Helpers {
  uint256 public marketFuturePriceIndexLength = 2; //longShortM.futurePriceIndexLength(marketIndex);

  uint16 constant masterChainId = 1;
  uint16 constant slaveChainId = 2;

  function setEverythingUpMaster() internal {
    // Deploy contracts
    cheats.startPrank(DEPLOYER); // deploy all contracts as deployer
    longShortM = new LongShortMaster();
    floatCapitalM = new FloatCapital_v0();
    treasuryM = new Treasury_v0();
    fltM = new FloatToken();
    synthLongMarket1M = new SyntheticTokenUpgradeableBase();
    synthShortMarket1M = new SyntheticTokenUpgradeableBase();
    gemsM = new GEMS();
    paymentTokenM = new ERC20MockWithPublicMint("Test Payment Token", "TPT");
    paymentTokenM.mintFor(1e22, DEPLOYER);
    paymentTokenM.mintFor(1e22, ADMIN);

    // Configure deployment

    fltM.initialize("TEST Float Token", "tFLT", address(stakerM));
    treasuryM.initialize(ADMIN, address(paymentTokenM), address(fltM), address(longShortM));
    gemsM.initialize(ADMIN, address(longShortM), address(stakerM));
    longShortM.initialize(
      ADMIN,
      address(
        987654321 /* token factory unused... */
      ),
      address(stakerM),
      address(gemsM)
    );

    // A few sanity tests (unimportant)
    oracleManagerM = new OracleManagerMock(ADMIN, 0);
    yieldManagerM = new YieldManagerMock(
      address(longShortM),
      address(treasuryM),
      address(paymentTokenM)
    );
    paymentTokenM.grantRole(paymentTokenM.MINTER_ROLE(), address(yieldManagerM));

    cheats.stopPrank();

    cheats.startPrank(ADMIN); // Work as admin for the rest

    paymentTokenM.approve(address(longShortM), ~uint256(0));
    uint32 latestMarket = uint32(longShortM.latestMarket()) + 1;

    synthLongMarket1M.initialize(
      "M1 MIA Long",
      "M1ML",
      address(longShortM),
      address(stakerM),
      latestMarket,
      true
    );
    synthShortMarket1M.initialize(
      "M1 MIA Short",
      "M1MS",
      address(longShortM),
      address(stakerM),
      latestMarket,
      false
    );

    longShortM.createNewSyntheticMarketExternalSyntheticTokens(
      "Test Market 1",
      "TM1",
      address(synthLongMarket1M),
      address(synthShortMarket1M),
      address(paymentTokenM),
      address(oracleManagerM),
      address(yieldManagerM)
    );

    longShortM.initializeMarket(
      latestMarket,
      /* initialMarketSeedForEachMarketSide */
      1e18,
      /* marketTreasurySplitGradient_e18 */
      1e18,
      /* marketLeverage */
      1e18
    );
    longShortM.setupCommunication(address(endpointLZ_mock_masterChain));
  }

  function setEverythingUpSlave() internal {
    // Deploy contracts
    cheats.startPrank(DEPLOYER); // deploy all contracts as deployer
    longShortS = new LongShortSlave();
    floatCapitalS = new FloatCapital_v0();
    treasuryS = new Treasury_v0();
    fltS = new FloatToken();
    synthLongMarket1S = new SyntheticTokenUpgradeableBase();
    synthShortMarket1S = new SyntheticTokenUpgradeableBase();
    gemsS = new GEMS();
    paymentTokenS = new ERC20MockWithPublicMint("Test Payment Token", "TPT");
    paymentTokenM.mintFor(1e22, DEPLOYER);
    paymentTokenM.mintFor(1e22, ADMIN);

    // Configure deployment

    fltM.initialize("TEST Float Token", "tFLT", address(stakerM));
    treasuryM.initialize(ADMIN, address(paymentTokenM), address(fltM), address(longShortM));
    gemsM.initialize(ADMIN, address(longShortM), address(stakerM));
    longShortM.initialize(
      ADMIN,
      address(
        987654321 /* token factory unused... */
      ),
      address(stakerM),
      address(gemsM)
    );
    stakerM.initialize(
      ADMIN,
      address(longShortM),
      address(fltM),
      address(treasuryM),
      address(floatCapitalM),
      address(DISCOUNT_SIGNER),
      250000000000000000,
      address(gemsM)
    );

    // A few sanity tests (unimportant)
    oracleManagerS = new OracleManagerMock(ADMIN, 0);
    yieldManagerS = new YieldManagerMock(
      address(longShortM),
      address(treasuryM),
      address(paymentTokenM)
    );
    paymentTokenM.grantRole(paymentTokenM.MINTER_ROLE(), address(yieldManagerM));

    cheats.stopPrank();

    cheats.startPrank(ADMIN); // Work as admin for the rest

    paymentTokenM.approve(address(longShortM), ~uint256(0));
    uint32 latestMarket = uint32(longShortM.latestMarket()) + 1;

    synthLongMarket1M.initialize(
      "M1 MIA Long",
      "M1ML",
      address(longShortM),
      address(stakerM),
      latestMarket,
      true
    );
    synthShortMarket1M.initialize(
      "M1 MIA Short",
      "M1MS",
      address(longShortM),
      address(stakerM),
      latestMarket,
      false
    );

    longShortM.createNewSyntheticMarketExternalSyntheticTokens(
      "Test Market 1",
      "TM1",
      address(synthLongMarket1M),
      address(synthShortMarket1M),
      address(paymentTokenM),
      address(oracleManagerM),
      address(yieldManagerM)
    );

    longShortM.initializeMarket(
      latestMarket,
      /* initialMarketSeedForEachMarketSide */
      1e18,
      /* marketTreasurySplitGradient_e18 */
      1e18,
      /* marketLeverage */
      1e18
    );
    longShortS.setupCommunication(address(endpointLZ_mock_slaveChain));
  }

  constructor() {
    endpointLZ_mock_masterChain = new LZEndpointMock(masterChainId);
    endpointLZ_mock_slaveChain = new LZEndpointMock(slaveChainId);

    setEverythingUpMaster();
    setEverythingUpSlave();

    longShortS.setupMarketCommunication(
      1,
      masterChainId,
      address(longShortM),
      longShortM.latestActionIndex(1) // MAKE VERY SURE THIS IS THE LATEST VALUE!
    );
  }

  function setUp() public {
    // setEverythingUp(); // TODO: once you are finished developing this, put it back in the contructor. - it is only here for the luxuary of stack traces (which don't apear from the constructor)
    freshUserOffset += 10;
    tempUser1 = address(freshUserOffset);
    tempUser2 = address(freshUserOffset + 1);

    cheats.startPrank(tempUser1); // Work as admin for the rest

    paymentTokenM.mint(5e21);
    paymentTokenM.approve(address(longShortM), ~uint256(0));

    cheats.startPrank(tempUser2); // Work as admin for the rest
    paymentTokenM.mint(5e21);
    paymentTokenM.approve(address(longShortM), ~uint256(0));
  }

  // TODO - do similar update for other actions.
  function _testCreateMinthNthPriceAction() public {
    uint32 marketIndex = 1;
    uint256 marketUpdateIndexBefore = longShortM.marketUpdateIndex(marketIndex);
    uint256 amountPaymentTokenToMint = 3e20;

    cheats.startPrank(tempUser1); // Work as first user for the rest

    longShortM.mintLongNextPrice(marketIndex, amountPaymentTokenToMint);

    // cleanup the test
    OracleManagerMock(oracleManagerM).setPrice(12e17);

    longShortM.updateSystemState(marketIndex);
    longShortM.executeOutstandingNextPriceSettlementsUser(tempUser1, marketIndex);

    OracleManagerMock(oracleManagerM).setPrice(151e16);

    console.log("123 - Before");
    longShortM.updateSystemState(marketIndex);
    console.log("123 - After");

    uint256 user1BalanceBefore = synthLongMarket1M.balanceOf(tempUser1);
    uint256 user2BalanceBefore = synthLongMarket1M.balanceOf(tempUser2);
    longShortM.executeOutstandingNextPriceSettlementsUser(tempUser1, marketIndex);
    longShortM.executeOutstandingNextPriceSettlementsUser(tempUser2, marketIndex);

    uint256 user1BalanceAfter = synthLongMarket1M.balanceOf(tempUser1);
    uint256 user2BalanceAfter = synthLongMarket1M.balanceOf(tempUser2);
  }
}

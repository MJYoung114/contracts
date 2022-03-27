// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.13;

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
    paymentTokenS.mintFor(1e22, DEPLOYER);
    paymentTokenS.mintFor(1e22, ADMIN);

    // Configure deployment

    fltS.initialize("TEST Float Token", "tFLT", address(stakerS));
    treasuryS.initialize(ADMIN, address(paymentTokenS), address(fltS), address(longShortS));
    gemsS.initialize(ADMIN, address(longShortS), address(stakerS));
    longShortS.initialize(
      ADMIN,
      address(
        987654321 /* token factory unused... */
      ),
      address(stakerS),
      address(gemsS)
    );

    // A few sanity tests (unimportant)
    oracleManagerS = new OracleManagerMock(ADMIN, 0);
    yieldManagerS = new YieldManagerMock(
      address(longShortS),
      address(treasuryS),
      address(paymentTokenS)
    );
    paymentTokenS.grantRole(paymentTokenS.MINTER_ROLE(), address(yieldManagerS));

    cheats.stopPrank();

    cheats.startPrank(ADMIN); // Work as admin for the rest

    paymentTokenS.approve(address(longShortS), ~uint256(0));
    uint32 latestMarket = uint32(longShortS.latestMarket()) + 1;

    synthLongMarket1S.initialize(
      "M1 MIA Long",
      "M1ML",
      address(longShortS),
      address(stakerS),
      latestMarket,
      true
    );
    synthShortMarket1S.initialize(
      "M1 MIA Short",
      "M1MS",
      address(longShortS),
      address(stakerS),
      latestMarket,
      false
    );

    longShortS.createNewSyntheticMarketExternalSyntheticTokens(
      "Test Market 1",
      "TM1",
      address(synthLongMarket1S),
      address(synthShortMarket1S),
      address(paymentTokenS),
      address(oracleManagerS),
      address(yieldManagerS)
    );

    longShortS.initializeMarket(
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

  function fConstructor() internal {
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
    uint16[] memory slaveChainIds = new uint16[](1);
    slaveChainIds[0] = slaveChainId;
    address[] memory longShorts = new address[](1);
    longShorts[0] = address(longShortS);
    longShortM.setupMarketCommunication(1, slaveChainIds, longShorts);

    /// Setup the LZ endpoints:
    endpointLZ_mock_masterChain.setDestLzEndpoint(
      address(longShortS),
      address(endpointLZ_mock_slaveChain)
    );
    endpointLZ_mock_slaveChain.setDestLzEndpoint(
      address(longShortM),
      address(endpointLZ_mock_masterChain)
    );
  }

  constructor() {}

  function setUp() public {
    fConstructor();
    // setEverythingUp(); // TODO: once you are finished developing this, put it back in the contructor.
    //                       - it is only here for the luxuary of stack traces (which don't apear from the constructor)
    freshUserOffset += 10;
    tempUser1 = address(freshUserOffset);
    tempUser2 = address(freshUserOffset + 1);

    cheats.startPrank(tempUser1); // Work as admin for the rest

    paymentTokenM.mint(5e21);
    paymentTokenM.approve(address(longShortM), ~uint256(0));
    paymentTokenS.mint(5e21);
    paymentTokenS.approve(address(longShortS), ~uint256(0));

    cheats.startPrank(tempUser2); // Work as admin for the rest
    paymentTokenM.mint(5e21);
    paymentTokenM.approve(address(longShortM), ~uint256(0));
    paymentTokenS.mint(5e21);
    paymentTokenS.approve(address(longShortS), ~uint256(0));
  }

  function testFullContractFlow() public {
    uint32 marketIndex = 1;
    uint256 amountPaymentTokenToMint = 3e20;

    cheats.startPrank(tempUser1); // Work as first user for the rest

    longShortM.mintLongNextPrice(marketIndex, amountPaymentTokenToMint);
    longShortS.mintShortNextPrice(marketIndex, amountPaymentTokenToMint);

    // cleanup the test
    OracleManagerMock(oracleManagerM).setPrice(12e17);

    uint256 user1BalanceBefore = synthLongMarket1M.balanceOf(tempUser1);
    uint256 user2BalanceBefore = synthShortMarket1S.balanceOf(tempUser1);

    longShortM.updateSystemState(marketIndex);

    longShortM.executeOutstandingNextPriceSettlementsUser(tempUser1, marketIndex);
    longShortS.executeOutstandingNextPriceSettlementsUser(tempUser1, marketIndex);

    uint256 user1BalanceAfter = synthLongMarket1M.balanceOf(tempUser1);
    uint256 user2BalanceAfter = synthShortMarket1S.balanceOf(tempUser1);
    console.log(user1BalanceBefore, user2BalanceBefore);
    console.log(user1BalanceAfter, user2BalanceAfter);
  }
}

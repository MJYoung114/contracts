// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.13;

import "../longShort/template/LongShort.sol";

/*
NOTE: This contract is for testing purposes only!
*/

contract LongShortInternalStateSetters is LongShort {
  function setInitializeMarketParams(
    uint32 marketIndex,
    bool marketIndexValue,
    uint32 _latestMarket,
    address _staker,
    address longAddress,
    address shortAddress
  ) public {
    latestMarket = _latestMarket;
    marketExists[marketIndex] = marketIndexValue;
    syntheticTokens[marketIndex][
      true /*short*/
    ] = (longAddress);
    syntheticTokens[marketIndex][
      false /*short*/
    ] = (shortAddress);
  }

  function setMarketExistsMulti(uint32[] calldata marketIndexes) external {
    uint256 length = marketIndexes.length;
    for (uint256 i = 0; i < length; i++) {
      marketExists[marketIndexes[i]] = true;
    }
  }

  function set_updateSystemStateInternalGlobals(
    uint32 marketIndex,
    uint256 _latestUpdateIndexForMarket,
    uint128 syntheticTokenPrice_inPaymentTokens_long,
    uint128 syntheticTokenPrice_inPaymentTokens_short,
    int256 _assetPrice,
    uint128 longValue,
    uint128 shortValue,
    address oracleManager,
    address _staker,
    address synthLong,
    address synthShort,
    uint256 stakerNextPrice_currentUpdateIndex
  ) public {
    marketExists[marketIndex] = true;
    marketUpdateIndex[marketIndex] = _latestUpdateIndexForMarket;
    syntheticToken_priceSnapshot[marketIndex][
      _latestUpdateIndexForMarket
    ] = SynthPriceInPaymentToken(
      syntheticTokenPrice_inPaymentTokens_long,
      syntheticTokenPrice_inPaymentTokens_short
    );

    marketSideValueInPaymentToken[marketIndex] = MarketSideValueInPaymentToken(
      longValue,
      shortValue
    );

    assetPrice[marketIndex] = _assetPrice;
    oracleManagers[marketIndex] = oracleManager;

    syntheticTokens[marketIndex][true] = synthLong;
    syntheticTokens[marketIndex][false] = synthShort;

    userNextPrice_currentUpdateIndex[marketIndex][_staker] = stakerNextPrice_currentUpdateIndex;
  }

  function setGetUsersConfirmedButNotSettledBalanceGlobals(
    uint32 marketIndex,
    address user,
    bool isLong,
    uint256 _userNextPrice_currentUpdateIndex,
    uint256 _marketUpdateIndex,
    uint256 _userNextPrice_paymentToken_depositAmount_isLong,
    uint128 _syntheticToken_priceSnapshot_long,
    uint128 _syntheticToken_priceSnapshot_short,
    uint256 _userNextPrice_syntheticToken_toShiftAwayFrom_marketSide_notIsLong
  ) external {
    marketExists[marketIndex] = true;
    userNextPrice_currentUpdateIndex[marketIndex][user] = _userNextPrice_currentUpdateIndex;
    marketUpdateIndex[marketIndex] = _marketUpdateIndex;

    userNextPrice_paymentToken_depositAmount[marketIndex][isLong][
      user
    ] = _userNextPrice_paymentToken_depositAmount_isLong;
    userNextPrice_paymentToken_depositAmount[marketIndex][!isLong][user] = 0; // reset other side for good measure

    syntheticToken_priceSnapshot[marketIndex][
      _userNextPrice_currentUpdateIndex
    ] = SynthPriceInPaymentToken(
      _syntheticToken_priceSnapshot_long,
      _syntheticToken_priceSnapshot_short
    );

    userNextPrice_syntheticToken_toShiftAwayFrom_marketSide[marketIndex][!isLong][
      user
    ] = _userNextPrice_syntheticToken_toShiftAwayFrom_marketSide_notIsLong;
    userNextPrice_syntheticToken_toShiftAwayFrom_marketSide[marketIndex][isLong][user] = 0; // reset other side for good measure
  }

  function setPerformOutstandingBatchedSettlementsGlobals(
    uint32 marketIndex,
    uint256 batched_amountPaymentToken_depositLong,
    uint256 batched_amountPaymentToken_depositShort,
    uint256 batched_amountSyntheticToken_redeemLong,
    uint256 batched_amountSyntheticToken_redeemShort,
    uint256 batchedAmountSyntheticTokenToShiftFromLong,
    uint256 batchedAmountSyntheticTokenToShiftFromShort
  ) external {
    batched_amountPaymentToken_deposit[marketIndex][true] = batched_amountPaymentToken_depositLong;
    batched_amountPaymentToken_deposit[marketIndex][
      false
    ] = batched_amountPaymentToken_depositShort;
    batched_amountSyntheticToken_redeem[marketIndex][
      true
    ] = batched_amountSyntheticToken_redeemLong;
    batched_amountSyntheticToken_redeem[marketIndex][
      false
    ] = batched_amountSyntheticToken_redeemShort;
    batched_amountSyntheticToken_toShiftAwayFrom_marketSide[marketIndex][
      true
    ] = batchedAmountSyntheticTokenToShiftFromLong;
    batched_amountSyntheticToken_toShiftAwayFrom_marketSide[marketIndex][
      false
    ] = batchedAmountSyntheticTokenToShiftFromShort;
  }

  function setHandleChangeInSyntheticTokensTotalSupplyGlobals(
    uint32 marketIndex,
    address longSyntheticToken,
    address shortSyntheticToken
  ) external {
    syntheticTokens[marketIndex][true] = longSyntheticToken;
    syntheticTokens[marketIndex][false] = shortSyntheticToken;
  }

  function setRedeemNextPriceGlobals(
    uint32 marketIndex,
    uint256 _marketUpdateIndex,
    address syntheticToken,
    bool isLong
  ) external {
    marketUpdateIndex[marketIndex] = _marketUpdateIndex;
    syntheticTokens[marketIndex][isLong] = syntheticToken;
  }

  function setShiftNextPriceGlobals(
    uint32 marketIndex,
    uint256 _marketUpdateIndex,
    address syntheticTokenShiftedFrom,
    bool isShiftFromLong
  ) external {
    marketUpdateIndex[marketIndex] = _marketUpdateIndex;
    syntheticTokens[marketIndex][isShiftFromLong] = syntheticTokenShiftedFrom;
  }

  function setExecuteOutstandingNextPriceMintsGlobals(
    uint32 marketIndex,
    address user,
    bool isLong,
    address syntheticToken,
    uint256 _userNextPrice_syntheticToken_redeemAmount,
    uint256 _userNextPrice_currentUpdateIndex,
    uint128 _syntheticToken_priceSnapshot
  ) external {
    userNextPrice_paymentToken_depositAmount[marketIndex][isLong][
      user
    ] = _userNextPrice_syntheticToken_redeemAmount;
    userNextPrice_currentUpdateIndex[marketIndex][user] = _userNextPrice_currentUpdateIndex;

    SynthPriceInPaymentToken storage priceSnapshot = syntheticToken_priceSnapshot[marketIndex][
      _userNextPrice_currentUpdateIndex
    ];
    if (isLong) {
      priceSnapshot.price_long = _syntheticToken_priceSnapshot;
    } else {
      priceSnapshot.price_short = _syntheticToken_priceSnapshot;
    }
    syntheticTokens[marketIndex][isLong] = syntheticToken;
  }

  function setExecuteOutstandingNextPriceRedeemsGlobals(
    uint32 marketIndex,
    address user,
    bool isLong,
    address yieldManager,
    uint256 _userNextPrice_syntheticToken_redeemAmount,
    uint256 _userNextPrice_currentUpdateIndex,
    uint128 _syntheticToken_priceSnapshot
  ) external {
    userNextPrice_syntheticToken_redeemAmount[marketIndex][isLong][
      user
    ] = _userNextPrice_syntheticToken_redeemAmount;
    userNextPrice_currentUpdateIndex[marketIndex][user] = _userNextPrice_currentUpdateIndex;
    SynthPriceInPaymentToken storage priceSnapshot = syntheticToken_priceSnapshot[marketIndex][
      _userNextPrice_currentUpdateIndex
    ];
    if (isLong) {
      priceSnapshot.price_long = _syntheticToken_priceSnapshot;
    } else {
      priceSnapshot.price_short = _syntheticToken_priceSnapshot;
    }
    yieldManagers[marketIndex] = yieldManager;
  }

  function setExecuteOutstandingNextPriceTokenShiftsGlobals(
    uint32 marketIndex,
    address user,
    bool isShiftFromLong,
    address syntheticTokenShiftedTo,
    uint256 _userNextPrice_syntheticToken_toShiftAwayFrom_marketSide,
    uint256 _userNextPrice_currentUpdateIndex,
    uint128 _syntheticToken_priceSnapshotShiftedFrom,
    uint128 _syntheticToken_priceSnapshotShiftedTo
  ) external {
    userNextPrice_syntheticToken_toShiftAwayFrom_marketSide[marketIndex][isShiftFromLong][
      user
    ] = _userNextPrice_syntheticToken_toShiftAwayFrom_marketSide;
    userNextPrice_currentUpdateIndex[marketIndex][user] = _userNextPrice_currentUpdateIndex;
    SynthPriceInPaymentToken storage priceSnapshot = syntheticToken_priceSnapshot[marketIndex][
      _userNextPrice_currentUpdateIndex
    ];
    if (isShiftFromLong) {
      priceSnapshot.price_long = _syntheticToken_priceSnapshotShiftedFrom;
      priceSnapshot.price_short = _syntheticToken_priceSnapshotShiftedTo;
    } else {
      priceSnapshot.price_short = _syntheticToken_priceSnapshotShiftedFrom;
      priceSnapshot.price_long = _syntheticToken_priceSnapshotShiftedTo;
    }
    syntheticTokens[marketIndex][!isShiftFromLong] = syntheticTokenShiftedTo;
  }

  function setExecuteOutstandingNextPriceSettlementsGlobals(
    uint32 marketIndex,
    address user,
    uint256 _userNextPrice_currentUpdateIndex,
    uint256 _marketUpdateIndex
  ) external {
    userNextPrice_currentUpdateIndex[marketIndex][user] = _userNextPrice_currentUpdateIndex;
    marketUpdateIndex[marketIndex] = _marketUpdateIndex;
  }

  function setClaimAndDistributeYieldThenRebalanceMarketGlobals(
    uint32 marketIndex,
    uint128 _marketSideValueInPaymentTokenLong,
    uint128 _marketSideValueInPaymentTokenShort,
    address yieldManager
  ) external {
    marketSideValueInPaymentToken[marketIndex] = MarketSideValueInPaymentToken(
      _marketSideValueInPaymentTokenLong,
      _marketSideValueInPaymentTokenShort
    );
    yieldManagers[marketIndex] = yieldManager;
  }

  function setDepositFundsGlobals(
    uint32 marketIndex,
    address paymentToken,
    address yieldManager
  ) external {
    paymentTokens[marketIndex] = paymentToken;
    yieldManagers[marketIndex] = yieldManager;
  }
}

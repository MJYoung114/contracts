// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.12;

import "./template/LongShort.sol";

library Types {
  struct SlavePushMessage {
    uint256 actionIndex;
    uint256 depositAmount;
    uint256 redeemAmount;
    uint32 marketIndex;
    bool isLong;
  }

  struct MasterPushMessage {
    uint256 latestProcessedActionIndex;
    uint256 marketIndex;
    uint256 currentUpdateIndex;
    LongShort.SynthPriceInPaymentToken paymentTokens;
  }
}

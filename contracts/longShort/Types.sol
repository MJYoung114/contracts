// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.10;

import "./template/LongShort.sol";

library Types {
  struct SlavePushMessage {
    uint256 actionIndex;
    uint256 depositAmount;
    uint256 redeemAmount;
    uint256 shiftAwayAmount;
    uint32 marketIndex;
    bool isLong;
  }

  struct PushYield {
    uint32 marketIndex;
    uint256 amount;
  }

  struct MasterPushMessage {
    uint256 latestProcessedActionIndex;
    uint256 marketIndex;
    LongShort.SynthPriceInPaymentToken paymentTokens;
  }
}

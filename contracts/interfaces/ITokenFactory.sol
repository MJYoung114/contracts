// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.12;

interface ITokenFactory {
  function createSyntheticToken(
    string calldata syntheticName,
    string calldata syntheticSymbol,
    uint32 marketIndex,
    bool isLong
  ) external returns (address);
}

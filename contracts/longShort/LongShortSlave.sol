// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "./Types.sol";

import "../interfaces/ITokenFactory.sol";
import "../interfaces/ISyntheticToken.sol";
import "../interfaces/IStaker.sol";
import "../interfaces/ILongShort.sol";
import "../interfaces/IYieldManager.sol";
import "../interfaces/IOracleManager.sol";
import "../abstract/AccessControlledAndUpgradeable.sol";
import "../GEMS.sol";
import "./template/LongShort.sol";

import "@layerzerolabs/contracts/contracts/interfaces/ILayerZeroReceiver.sol";
import "@layerzerolabs/contracts/contracts/interfaces/ILayerZeroEndpoint.sol";

/**
 **** visit https://float.capital *****
 */

contract LongShortSlave is LongShort, ILayerZeroReceiver {
  /* DATA structure */
  mapping(uint32 => uint16) public masterChainId;
  mapping(uint32 => bytes) public masterChainLongShortAddressAsBytes;

  mapping(uint32 => uint256) public latestActionIndex;

  /* ══════ User specific ══════ */
  /// NOTE: we are blocking users from doing multiple actions in the same batch
  mapping(uint32 => mapping(address => uint256)) public userNextPrice_currentActionIndex;

  mapping(uint32 => mapping(uint256 => uint256)) public latestActionInLatestConfirmedBatch;

  ILayerZeroEndpoint public endpoint;

  // constructor mints tokens to the deployer
  /// NOTE: this is insecure still, need to ensure this is setup correctly. Ok for hackathon.
  function setupCommunication(address _layerZeroEndpoint) public adminOnly {
    endpoint = ILayerZeroEndpoint(_layerZeroEndpoint);
  }

  function setupMarketCommunication(
    uint32 marketIndex,
    uint16 _masterChainId,
    address masterChainLongShortAddress,
    uint256 _latestActionIndex // MAKE VERY SURE THIS IS THE LATEST VALUE!
  ) public adminOnly {
    // Get the latested update index here too!
    masterChainLongShortAddressAsBytes[marketIndex] = abi.encodePacked(masterChainLongShortAddress);
    masterChainId[marketIndex] = _masterChainId;
    latestActionIndex[marketIndex] = _latestActionIndex;
  }

  modifier noExistingActionsInBatch(uint32 marketIndex) {
    // For now disable multiple actions in batch
    require(
      userNextPrice_currentActionIndex[marketIndex][msg.sender] <=
        latestActionInLatestConfirmedBatch[marketIndex][marketUpdateIndex[marketIndex]],
      "can't have multiple actions in the same batch"
    );
    _;
  }

  function lzReceive(
    uint16 _srcChainId,
    bytes calldata _srcAddress,
    uint64 _nonce,
    bytes calldata _payload
  ) external override {
    Types.MasterPushMessage memory pushMessageReceived = abi.decode(
      _payload,
      (Types.MasterPushMessage)
    );

    uint32 marketIndex = pushMessageReceived.marketIndex;
    uint256 currentMarketIndex = pushMessageReceived.currentUpdateIndex;
    syntheticToken_priceSnapshot[marketIndex][currentMarketIndex] = pushMessageReceived
      .paymentTokens;

    marketUpdateIndex[marketIndex] = currentMarketIndex;
  }

  /// @notice Allows users to mint synthetic assets for a market. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @dev Called by external functions to mint either long or short. If a user mints multiple times before a price update, these are treated as a single mint.
  /// @param marketIndex An uint32 which uniquely identifies a market.
  /// @param amount Amount of payment tokens in that token's lowest denominationfor which to mint synthetic assets at next price.
  /// @param isLong Whether the mint is for a long or short synth.
  function _mintNextPrice(
    uint32 marketIndex,
    uint256 amount,
    bool isLong
  )
    internal
    virtual
    override
    updateSystemStateMarketAndExecuteOutstandingNextPriceSettlements(msg.sender, marketIndex)
    noExistingActionsInBatch(marketIndex)
    gemCollecting
  {
    require(amount > 0, "Mint amount == 0");

    _transferPaymentTokensFromUserToYieldManager(marketIndex, amount);

    batched_amountPaymentToken_deposit[marketIndex][isLong] += amount;
    userNextPrice_paymentToken_depositAmount[marketIndex][isLong][msg.sender] += amount;
    // uint256 nextUpdateIndex = marketUpdateIndex[marketIndex] + 1;
    // userNextPrice_currentUpdateIndex[marketIndex][msg.sender] = nextUpdateIndex;

    ++latestActionIndex[marketIndex];

    userNextPrice_currentActionIndex[marketIndex][msg.sender] = latestActionIndex[marketIndex];

    Types.SlavePushMessage memory pushMessage = Types.SlavePushMessage(
      latestActionIndex[marketIndex],
      amount,
      0,
      marketIndex,
      isLong
    );

    bytes memory payload = abi.encode(pushMessage);
    uint16 destChainId = masterChainId[marketIndex];

    endpoint.send{value: msg.value}(
      // @param _dstChainId - the destination chain identifier
      destChainId,
      // @param _destination - the address on destination chain (in bytes). address length/format may vary by chains
      masterChainLongShortAddressAsBytes[marketIndex],
      // @param _payload - a custom bytes payload to send to the destination contract
      payload,
      // @param _refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
      payable(msg.sender),
      // @param _zroPaymentAddress - the address of the ZRO token holder who would pay for the transaction
      address(0),
      // @param _adapterParams - parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination
      bytes("")
    );

    emit NextPriceDeposit(marketIndex, isLong, amount, msg.sender, latestActionIndex[marketIndex]);
  }

  /// @notice Allows users to mint long synthetic assets for a market. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @param marketIndex An uint32 which uniquely identifies a market.
  /// @param amount Amount of payment tokens in that token's lowest denominationfor which to mint synthetic assets at next price.
  function mintLongNextPrice(uint32 marketIndex, uint256 amount) external override {
    _mintNextPrice(marketIndex, amount, true);
  }

  /// @notice Allows users to mint short synthetic assets for a market. To prevent front-running these mints are executed on the next price update from the oracle.
  /// @param marketIndex An uint32 which uniquely identifies a market.
  /// @param amount Amount of payment tokens in that token's lowest denominationfor which to mint synthetic assets at next price.
  function mintShortNextPrice(uint32 marketIndex, uint256 amount) external override {
    _mintNextPrice(marketIndex, amount, false);
  }

  function _executeOutstandingNextPriceMints(
    uint32 marketIndex,
    address user,
    bool isLong
  ) internal virtual override {
    uint256 currentPaymentTokenDepositAmount = userNextPrice_paymentToken_depositAmount[
      marketIndex
    ][isLong][user];
    if (currentPaymentTokenDepositAmount > 0) {
      userNextPrice_paymentToken_depositAmount[marketIndex][isLong][user] = 0;
      uint256 amountSyntheticTokensToMintToUser = _getAmountSyntheticToken(
        currentPaymentTokenDepositAmount,
        get_syntheticToken_priceSnapshot_side(
          marketIndex,
          isLong,
          userNextPrice_currentUpdateIndex[marketIndex][user]
        )
      );
      ISyntheticToken(syntheticTokens[marketIndex][isLong]).mint(
        user,
        amountSyntheticTokensToMintToUser
      );
    }
  }

  function _executeOutstandingNextPriceRedeems(
    uint32 marketIndex,
    address user,
    bool isLong
  ) internal virtual override {
    uint256 currentSyntheticTokenRedemptions = userNextPrice_syntheticToken_redeemAmount[
      marketIndex
    ][isLong][user];
    if (currentSyntheticTokenRedemptions > 0) {
      userNextPrice_syntheticToken_redeemAmount[marketIndex][isLong][user] = 0;
      uint256 amountPaymentToken_toRedeem = _getAmountPaymentToken(
        currentSyntheticTokenRedemptions,
        get_syntheticToken_priceSnapshot_side(
          marketIndex,
          isLong,
          userNextPrice_currentUpdateIndex[marketIndex][user]
        )
      );

      ISyntheticToken(syntheticTokens[marketIndex][isLong]).burn(currentSyntheticTokenRedemptions);

      IYieldManager(yieldManagers[marketIndex]).transferPaymentTokensToUser(
        user,
        amountPaymentToken_toRedeem
      );
    }
  }

  /// @notice Updates the value of the long and short sides to account for latest oracle price updates
  /// and batches all next price actions.
  /// @dev To prevent front-running only executes on price change from an oracle.
  /// We assume the function will be called for each market at least once per price update.
  /// Note Even if not called on every price update, this won't affect security, it will only affect how closely
  /// the synthetic asset actually tracks the underlying asset.
  /// @param marketIndex The market index for which to update.
  function _updateSystemStateInternal(uint32 marketIndex)
    internal
    virtual
    override
    requireMarketExists(marketIndex)
  {
    // If a negative int is return this should fail.
    int256 newAssetPrice = IOracleManager(oracleManagers[marketIndex]).updatePrice();

    uint256 currentMarketIndex = marketUpdateIndex[marketIndex];

    bool assetPriceHasChanged = assetPrice[marketIndex] != newAssetPrice;

    if (assetPriceHasChanged) {
      MarketSideValueInPaymentToken
        storage currentMarketSideValueInPaymentToken = marketSideValueInPaymentToken[marketIndex];
      // Claiming and distributing the yield
      uint256 newLongPoolValue = currentMarketSideValueInPaymentToken.value_long;
      uint256 newShortPoolValue = currentMarketSideValueInPaymentToken.value_short;

      uint256 syntheticTokenPrice_inPaymentTokens_long = _getSyntheticTokenPrice(
        newLongPoolValue,
        ISyntheticToken(syntheticTokens[marketIndex][true]).totalSupply()
      );
      uint256 syntheticTokenPrice_inPaymentTokens_short = _getSyntheticTokenPrice(
        newShortPoolValue,
        ISyntheticToken(syntheticTokens[marketIndex][false]).totalSupply()
      );

      assetPrice[marketIndex] = newAssetPrice;

      currentMarketIndex++;
      marketUpdateIndex[marketIndex] = currentMarketIndex;

      syntheticToken_priceSnapshot[marketIndex][currentMarketIndex] = SynthPriceInPaymentToken(
        SafeCast.toUint128(syntheticTokenPrice_inPaymentTokens_long),
        SafeCast.toUint128(syntheticTokenPrice_inPaymentTokens_short)
      );

      (
        int256 long_changeInMarketValue_inPaymentToken,
        int256 short_changeInMarketValue_inPaymentToken
      ) = _batchConfirmOutstandingPendingActions(
          marketIndex,
          syntheticTokenPrice_inPaymentTokens_long,
          syntheticTokenPrice_inPaymentTokens_short
        );

      newLongPoolValue = uint256(
        int256(newLongPoolValue) + long_changeInMarketValue_inPaymentToken
      );
      newShortPoolValue = uint256(
        int256(newShortPoolValue) + short_changeInMarketValue_inPaymentToken
      );
      marketSideValueInPaymentToken[marketIndex] = MarketSideValueInPaymentToken(
        SafeCast.toUint128(newLongPoolValue),
        SafeCast.toUint128(newShortPoolValue)
      );

      emit SystemStateUpdated(
        marketIndex,
        currentMarketIndex,
        newAssetPrice,
        newLongPoolValue,
        newShortPoolValue,
        syntheticTokenPrice_inPaymentTokens_long,
        syntheticTokenPrice_inPaymentTokens_short
      );
    }
  }
}

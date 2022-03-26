// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.12;

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

contract LongShortMaster is LongShort, ILayerZeroReceiver {
  /* DATA structure */
  mapping(uint32 => uint16) public slaveChainId;
  mapping(uint32 => bytes) public slaveChainLongShortAddressAsBytes;
  address payable public payableSender;
  address payable public zroPaymentAddress;

  // mapping(uint32 => uint256) public marketUpdateIndex;
  mapping(uint32 => uint256) public latestActionIndex;

  mapping(uint32 => mapping(bool => uint256)) public slaveChainsTotalSupply;

  // mapping(uint32 => address) public paymentTokens;
  // mapping(uint32 => address) public yieldManagers;

  // mapping(uint32 => mapping(bool => address)) public syntheticTokens;

  // /// QUESTION: should this be in the master only?
  // struct MarketSideValueInPaymentToken {
  //   // this has a maximum size of `2^128=3.4028237e+38` units of payment token which is amply sufficient for our markets
  //   uint128 value_long;
  //   uint128 value_short;
  // }
  // mapping(uint32 => MarketSideValueInPaymentToken) public marketSideValueInPaymentToken;

  // struct SynthPriceInPaymentToken {
  //   // this has a maximum size of `2^128=3.4028237e+38` units of payment token which is amply sufficient for our markets
  //   uint128 price_long;
  //   uint128 price_short;
  // }
  // mapping(uint32 => mapping(uint256 => SynthPriceInPaymentToken))
  //   public syntheticToken_priceSnapshot;

  /* ══════ User specific ══════ */
  /// NOTE: we are blocking users from doing multiple actions in the same batch
  mapping(uint32 => mapping(address => uint256)) public userNextPrice_currentActionIndex;

  mapping(uint32 => mapping(uint256 => uint256)) public latestActionInNextExecutableBatch;

  mapping(uint32 => mapping(uint16 => mapping(bool => uint256)))
    public batched_slaves_amountPaymentToken_deposit;

  // mapping(uint32 => mapping(bool => mapping(address => uint256)))
  //   public userNextPrice_paymentToken_depositAmount;
  // mapping(uint32 => mapping(bool => mapping(address => uint256)))
  //   public userNextPrice_syntheticToken_redeemAmount;
  // mapping(uint32 => mapping(bool => mapping(address => uint256)))
  //   public userNextPrice_syntheticToken_toShiftAwayFrom_marketSide;

  ILayerZeroEndpoint public endpoint;

  // constructor mints tokens to the deployer
  /// NOTE: this is insecure still, need to ensure this is setup correctly. Ok for hackathon.
  function setupCommunication(address _layerZeroEndpoint) public adminOnly {
    endpoint = ILayerZeroEndpoint(_layerZeroEndpoint);
  }

  function lzReceive(
    uint16 _srcChainId,
    bytes calldata _srcAddress,
    uint64 _nonce,
    bytes calldata _payload
  ) external override {
    Types.SlavePushMessage memory pushMessageReceived = abi.decode(
      _payload,
      (Types.SlavePushMessage)
    );

    uint32 marketIndex = pushMessageReceived.marketIndex;
    //TODO breakdown with shift and redeem amounts
    if (pushMessageReceived.depositAmount > 0) {
      batched_amountPaymentToken_deposit[marketIndex][
        pushMessageReceived.isLong
      ] += pushMessageReceived.depositAmount;
    } else if (pushMessageReceived.redeemAmount > 0) {
      batched_amountSyntheticToken_redeem[marketIndex][
        pushMessageReceived.isLong
      ] += pushMessageReceived.redeemAmount;
    }

    uint256 nextPriceMarketUpdateIndex = marketUpdateIndex[marketIndex] + 1;
    latestActionInNextExecutableBatch[marketIndex][nextPriceMarketUpdateIndex] = pushMessageReceived
      .actionIndex;
  }

  function _sendUpdatedStateToSlave(uint32 marketIndex, uint256 currentUpdateIndex) internal {
    Types.MasterPushMessage memory pushMessage = Types.MasterPushMessage(
      latestActionInNextExecutableBatch[marketIndex][currentUpdateIndex],
      marketIndex,
      currentUpdateIndex,
      syntheticToken_priceSnapshot[marketIndex][currentUpdateIndex]
    );

    bytes memory payload = abi.encode(pushMessage);
    uint16 destChainId = slaveChainId[marketIndex];

    endpoint.send{value: msg.value}(
      // @param _dstChainId - the destination chain identifier
      destChainId,
      // @param _destination - the address on destination chain (in bytes). address length/format may vary by chains
      slaveChainLongShortAddressAsBytes[marketIndex],
      // @param _payload - a custom bytes payload to send to the destination contract
      payload,
      // @param _refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
      payable(msg.sender),
      // @param _zroPaymentAddress - the address of the ZRO token holder who would pay for the transaction
      address(0),
      // @param _adapterParams - parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination
      bytes("")
    );
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
  // gemCollecting
  {
    require(amount > 0, "Mint amount == 0");
    // TODO: add back
    _transferPaymentTokensFromUserToYieldManager(marketIndex, amount);

    batched_amountPaymentToken_deposit[marketIndex][isLong] += amount;
    userNextPrice_paymentToken_depositAmount[marketIndex][isLong][msg.sender] += amount;
    uint256 nextUpdateIndex = marketUpdateIndex[marketIndex] + 1;
    userNextPrice_currentUpdateIndex[marketIndex][msg.sender] = nextUpdateIndex;

    emit NextPriceDeposit(marketIndex, isLong, amount, msg.sender, nextUpdateIndex);
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
        ISyntheticToken(syntheticTokens[marketIndex][true]).totalSupply() +
          slaveChainsTotalSupply[marketIndex][true]
      );
      uint256 syntheticTokenPrice_inPaymentTokens_short = _getSyntheticTokenPrice(
        newShortPoolValue,
        ISyntheticToken(syntheticTokens[marketIndex][false]).totalSupply() +
          slaveChainsTotalSupply[marketIndex][false]
      );

      assetPrice[marketIndex] = newAssetPrice;

      currentMarketIndex++;
      marketUpdateIndex[marketIndex] = currentMarketIndex;

      syntheticToken_priceSnapshot[marketIndex][currentMarketIndex] = SynthPriceInPaymentToken(
        SafeCast.toUint128(syntheticTokenPrice_inPaymentTokens_long),
        SafeCast.toUint128(syntheticTokenPrice_inPaymentTokens_short)
      );

      _sendUpdatedStateToSlave(marketIndex, currentMarketIndex);

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

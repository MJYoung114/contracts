// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

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
    SynthPriceInPaymentToken paymentTokens;
  }

  ILayerZeroEndpoint public endpoint;

  // constructor mints tokens to the deployer
  /// NOTE: this is insecure still, need to ensure this is setup correctly. Ok for hackathon.
  function setupCommunication(address _layerZeroEndpoint) public adminOnly {
    endpoint = ILayerZeroEndpoint(_layerZeroEndpoint);
  }

  function setupMarketCommunication(uint32 marketIndex, address masterChainLongShortAddress)
    public
    adminOnly
  {
    // Get the latested update index here too!
    masterChainLongShortAddressAsBytes[marketIndex] = bytes(masterChainLongShortAddress);
  }

  modifier noExistingActionsInBatch(uint32 marketIndex) {
    // For now disable multiple actions in batch
    require(
      userNextPrice_currentActionIndex[marketIndex][msg.sender] <=
        latestActionInLatestConfirmedBatch[marketIndex][marketUpdateIndex[marketIndex]],
      "can't have multiple actions in the same batch"
    );
  }

  function lzReceive(
    uint16 _srcChainId,
    bytes calldata _srcAddress,
    uint64 _nonce,
    bytes calldata _payload
  ) external override {}

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
    // updateSystemStateMarketAndExecuteOutstandingNextPriceSettlements(msg.sender, marketIndex)
    gemCollecting
  {
    require(amount > 0, "Mint amount == 0");

    _transferPaymentTokensFromUserToYieldManager(marketIndex, amount);

    userNextPrice_paymentToken_depositAmount[marketIndex][isLong][msg.sender] += amount;
    // uint256 nextUpdateIndex = marketUpdateIndex[marketIndex] + 1;
    // userNextPrice_currentUpdateIndex[marketIndex][msg.sender] = nextUpdateIndex;

    ++latestActionIndex[marketIndex];

    userNextPrice_currentActionIndex[marketIndex][msg.sender] = latestActionIndex[marketIndex];

    SlavePushMessage memory pushMessage = SlavePushMessage(
      latestActionIndex[marketIndex],
      amount,
      0,
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
}
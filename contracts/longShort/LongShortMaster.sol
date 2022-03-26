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
  address payable public payableSender;
  address payable public zroPaymentAddress;

  // mapping(uint32 => uint256) public marketUpdateIndex;
  mapping(uint32 => uint256) public latestActionIndex;

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

  mapping(uint32 => mapping(uint256 => uint256)) public latestActionInLatestConfirmedBatch;

  // mapping(uint32 => mapping(bool => mapping(address => uint256)))
  //   public userNextPrice_paymentToken_depositAmount;
  // mapping(uint32 => mapping(bool => mapping(address => uint256)))
  //   public userNextPrice_syntheticToken_redeemAmount;
  // mapping(uint32 => mapping(bool => mapping(address => uint256)))
  //   public userNextPrice_syntheticToken_toShiftAwayFrom_marketSide;

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
  // gemCollecting
  {
    require(amount > 0, "Mint amount == 0");
    // TODO: add back
    _transferPaymentTokensFromUserToYieldManager(marketIndex, amount);

    userNextPrice_paymentToken_depositAmount[marketIndex][isLong][msg.sender] += amount;
    uint256 nextUpdateIndex = marketUpdateIndex[marketIndex] + 1;
    userNextPrice_currentUpdateIndex[marketIndex][msg.sender] = nextUpdateIndex;

    ++latestActionIndex[marketIndex];

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

    // @notice send a LayerZero message to the specified address at a LayerZero endpoint.
    // @param _dstChainId - the destination chain identifier
    // @param _destination - the address on destination chain (in bytes). address length/format may vary by chains
    // @param _payload - a custom bytes payload to send to the destination contract
    // @param _refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
    // @param _zroPaymentAddress - the address of the ZRO token holder who would pay for the transaction
    // @param _adapterParams - parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination
    // function send(uint16 _dstChainId, bytes calldata _destination, bytes calldata _payload, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) external payable;
    endpoint.send{value: msg.value}(
      destChainId,
      masterChainLongShortAddressAsBytes[marketIndex],
      payload,
      payableSender,
      zroPaymentAddress,
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

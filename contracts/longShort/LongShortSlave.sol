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

import "@layerzerolabs/contracts/contracts/interfaces/ILayerZeroReceiver.sol";
import "@layerzerolabs/contracts/contracts/interfaces/ILayerZeroEndpoint.sol";

/*
////// template

contract Example is ILayerZeroReceiver {

    // the LayerZero endpoint address
    ILayerZeroEndpoint public endpoint;

    constructor(address _endpoint)  {
        endpoint = ILayerZeroEndpoint(_endpoint);
    }
    
    // Use the endpoint to send a message to another chain.
    // This function should be payable, and you should send 
    // additional gas to make sure the message delivery is paid for
    // on the destination chain. 
    function sendYourMessage(uint16 _chainId, bytes calldata _endpoint) public payable {
        endpoint.send{value:msg.value}(_chainId, _endpoint, bytes(""), msg.sender, address(0x0), bytes(""));
    }

    // receiving message interface method.
    function lzReceive(uint16 _srcChainId, bytes memory _fromAddress, bytes memory _payload) override external {}
}
*/
/**
 **** visit https://float.capital *****
 */

/// @title Core logic of Float Protocal markets
/// @author float.capital
/// @notice visit https://float.capital for more info
/// @dev All functions in this file are currently `virtual`. This is NOT to encourage inheritance.
/// It is merely for convenince when unit testing.
/// @custom:auditors This contract balances long and short sides.
contract LongShortSlave is AccessControlledAndUpgradeable, ILayerZeroReceiver {
  enum MasterChain {
    NO_MASTER,
    AVALANCHE,
    POLYGON
  }
  mapping(uint32 => MasterChain) public MasterChain;

  mapping(uint32 => uint256) public marketUpdateIndex;
  mapping(uint256 => uint256) public latestActionIndex;

  mapping(uint32 => address) public paymentTokens;
  mapping(uint32 => address) public yieldManagers;

  mapping(uint32 => mapping(bool => address)) public syntheticTokens;

  /// QUESTION: should this be in the master only?
  struct MarketSideValueInPaymentToken {
    // this has a maximum size of `2^128=3.4028237e+38` units of payment token which is amply sufficient for our markets
    uint128 value_long;
    uint128 value_short;
  }
  mapping(uint32 => MarketSideValueInPaymentToken) public marketSideValueInPaymentToken;

  struct SynthPriceInPaymentToken {
    // this has a maximum size of `2^128=3.4028237e+38` units of payment token which is amply sufficient for our markets
    uint128 price_long;
    uint128 price_short;
  }
  mapping(uint32 => mapping(uint256 => SynthPriceInPaymentToken))
    public syntheticToken_priceSnapshot;

  /* ══════ User specific ══════ */
  /// NOTE: we are blocking users from doing multiple actions in the same batch
  mapping(uint32 => mapping(address => uint256)) public userNextPrice_currentActionIndex;

  mapping(uint32 => mapping(uint256 => uint256)) public latestActionInLatestConfirmedBatch;

  mapping(uint32 => mapping(bool => mapping(address => uint256)))
    public userNextPrice_paymentToken_depositAmount;
  mapping(uint32 => mapping(bool => mapping(address => uint256)))
    public userNextPrice_syntheticToken_redeemAmount;
  mapping(uint32 => mapping(bool => mapping(address => uint256)))
    public userNextPrice_syntheticToken_toShiftAwayFrom_marketSide;

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

  /*
    function sendYourMessage(uint16 _chainId, bytes calldata _endpoint) public payable {
        endpoint.send{value:msg.value}(_chainId, _endpoint, bytes(""), msg.sender, address(0x0), bytes(""));
    }

    // receiving message interface method.
    function lzReceive(uint16 _srcChainId, bytes memory _fromAddress, bytes memory _payload) override external {}
  */
}

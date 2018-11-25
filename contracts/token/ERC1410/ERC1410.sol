/*
* This code has not been reviewed.
* Do not use or deploy this code before reviewing it personally first.
*/
pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./IERC1410.sol";
import "../ERC777/ERC777.sol";
import "./ERC1410TrancheRegistry.sol";


contract ERC1410 is IERC1410, ERC777 {
  using SafeMath for uint256;

  ERC1410TrancheRegistry internal _trancheRegistry;

  constructor(
    string name,
    string symbol,
    uint256 granularity,
    address[] defaultOperators,
    address certificateSigner,
    address trancheRegistry
  )
    public
    ERC777(name, symbol, granularity, defaultOperators, certificateSigner)
  {
    _trancheRegistry = ERC1410TrancheRegistry(trancheRegistry);

    setInterfaceImplementation("ERC1410Token", this);
  }


  /**
   * [ERC1410 INTERFACE (1/12)]
   * @dev View function that returns the balance of a tokenholder for a specific tranche
   * @param tranche Name of the tranche.
   * @param tokenHolder Address for which the balance is returned.
   */
  function balanceOfByTranche(bytes32 tranche, address tokenHolder) external view returns (uint256) {
    return _trancheRegistry.balanceOfByTranche(tranche, tokenHolder);
  }

  /**
   * [ERC1410 INTERFACE (2/12)]
   * @dev View function that returns the tranches index of a tokenholder
   * @param tokenHolder Address for which the tranches index are returned.
   */
  function tranchesOf(address tokenHolder) external view returns (bytes32[]) {
    return _trancheRegistry.tranchesOf(tokenHolder);
  }

  /**
   * [ERC1410 INTERFACE (3/12)]
   * @dev External function to send tokens from a specific tranche
   * @param tranche Name of the tranche.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, by the token holder [contains the conditional ownership certificate].
   * @return destination tranche.
   */
  function sendByTranche(
    bytes32 tranche,
    address to,
    uint256 amount,
    bytes data
  )
    external
    isValidCertificate(data)
    returns (bytes32)
  {
    return _sendByTranche(tranche, msg.sender, msg.sender, to, amount, data, "");
  }

  /**
   * [ERC1410 INTERFACE (4/12)]
   * @dev External function to send tokens from specific tranches
   * @param tranches Name of the tranches.
   * @param to Token recipient.
   * @param amounts Number of tokens to send.
   * @param data Information attached to the send, by the token holder [contains the conditional ownership certificate].
   * @return destination tranches.
   */
  function sendByTranches(
    bytes32[] tranches,
    address to,
    uint256[] amounts,
    bytes data
  )
    external
    isValidCertificate(data)
    returns (bytes32[])
  {
    require(tranches.length == amounts.length);
    bytes32[] memory destinationTranches = new bytes32[](tranches.length);

    for (uint i = 0; i < tranches.length; i++) {
      destinationTranches[i] = _sendByTranche(tranches[i], msg.sender, msg.sender, to, amounts[i], data, "");
    }

    return destinationTranches;
  }

  /**
   * [ERC1410 INTERFACE (5/12)]
   * @dev External function to send tokens from a specific tranche through an operator
   * @param tranche Name of the tranche.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from) [contains the destination tranche].
   * @param operatorData Information attached to the send by the operator [contains the conditional ownership certificate].
   * @return destination tranche.
   */
  function operatorSendByTranche(
    bytes32 tranche,
    address from,
    address to,
    uint256 amount,
    bytes data,
    bytes operatorData
  )
    external
    isValidCertificate(operatorData)
    returns (bytes32) // Return destination tranche
  {
    address _from = (from == address(0)) ? msg.sender : from;
    require(_isOperatorFor(msg.sender, _from) || _isOperatorForTranche(tranche, msg.sender, _from));

    return _sendByTranche(tranche, msg.sender, _from, to, amount, data, operatorData);
  }

  /**
   * [ERC1410 INTERFACE (6/12)]
   * @dev External function to send tokens from specific tranches through an operator
   * @param tranches Name of the tranches.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amounts Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from) [contains the destination tranche].
   * @param operatorData Information attached to the send by the operator [contains the conditional ownership certificate].
   * @return destination tranches.
   */
  function operatorSendByTranches(
    bytes32[] tranches,
    address from,
    address to,
    uint256[] amounts,
    bytes data,
    bytes operatorData
  )
    external
    isValidCertificate(operatorData)
    returns (bytes32[]) // Return destination tranches
  {
    require(tranches.length == amounts.length);
    bytes32[] memory destinationTranches = new bytes32[](tranches.length);
    address _from = (from == address(0)) ? msg.sender : from;

    for (uint i = 0; i < tranches.length; i++) {
      require(_isOperatorFor(msg.sender, _from) || _isOperatorForTranche(tranches[i], msg.sender, _from));

      destinationTranches[i] = _sendByTranche(tranches[i], msg.sender, from, to, amounts[i], data, operatorData);
    }

    return destinationTranches;
  }

  /**
   * [ERC1410 INTERFACE (7/12)][OPTIONAL]
   * For ERC777 and ERC20 backwards compatibility.
   * @dev View function to get default tranches to send from.
   *  For example, a security token may return the bytes32("unrestricted").
   * @param tokenHolder Address for which we want to know the default tranches.
   */
  function getDefaultTranches(address tokenHolder) external view returns (bytes32[]) {
    return _trancheRegistry.getDefaultTranches(tokenHolder);
  }

  /**
   * [ERC1410 INTERFACE (8/12)][OPTIONAL]
   * For ERC777 and ERC20 backwards compatibility.
   * @dev External function to set default tranches to send from.
   * @param tranches tranches to use by default when not specified.
   */
  function setDefaultTranches(bytes32[] tranches) external {
    _trancheRegistry.setDefaultTranches(tranches);
  }

  /**
   * [ERC1410 INTERFACE (9/12)]
   * For ERC777 and ERC20 backwards compatibility.
   * @dev External function to get default operators for a given tranche.
   * @param tranche Name of the tranche.
   */
  function defaultOperatorsByTranche(bytes32 tranche) external view returns (address[]) {
    return _trancheRegistry.defaultOperatorsByTranche(tranche);
  }

  /**
   * [ERC1410 INTERFACE (10/12)]
   * @dev External function to set as an operator for msg.sender for a given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address to set as an operator for msg.sender.
   */
  function authorizeOperatorByTranche(bytes32 tranche, address operator) external {
    _trancheRegistry.authorizeOperatorByTranche(tranche, operator);
    emit AuthorizedOperatorByTranche(tranche, operator, msg.sender);
  }

  /**
   * [ERC1410 INTERFACE (11/12)]
   * @dev External function to remove the right of the operator address to be an operator
   *  on a given tranche for msg.sender and to send and burn tokens on its behalf.
   * @param tranche Name of the tranche.
   * @param operator Address to rescind as an operator on given tranche for msg.sender.
   */
  function revokeOperatorByTranche(bytes32 tranche, address operator) external {
    _trancheRegistry.revokeOperatorByTranche(tranche, operator);
    emit RevokedOperatorByTranche(tranche, operator, msg.sender);
  }

  /**
   * [ERC1410 INTERFACE (12/12)]
   * @dev External function to indicate whether the operator address is an operator
   *  of the tokenHolder address for the given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address which may be an operator of tokenHolder for the given tranche.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given tranche.
   */
  function isOperatorForTranche(bytes32 tranche, address operator, address tokenHolder) external view returns (bool) {
    _isOperatorForTranche(tranche, operator, tokenHolder);
  }

  /**
   * @dev Internal function to indicate whether the operator address is an operator
   *  of the tokenHolder address for the given tranche.
   * @param tranche Name of the tranche.
   * @param operator Address which may be an operator of tokenHolder for the given tranche.
   * @param tokenHolder Address of a token holder which may have the operator address as an operator for the given tranche.
   */
  function _isOperatorForTranche(bytes32 tranche, address operator, address tokenHolder) internal view returns (bool) {
    return _trancheRegistry.isOperatorForTranche(tranche, operator, tokenHolder, false);
  }


  /**
   * @dev Internal function to send tokens from a specific tranche
   * @param fromTranche Tranche of the tokens to send.
   * @param operator The address performing the send.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from) [can contain the destination tranche].
   * @param operatorData Information attached to the send by the operator.
   * @return destination tranche.
   */
  function _sendByTranche(
    bytes32 fromTranche,
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes data,
    bytes operatorData
  )
    internal
    returns (bytes32)
  {
    require(_trancheRegistry.balanceOfByTranche(fromTranche, from) >= amount); // ensure enough funds

    bytes32 toTranche = fromTranche;
    if(operatorData.length != 0 && data.length != 0) {
      toTranche = _trancheRegistry.getDestinationTranche(data);
    }

    _trancheRegistry.removeTokenFromTranche(from, fromTranche, amount);
    _sendTo(operator, from, to, amount, data, operatorData, true);
    _trancheRegistry.addTokenToTranche(to, toTranche, amount);

    emit SentByTranche(fromTranche, operator, from, to, amount, data, operatorData);

    if(toTranche != fromTranche) {
      emit ChangedTranche(fromTranche, toTranche, amount);
    }

    return toTranche;
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Send the amount of tokens from the address msg.sender to the address to.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, by the token holder [contains the conditional ownership certificate].
   */
  function sendTo(address to, uint256 amount, bytes data)
    external
    isValidCertificate(data)
  {
    _sendByDefaultTranches(msg.sender, msg.sender, to, amount, data, "");
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Send the amount of tokens on behalf of the address from to the address to.
   * @param from Token holder (or address(0) to set from to msg.sender).
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from) [can contain the destination tranche].
   * @param operatorData Information attached to the send by the operator [contains the conditional ownership certificate].
   */
  function operatorSendTo(address from, address to, uint256 amount, bytes data, bytes operatorData)
    external
    isValidCertificate(operatorData)
  {
    address _from = (from == address(0)) ? msg.sender : from;

    require(_isOperatorFor(msg.sender, _from));

    _sendByDefaultTranches(msg.sender, _from, to, amount, data, operatorData);
  }

  /**
  * [NOT MANDATORY FOR ERC1410 STANDARD]
   * @dev Internal function to send tokens from a default tranches
   * @param operator The address performing the send.
   * @param from Token holder.
   * @param to Token recipient.
   * @param amount Number of tokens to send.
   * @param data Information attached to the send, and intended for the token holder (from) [can contain the destination tranche].
   * @param operatorData Information attached to the send by the operator.
   */
  function _sendByDefaultTranches(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes data,
    bytes operatorData
  )
    internal
  {
    require((_trancheRegistry.getDefaultTranches(from)).length != 0);

    bytes32[] memory _tranches;
    uint256[] memory _amounts;

    (_tranches, _amounts) = _trancheRegistry.getDefaultTranchesForAmount(from, amount);

    require(_tranches.length == _amounts.length);

    for (uint i = 0; i < _tranches.length; i++) {
      _sendByTranche(_tranches[i], operator, from, to, _amounts[i], data, operatorData);
      if(_amounts[i] == 0) {break;}
    }
  }

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Empty function to erase ERC777 burn() function since it doesn't handle tranches.
   */
  function burn(uint256 amount, bytes data) external {}

  /**
   * [NOT MANDATORY FOR ERC1410 STANDARD][OVERRIDES ERC777 METHOD]
   * @dev Empty function to erase ERC777 operatorBurn() function since it doesn't handle tranches.
   */
  function operatorBurn(address from, uint256 amount, bytes data, bytes operatorData) external {}

}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {

  event Stake(address from, uint256 amount);

  ExampleExternalContract public exampleExternalContract;

  mapping(address => uint256) balances;

  uint256 threshold = 0;
  uint256 timeframe = block.timestamp + 30;

  modifier afterDeadline() {
    require(block.timestamp > timeframe, "Deadline not met yet");
    _;
  }

  modifier beforeDeadline() {
    require(block.timestamp < timeframe, "Deadline not met yet");
    _;
  }

  modifier thresholdIsMet() {
    require(address(this).balance >= threshold, "Threshold not met yet");
    _;
  }

  modifier hasBalance() {
    require(balances[msg.sender] > 0, "You have no money here");
    _;
  }

  modifier valueIsSent() {
    require(msg.value > 0, "Money is required");
    _;
  }

  modifier thresholdIsNotMet() {
    require(address(this).balance < threshold, "Threshold was met, thank you kind sir");
    _;
  }
  
  constructor(address exampleExternalContractAddress) {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  function _calculateChange(uint256 _amount, uint256 _currContribution, uint256 _threshold) private pure returns (uint256, uint256) {
    uint256 totalGoodWill = _currContribution + _amount;
    uint256 change = totalGoodWill - _threshold;

    if (change <= 0) {
      return (totalGoodWill, 0);
    } else {
      uint256 maxNecessary = totalGoodWill - change;

      return (maxNecessary, change);
    }
  }

  /**
    Will transfer register the sender's contribution in the balances map.
    This function will also send back any ether that
    would make the contribution go beyong the thhreshold (i.e. change).

    Function to be called from `receive()`.
  */
  function _stake() private {
    (uint256 contribution, uint256 change) = _calculateChange(msg.value, balances[msg.sender], threshold);

    balances[msg.sender] = contribution;  
    emit Stake(msg.sender, contribution);

    if (change > 0) {      
      payable(msg.sender).transfer(change);
    }
  }

  /**
    Will send the the given address the correspondent amount sotred in balances.
   */
  function _withdraw(address payable _to) private {
    uint256 valueToWithdraw = balances[_to];
    balances[_to] = 0;
    
    _to.transfer(valueToWithdraw);
  }

  /**
    Will send the value to the external contract once the funding is complete.
   */
  function deadline() public afterDeadline thresholdIsMet {
    exampleExternalContract.complete{value: address(this).balance}();
  }

  function withdraw() public afterDeadline hasBalance thresholdIsMet {
    _withdraw(payable(msg.sender));
  }

  function timeLeft() public view returns (uint) {
    if (block.timestamp < timeframe) {
      return timeframe - block.timestamp;
    } else {
      return 0;
    }
  }

  /**
    Stakes the received amount
  */
  receive() payable external valueIsSent thresholdIsNotMet {
    _stake();
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.3;
pragma experimental ABIEncoderV2;

// ============ Imports ============

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Potluck {
  // ============ Constants ============

  address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

  // ============ Immutable storage ============

  // Address of the Token contract
  address public immutable ERC20Address;
  // Uniswap V2 Router 02
  IUniswapV2Router02 public immutable router;
  // Amount that potluck will buy of the token
  uint256 public immutable buyAmount;
  // Timestamp when the potluck closes contributions and contributors can exit
  uint256 public immutable exitTimeout;

  // ============ Mutable storage ============

  // Current amount raised to buy the token
  uint256 public currentRaisedAmount;
  // Value received from executed buy
  uint256 public receivedTokenAmount;
  // Toggled when potluck buys the tokens
  bool public buyExecuted;
  // Stakes of individual potluck contributors
  mapping (address => uint256) public contributions;
  // Users who have contributed then exited cannot recontribute
  mapping (address => bool) public blockList;

  // ============ Events ============

  // Address of a new potluck contributor and their entry share
  event PotluckJoined(address indexed member, uint256 value);
  // Value of the buy of the potluck
  event PotluckBuyExecuted(uint256 value);
  // Address and exit share of potluck contributor, along with reason for exit
  event PotluckMemberExited(address indexed member, uint256 value, bool timeoutExit);

  // ============ Constructor ============

  constructor(
    address _ERC20Address,
    uint256 _buyAmount,
    uint256 _exitTimeout
  ) {
    // Initialize immutable memory
    ERC20Address = _ERC20Address;
    router = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);

    // Initialize mutable memory
    buyAmount = _buyAmount;
    currentRaisedAmount = 0;
    exitTimeout = _exitTimeout;
    buyExecuted = false;
  }

  // ============ Join the potluck ============

  /**
   * Join the potluck by sending ETH
   * Requirements:
   *   - contributions enabled (i.e. buy not executed yet)
   *   - forced matching of deposit value to sent ETH
   *   - room in the potluck
   *   - not on block list
   */
  function join(uint256 _value) external payable {
    // Dont allow joining once the buy has already been executed
    require(buyExecuted == false, "Potluck: Cannot join because buy has been executed.");
    // Ensure matching of deposited value to ETH sent to contract
    require(msg.value == _value, "Potluck: Deposit amount does not match spent ETH.");
    // Ensure sum(eth sent, current raised) <= required buy amount
    require(_value + currentRaisedAmount <= buyAmount, "Potluck: Potluck does not have capacity.");
    // Ensure that caller is not blocked
    require(blockList[msg.sender] == false, "Potluck: Must not have previously contributed and exited.");

    currentRaisedAmount += _value; // Increment raised amount
    contributions[msg.sender] += _value; // Track potluck contribution

    emit PotluckJoined(msg.sender, _value); // Emit new potluck contributor
  }

  // ============ Execute a buy from potluck ============

  /**
   * Execute buy, as potluck contributor, so long as required conditions are met
   */
  function executeBuy() external {
    // Dont allow executing a buy if already executed
    require(buyExecuted == false, "Potluck: Buy has already been executed.");
    // Ensure that required buyAmount is matched with currently raised amount
    require(buyAmount == currentRaisedAmount, "Potluck: Insufficient raised capital to execute buy.");
    // Ensure that caller is a potluck contributor
    require(contributions[msg.sender] > 0, "Potluck: Must be potluck contributor to execute buy.");

    buyExecuted = true;

    // Set up Uniswap contract, place buy order, toggle execution status
    address[] memory path = new address[](2);
    path[0] = router.WETH();
    path[1] = ERC20Address;
    uint deadline = block.timestamp + 20 minutes;
    uint[] memory amounts = router.swapExactETHForTokens{ value: buyAmount }(0, path, address(this), deadline);
    receivedTokenAmount = amounts[1];

    // Approve potluck to distribute proceeds
    IERC20(ERC20Address).approve(address(this), receivedTokenAmount);

    emit PotluckBuyExecuted(buyAmount); // Emit buy executed
  }

  // ============ Exit the potluck ============

  /**
   * Exit potluck if buy was executed
   */
  function _exitPostBuy() internal {
    // Require ERC20 to have already been bought
    require(buyExecuted = true, "Potluck: Buy has not yet been executed.");
    // Failsafe: Ensure contract has non-zero funds to payout potluck contributors
    require(IERC20(ERC20Address).balanceOf(address(this)) > 0, "Potluck: potluck is insolvent.");

    uint contribution = contributions[msg.sender];

    // Nullify member potluck contribution
    contributions[msg.sender] = 0;

    // Calculate share of token bought
    uint256 proceeds = ABDKMath64x64.mulu(
      // Multiply (potluck contribution / total)
      ABDKMath64x64.divu(contribution, currentRaisedAmount),
      // by final output amount
        receivedTokenAmount);

    // Send calculated share of ERC20 based on potluck contribution share
    IERC20(ERC20Address).transferFrom(address(this), msg.sender, proceeds);

    emit PotluckMemberExited(msg.sender, contribution, false); // Emit exit event
  }

  /**
   * Exit potluck if deposit timeout has passed
   */
  function _exitIfTimeoutPassed() internal {
    // Dont allow exiting via this function if buy has been executed
    require(buyExecuted == false, "Potluck: Buy must not be executed to exit via timeout.");
    // Ensure that current time > deposit timeout
    require(block.timestamp >= exitTimeout, "Potluck: Exit timeout not met.");

    uint256 contribution = contributions[msg.sender];

    // Nullify user potluck contribution
    contributions[msg.sender] = 0;

    // Prevent user from contributing again
    blockList[msg.sender] = true;

    // Deduct from contribution share
    currentRaisedAmount -= contribution;

    // Transfer ETH from contract to potluck contributor and emit event
    payable(msg.sender).transfer(contribution);

    emit PotluckMemberExited(msg.sender, contribution, false); // Emit exit event
  }

  /**
   * Public utility function to call internal exit functions based on buy state
   */
  function exit() external payable {
    // Ensure that caller is a potluck contributor
    require(contributions[msg.sender] > 0, "Potluck: Must first be a potluck contributor to exit the potluck.");

    if (buyExecuted) {
      // If ERC20 has been bought, exit with tokens
      _exitPostBuy();
    } else {
      // Else, exit because timeout window passed
      _exitIfTimeoutPassed();
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @custom:info This is an exercise where i fix the old existing contract(done in phase 1 of relearning solidity) look professional.
/// @custom:info I fixed it by improving its documentation and by following solidity best practices.
/// @custom:info You can find the original contract in this link: https://github.com/Asout3/Relearn_and_prac/blob/main/src/Bank.sol

/// @title A Bank contract exercise.
/// @author Mikiyas Yimer.
/// @notice This is just simple exercise solidity code. Don't push this code to production.
/// @dev Don't push this code to production.
/// @custom:experimental This is an experimental contract.
contract Bank {
    /// @notice Address used to store the owner address.
    address public owner;
    /// @notice Mapping of user addresses to their deposited ETH balance in wei.
    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrew(address indexed user, uint256 amount);
    event FallbackWasCalled(address user, uint256 amount);

    error NotOwner();
    error NotEnoughMoney();
    error TransferFailed();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    fallback() external payable {
        emit FallbackWasCalled(msg.sender, msg.value);
    }

    /// @notice This function receives the sent ethers.
    /// @dev This is the function which receives the ethers and adds the value and emits the event.
    function deposit() public payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice This is the function which we use to withdraw funds.
    /// @dev This function is used to withdraw funds and it follows the CEI rule.
    /// @dev It withdraws funds using low level call which is .call and at the end it emits an event.
    /// @param _amount The amount of fund to withdraw.
    function withdraw(uint256 _amount) public {
        if (_amount > balances[msg.sender]) revert NotEnoughMoney();

        balances[msg.sender] -= _amount;
        (bool success,) = msg.sender.call{value: _amount}("");
        if (!success) revert TransferFailed();

        emit Withdrew(msg.sender, _amount);
    }

    /// @notice This is the function we use to get our balance.
    /// @return The ETH balance of the caller in wei.
    function getBalance() public view returns (uint256) {
        return balances[msg.sender];
    }

    /// @notice This is the function we use to get all total amount of funds this contract has.
    /// @return All the funds this contract holds.
    function getTotalBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }
}


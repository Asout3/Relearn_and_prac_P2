// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @title TipJar
/// @author Mikiyas.
/// @dev This is experiment with payment methods.
contract TipJar {
    mapping(address => uint256) public tipsOwed;
    mapping(address => bool) public doesExist;
    address[] public creators;

    event Tipped(address indexed sender, address indexed to, uint256 amount);
    event Distributed(address indexed to, uint256 amount);
    event Claimed(address indexed account, uint256 amount);

    error YouCanNotAddZeroAddress();
    error TransferFailed();
    error YouAreNotIn();
    error NoTipsOwed();
    error NotEnoughMoney();

    /// @param _creator is the creator address that we want to add.
    /// @notice this function adds and tips the creator.
    function tip(address _creator) external payable {
        if (msg.value == 0 ether) revert NotEnoughMoney();
        if (_creator == address(0)) revert YouCanNotAddZeroAddress();
        if (!doesExist[_creator]) {
            creators.push(_creator);
            doesExist[_creator] = true;
        }

        tipsOwed[_creator] += msg.value;

        emit Tipped(msg.sender, _creator, msg.value);
    }

    /// @notice this function distribute the tip to the creators.
    /// @dev this function intentionally have bug which is the point of this exercise.
    function distribute() external {
        for (uint256 i = 0; i < creators.length; i++) {
            uint256 amount = tipsOwed[creators[i]];

            tipsOwed[creators[i]] = 0;

            (bool ok,) = payable(creators[i]).call{value: amount}("");
            if (!ok) revert TransferFailed();

            emit Distributed(creators[i], amount);
        }
    }

    /// @notice this function sends the tip to the creators.
    function claim() external {
        if (!doesExist[msg.sender]) revert YouAreNotIn();
        if (tipsOwed[msg.sender] == 0) revert NoTipsOwed();

        uint256 amount = tipsOwed[msg.sender];

        tipsOwed[msg.sender] = 0;

        (bool ok,) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Claimed(msg.sender, amount);
    }
}

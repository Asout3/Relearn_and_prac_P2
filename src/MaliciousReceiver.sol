// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/// @title Malicious receiver.
/// @author Mikiyas.
/// @dev This is the receiver which make the distribute function revert.
contract MaliciousReceiver {
    error HAHAHA();

    receive() external payable {
        revert HAHAHA();
    }
}

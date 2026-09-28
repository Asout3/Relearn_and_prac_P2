// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";

contract DummyReverter {
    uint256 public constant MAX_ALLOWED = 100;

    error AmountTooHigh(uint256 maxAllowed, uint256 amount);
    error LowLevelCallFailed();

    function revertWithArgs(uint256 _amount) public {
        if (_amount > MAX_ALLOWED) {
            revert AmountTooHigh({maxAllowed: MAX_ALLOWED, amount: _amount});
        }
    }

    function revertWithString(uint256 _amount) public {
        require(_amount <= MAX_ALLOWED, "Amount exceeds limit");
    }

    function failLowLevelCall() public {
        (bool success,) = address(1).call{value: 2 ether}("");
        if (!success) revert LowLevelCallFailed();
    }
}

contract ExpectRevertPractice is Test {
    DummyReverter dummy;

    function setUp() public {
        dummy = new DummyReverter();
    }

    function test_revertWithArgs() public {
        vm.expectRevert(abi.encodeWithSelector(DummyReverter.AmountTooHigh.selector, 100, 1000));
        dummy.revertWithArgs(1000);
    }

    function test_revertWithString() public {
        vm.expectRevert("Amount exceeds limit");
        dummy.revertWithString(1000);
    }

    function test_failLowLevelCall() public {
        vm.expectRevert(DummyReverter.LowLevelCallFailed.selector);
        dummy.failLowLevelCall();
    }
}

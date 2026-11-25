// SPDX-License-identifer: MIT
pragma solidity ^0.8.34;

import {Flashlender} from "./Flashlender.sol";
import {Asout3Token} from "./ERC20.sol";

contract MaliciousBorrower {
    /// @notice Flash lender used by this borrower.
    Flashlender lender;
    Asout3Token token;

    bool public steal = false;
    address public thief = address(0x1234);

    /// @notice Sets the flash lender for this borrower.
    /// @param _lender Address of the `FlashLender` contract.
    constructor(address _lender, address _token) {
        lender = Flashlender(_lender);
        token = Asout3Token(_token);
    }

    function setSteal(bool _steal) public {
        steal = _steal;
    }

    function onFlashLoan(address _initiator, uint256 _amount, uint256 _fee) external returns (bytes32) {
        require(msg.sender == address(lender), "untrusted lender");
        require(_initiator == address(this), "untrusted initiator");

        uint256 _repayment = _amount + _fee;

        if (steal) {
            bool ok = token.transfer(thief, _amount);
            require(ok, "transfer failed");
        } else {
            bool ok = token.approve(msg.sender, _repayment);
            require(ok, "approval failed");
        }

        return keccak256("FlashBorrower.onFlashLoan");
    }

    function flashloan(address _token, uint256 _amount) external {
        bool ok = lender.flashLoan(address(this), _token, _amount);
        require(ok, "flashloan failed");
    }
}

// SPDX-License-identifer: MIT
pragma solidity ^0.8.34;

import {FlashLender} from "./FlashLoan.sol";
import {Asout3Token} from "./ERC20.sol";

contract MaliciousBorrower {
    /// @notice Action selector used to choose callback behavior.
    /// @dev Encoded into the callback `data` parameter by `flashloan`.
    enum Action {
        Normal,
        Other
    }

    /// @notice Flash lender used by this borrower.
    FlashLender lender;
    Asout3Token token;
    nestedFlashBorrower nesFB;

    /// @notice Sets the flash lender for this borrower.
    /// @param _lender Address of the `FlashLender` contract.
    constructor(address _lender, address _token) {
        lender = FlashLender(_lender);
        token = Asout3Token(_token);
    }

    /// @notice Callback invoked by the flash lender after the loan amount is transferred.
    /// @dev Must return the lender's expected callback magic value. The borrower approves the lender for repayment before or during this callback so the lender can pull `amount + fee`.
    /// @param _initiator Address that initiated the flash loan on the lender.
    /// @param _token ERC-20 token borrowed.
    /// @param _amount Principal amount borrowed.
    /// @param _fee Fee owed to the lender.
    /// @param _data Arbitrary data supplied when initiating the loan.
    /// @return Must equal `keccak256("FlashBorrower.onFlashLoan")`.
    /// @custom:security Reverts if the caller is not the configured lender or if `initiator` is not this borrower.
    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
        external
        returns (bytes32)
    {
        require(msg.sender == address(lender), "untrusted lender");

        require(_initiator == address(this), "untrusted intiator");

        (Action action) = abi.decode(_data, (Action));

        uint256 _fee = lender.flashFee(_amount);
        uint256 _repayment = _amount + _fee;

        nesFB = new nestedFlashBorrower(address(lender), _token, _repayment);

        if (action == Action.Normal) {
            nesFB.onFlashLoan(_initiator, _token, _amount, _fee, _data);
        }

        return keccak256("FlashBorrower.onFlashLoan");
    }

    /// @notice Initiates a flash loan of `amount` of `token` from the configured lender.
    /// @dev Approves the lender for `amount + fee` before calling `flashLoan`.
    /// @param _token ERC-20 token to borrow.
    /// @param _amount Principal amount to borrow.
    function flashloan(address _token, uint256 _amount) public {
        bytes memory data = abi.encode(Action.Normal);
        uint256 _fee = lender.flashFee(_amount);
        uint256 _repayment = _amount + _fee;
        bool ok = token.transfer(address(0x1234), _repayment);
        require(ok, "failed");
    }
}

contract nestedFlashBorrower {
    /// @notice Action selector used to choose callback behavior.
    /// @dev Encoded into the callback `data` parameter by `flashloan`.
    enum Action {
        Normal
    }

    /// @notice Flash lender used by this borrower.
    FlashLender lender;
    Asout3Token token;

    uint256 public repaymentAmount;

    /// @notice Sets the flash lender for this borrower.
    /// @param _lender Address of the `FlashLender` contract.
    constructor(address _lender, address _token, uint256 _amount) {
        lender = FlashLender(_lender);
        token = Asout3Token(_token);
        repaymentAmount = _amount;
    }

    /// @notice Callback invoked by the flash lender after the loan amount is transferred.
    /// @dev Must return the lender's expected callback magic value. The borrower approves the lender for repayment before or during this callback so the lender can pull `amount + fee`.
    /// @param _initiator Address that initiated the flash loan on the lender.
    /// @param _token ERC-20 token borrowed.
    /// @param _amount Principal amount borrowed.
    /// @param _fee Fee owed to the lender.
    /// @param _data Arbitrary data supplied when initiating the loan.
    /// @return Must equal `keccak256("FlashBorrower.onFlashLoan")`.
    /// @custom:security Reverts if the caller is not the configured lender or if `initiator` is not this borrower.
    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
        external
        returns (bytes32)
    {
        require(msg.sender == address(lender), "untrusted lender");

        require(_initiator == address(this), "untrusted intiator");

        (Action action) = abi.decode(_data, (Action));

        if (action == Action.Normal) {
            bool ok = token.transfer(address(lender), repaymentAmount);
            require(ok, "repayment failed");
        }

        return keccak256("FlashBorrower.onFlashLoan");
    }

    /// @notice Initiates a flash loan of `amount` of `token` from the configured lender.
    /// @dev Approves the lender for `amount + fee` before calling `flashLoan`.
    /// @param _token ERC-20 token to borrow.
    /// @param _amount Principal amount to borrow.
    function flashloan(address _token, uint256 _amount) public {
        bytes memory data = abi.encode(Action.Normal);
        uint256 _fee = lender.flashFee(_amount);
        uint256 _repayment = _amount + _fee;
        bool ok = token.approve(address(lender), _repayment);
        require(ok, "failed");
        lender.flashLoan(address(this), _token, _amount, data);
    }
}

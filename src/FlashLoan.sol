// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

/*
  _____.__                .__
_/ ____\  | _____    _____|  |__
\   __\|  | \__  \  /  ___/  |  \
 |  |  |  |__/ __ \_\___ \|   Y  \
 |__|  |____(____  /____  >___|  /
                 \/     \/     \/
       .__
       |  |   _________    ____
       |  |  /  _ \__  \  /    \
       |  |_(  <_> ) __ \|   |  \
       |____/\____(____  /___|  /
                       \/     \/
*/

/// @custom:info This contract have been refactored by an ai(deepseek v4.1 flash) not the core logic but only for the natspec.
/// @custom:info You can find the original contract in this link: https://github.com/Asout3/Relearn_and_prac/blob/main/src/FlashLoan.sol

/// @title IERC20
/// @notice Minimal ERC-20 interface used by the flash-loan exercise contracts.
/// @dev Declares only the ERC-20 functions and events required by these contracts.
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title FlashLender
/// @notice Holds an ERC-20 token pool and issues flash loans that must be repaid plus a fee in the same transaction.
/// @dev Exercise-specific flash-loan implementation inspired by ERC-3156. The lender transfers the loan amount to the receiver, calls the receiver callback, and requires repayment of `amount + fee` before the transaction succeeds.
/// @custom:security The lender verifies repayment by checking its token balance after the callback. If repayment is missing or insufficient, the transaction reverts.
contract FlashLender {
    /// @notice Emitted when a flash loan is issued.
    /// @param to Address receiving the flash loan.
    /// @param amount Principal amount lent.
    event FlashLoanIsIssued(address indexed to, uint256 indexed amount);

    /// @notice Emitted when a flash loan is repaid.
    /// @param from Address repaying the flash loan.
    /// @param amount Total repayment amount, including the fee.
    event FlashLoanIsPaid(address indexed from, uint256 indexed amount);

    /// @notice Expected magic return value from a compliant `onFlashLoan` callback.
    /// @dev Equal to `keccak256("FlashBorrower.onFlashLoan")`.
    bytes32 public constant CALLBACK_SUCCESS = keccak256("FlashBorrower.onFlashLoan");

    /// @notice Issues a flash loan of `_amount` of `_token` to `_receiver`.
    /// @dev Transfers `_amount` to `_receiver`, calls `_receiver.onFlashLoan(...)`, then pulls `_amount + fee` back from `_receiver`. Reverts if the callback fails or repayment is insufficient.
    /// @param _receiver Address receiving the loan and implementing the callback.
    /// @param _token ERC-20 token being lent.
    /// @param _amount Principal amount to lend.
    /// @param _data Arbitrary data forwarded to the receiver callback.
    /// @return True if the flash loan is issued and repaid successfully.
    /// @custom:security The receiver is untrusted and must implement the callback correctly. Repayment is enforced with `transferFrom` and a before/after balance check.
    function flashLoan(address _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        returns (bool)
    {
        flashBorrower Receiver = flashBorrower(_receiver);

        uint256 beforeBalance = IERC20(_token).balanceOf(address(this));

        uint256 fee = flashFee(_amount);

        require(IERC20(_token).transfer(_receiver, _amount), "Transfer Failed!");

        emit FlashLoanIsIssued(_receiver, _amount);

        require(
            Receiver.onFlashLoan(msg.sender, _token, _amount, fee, _data) == CALLBACK_SUCCESS,
            "FlashLender: Callback failed"
        );

        require(IERC20(_token).transferFrom(_receiver, address(this), _amount + fee), "Reciving failed");

        uint256 afterBalance = IERC20(_token).balanceOf(address(this));
        require(afterBalance >= beforeBalance, "you paid less");

        emit FlashLoanIsPaid(_receiver, _amount + fee);

        return true;
    }

    /// @notice Calculates the flat flash-loan fee for `_amount`.
    /// @dev Fee is 0.3%, represented with integer arithmetic as `(_amount * 3) / 1000`.
    /// @param _amount Principal loan amount.
    /// @return The fee owed for the loan.
    function flashFee(uint256 _amount) public pure returns (uint256) {
        return (_amount * 3) / 1000;
    }
}

/// @title flashBorrower
/// @notice Example flash-loan borrower that initiates a loan and repays it during the callback.
/// @dev Implements the borrower-side callback expected by `FlashLender`. The borrower must hold enough tokens to cover the fee and approve the lender for `amount + fee`.
/// @custom:security The callback accepts calls only from the configured lender and requires the initiator to be this borrower.
// as i said there will be some customization so i will try my best looking look like the original erc3156.
contract flashBorrower {
    /// @notice Action selector used to choose callback behavior.
    /// @dev Encoded into the callback `data` parameter by `flashloan`.
    enum Action {
        Normal,
        Other
    }

    /// @notice Flash lender used by this borrower.
    FlashLender lender;

    /// @notice Sets the flash lender for this borrower.
    /// @param _lender Address of the `FlashLender` contract.
    constructor(address _lender) {
        lender = FlashLender(_lender);
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
        view
        returns (bytes32)
    {
        require(msg.sender == address(lender), "untrusted lender");

        require(_initiator == address(this), "untrusted intiator");

        (Action action) = abi.decode(_data, (Action));

        if (action == Action.Normal) {
            // do something.
        } else if (action == Action.Other) {
            // do something.
        } else {
            // do something.
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
        IERC20(_token).approve(address(lender), _repayment);
        lender.flashLoan(address(this), _token, _amount, data);
    }
}

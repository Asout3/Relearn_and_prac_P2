// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Governor} from "../../src/Governor.sol";
import {Asout3Token} from "../../src/ERC20.sol";
import {GovernorHandler} from "../Handlers/GovernorHandler.sol";

/// @title GovernorLifecycleInvariantTest
/// @notice Invariant suite covering the full proposal lifecycle of `Governor`.
/// @dev Deploys a fresh token, governor, and handler in `setUp`, then targets the handler
///      so the fuzzer drives all state transitions.
contract GovernorLifecycleInvariantTest is Test {
    Governor public gov;
    Asout3Token public token;
    GovernorHandler public handler;

    /// @notice Deploys token, governor, and handler; funds the handler's actors; registers
    ///         the handler as the fuzzed target.
    function setUp() public {
        token = new Asout3Token("Meow", "MW", 18, 110_000e18);
        gov = new Governor(address(token));
        handler = new GovernorHandler(gov, token);

        for (uint256 i = 0; i < 8; i++) {
            token.transfer(handler.actors(i), ((5000e18) - (i * 100e18)) - 2500e18);
        }

        targetContract(address(handler));
    }

    /// @notice Every tracked proposal should be in one of the six defined `ProposalState`s.
    /// @dev Loops over all known proposals, setting `returnsSafe` when a recognised state is
    ///      seen, then asserts the flag. Vacuously passes when no proposals exist.
    function invariant_stateIsValid() public view {
        if (handler.getArrayLength() == 0) return;
        for (uint256 i = 0; i < handler.getArrayLength(); i++) {
            Governor.ProposalState state = gov.state(handler.ids(i));
            assertTrue(
                state == Governor.ProposalState.Pending || state == Governor.ProposalState.Active
                    || state == Governor.ProposalState.Succeeded || state == Governor.ProposalState.Defeated
                    || state == Governor.ProposalState.Queued || state == Governor.ProposalState.Executed,
                "Invalid proposal state"
            );
        }
    }

    /// @notice Once a proposal is `Executed`, its `proposals(id).executed` flag must be `true`.
    /// @dev Vacuously passes when no proposals exist. Skips on the first non-`Executed`
    ///      proposal; otherwise destructures the auto-generated `proposals` getter and asserts.
    function invariant_executedIsFinal() public view {
        if (handler.getArrayLength() == 0) return;
        for (uint256 i = 0; i < handler.getArrayLength(); i++) {
            if (gov.state(handler.ids(i)) != Governor.ProposalState.Executed) continue;
            (,,,,,,,,, bool executed) = gov.proposals(handler.ids(i));
            assertTrue(executed);
        }
    }
}

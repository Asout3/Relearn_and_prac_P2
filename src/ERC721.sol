// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @custom:Info This is shitty code it is really bad. But i wrote it long ago and i have become smart enough to see
///              how bad this code is i guess that is a progress. This is broken code honestly.

/// @title MyNft
/// @author Mikiyas Yimer
/// @notice Simple NFT exercise contract made for learning. Do not use this in production.
/// @dev This is a from-scratch NFT-style contract for practice, so it intentionally does not use OpenZeppelin.
///      It still has rough edges and is only meant for learning and testing.
/// @custom:source Original contract: https://github.com/Asout3/Relearn_and_prac/blob/main/src/MyNft.sol
/// @custom:experimental This is an experimental contract.
contract MyNft {
    /// @notice The next NFT id that will be minted.
    uint256 public id = 1;

    address public owner;
    /// @notice The name of the NFT collection.
    string public name;
    /// @notice The symbol of the NFT collection.
    string public symbol;

    /// @notice Tracks the owner of each NFT id.
    mapping(uint256 => address) public nftOwner;
    /// @notice Tracks how many NFTs an address owns.
    mapping(address => uint256) public balanceOf;
    /// @notice Tracks the approved address for each NFT id.
    mapping(uint256 => address) public listOfApprovals;

    /// @notice Emitted when ownership of an NFT is moved.
    /// @param _from The previous owner address.
    /// @param _to The new owner address.
    /// @param _id The NFT id being moved.
    event OwnershipTrasfered(address indexed _from, address indexed _to, uint256 indexed _id);

    /// @notice Emitted when an NFT is transferred.
    /// @param _from The address sending the NFT.
    /// @param _to The address receiving the NFT.
    /// @param _id The NFT id being transferred.
    event Transfered(address indexed _from, address indexed _to, uint256 indexed _id);

    /// @notice Emitted when an address is approved for an NFT id.
    /// @param _owner The owner of the NFT.
    /// @param _spender The address approved to transfer the NFT.
    /// @param _id The NFT id approved.
    event Approved(address indexed _owner, address _spender, uint256 indexed _id);

    /// @notice Reverts when trying to send or mint an NFT to the zero address.
    error cantSendToZeroAddress();
    /// @notice Reverts when the caller is not allowed to perform the action.
    error youAreNotOwner();
    /// @notice Reverts when the caller or provided address does not own the NFT.
    error youDoNotOwnTheToken();

    /// @notice Restricts a function so only the contract owner can call it.
    modifier onlyOwner() {
        require(owner == msg.sender, "you are not the owner");
        _;
    }

    /// @notice Sets the collection name and symbol, and makes the deployer the contract owner.
    /// @param _name The NFT collection name.
    /// @param _symbol The NFT collection symbol.
    constructor(string memory _name, string memory _symbol) {
        owner = msg.sender;
        name = _name;
        symbol = _symbol;
    }

    /// @notice Mints a new NFT to an address.
    /// @dev Only the contract owner can mint. The NFT id starts from 1 and increases after every mint.
    /// @param _to The address that will receive the new NFT.
    function mint(address _to) public onlyOwner {
        if (_to == address(0)) revert cantSendToZeroAddress();
        nftOwner[id] = _to;
        balanceOf[_to] += 1;
        emit OwnershipTrasfered(address(0), _to, id);
        id++;
    }

    /// @notice Transfers ownership of an NFT from one address to another.
    /// @dev The caller must be the same as `_from`, and `_from` must own the NFT id.
    /// @param _from The current owner of the NFT.
    /// @param _to The address receiving the NFT.
    /// @param _id The NFT id being transferred.
    function transferOwnership(address _from, address _to, uint256 _id) public {
        if (_from != msg.sender) revert youAreNotOwner();
        if (nftOwner[_id] != _from) revert youDoNotOwnTheToken();

        nftOwner[_id] = _to;
        balanceOf[_from] -= 1;
        balanceOf[_to] += 1;

        emit OwnershipTrasfered(_from, _to, _id);
    }

    /// @notice Approves an address to transfer a specific NFT id.
    /// @dev Only the current NFT owner can approve another address.
    /// @param _to The address being approved.
    /// @param _id The NFT id being approved.
    function approve(address _to, uint256 _id) public {
        if (nftOwner[_id] != msg.sender) revert youDoNotOwnTheToken();

        listOfApprovals[_id] = _to;

        emit Approved(msg.sender, _to, _id);
    }

    /// @notice Transfers an NFT owned by the caller to another address.
    /// @param _to The address receiving the NFT.
    /// @param _id The NFT id being transferred.
    function transfer(address _to, uint256 _id) public {
        if (nftOwner[_id] != msg.sender) revert youDoNotOwnTheToken();
        if (_to == address(0)) revert cantSendToZeroAddress();

        nftOwner[_id] = _to;
        balanceOf[msg.sender] -= 1;
        balanceOf[_to] += 1;

        emit Transfered(msg.sender, _to, _id);
    }

    /// @notice Transfers an NFT from one address to another using approval.
    /// @dev The caller must be the approved address for the NFT id.
    /// @param _from The current owner of the NFT.
    /// @param _to The address receiving the NFT.
    /// @param _id The NFT id being transferred.
    function transferFrom(address _from, address _to, uint256 _id) public {
        if (nftOwner[_id] != _from) revert youDoNotOwnTheToken();
        if (approvedAddresses(_id) != msg.sender) revert youAreNotOwner();
        if (_to == address(0)) revert cantSendToZeroAddress();

        nftOwner[_id] = _to;
        balanceOf[_from] -= 1;
        balanceOf[_to] += 1;

        emit Transfered(_from, _to, _id);
    }

    /// @notice Returns the owner of an NFT id.
    /// @param _id The NFT id to check.
    /// @return The address that owns the NFT.
    function ownerOf(uint256 _id) public view returns (address) {
        return nftOwner[_id];
    }

    /// @notice Returns how many NFTs an address owns.
    /// @dev This is basically a helper around the public balanceOf mapping.
    /// @param _owner The address to check.
    /// @return The number of NFTs owned by the address.
    function amountOfNft(address _owner) public view returns (uint256) {
        return balanceOf[_owner];
    }

    /// @notice Returns the approved address for an NFT id.
    /// @param _id The NFT id to check.
    /// @return The address approved for that NFT id.
    function approvedAddresses(uint256 _id) public view returns (address) {
        return listOfApprovals[_id];
    }
}

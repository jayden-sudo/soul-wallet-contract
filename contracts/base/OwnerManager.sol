// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../libraries/AccountStorage.sol";
import "../authority/Authority.sol";
import "../interfaces/IOwnerManager.sol";
import "../libraries/AddressLinkedList.sol";

abstract contract OwnerManager is IOwnerManager, Authority {
    using AddressLinkedList for mapping(address => address);

    function ownerMapping() private view returns (mapping(address => address) storage owners) {
        owners = AccountStorage.layout().owners;
    }

    function _isOwner(address addr) internal view override returns (bool) {
        return ownerMapping().isExist(addr);
    }

    function isOwner(address addr) external view override returns (bool) {
        return _isOwner(addr);
    }

    function clearOwner() private {
        ownerMapping().clear();
        emit OwnerCleared();
    }

    function resetOwner(address newOwner) public override onlyEntryPointOrSelf {
        clearOwner();
        addOwner(newOwner);
    }
    function resetOwners(address[] calldata newOwners) public override onlyEntryPointOrSelf {
        clearOwner();
        addOwners(newOwners);
    }

    function addOwner(address owner) public override onlyEntryPointOrSelf {
        _addOwner(owner);
    }
    function addOwners(address[] calldata owners) public override onlyEntryPointOrSelf {
        for(uint256 i =0; i < owners.length; i++){
            _addOwner(owners[i]);
        }
    }

    function _addOwner(address owner) internal {
        ownerMapping().add(owner);
        emit OwnerAdded(owner);
    }

    function removeOwner(address owner) public override onlyEntryPointOrSelf {
        ownerMapping().remove(owner);
        require(!ownerMapping().isEmpty(), "no owner");
        emit OwnerRemoved(owner);
    }

    function replaceOwner(address oldOwner, address newOwner) public override onlyEntryPointOrSelf {
        ownerMapping().replace(oldOwner, newOwner);
        emit OwnerRemoved(oldOwner);
        emit OwnerAdded(newOwner);
    }

    function listOwner() external view override returns (address[] memory owners) {
        uint256 size = ownerMapping().size();
        owners = ownerMapping().list(AddressLinkedList.SENTINEL_ADDRESS, size);
    }

    function getNonce(address owner) external view override returns (uint256) {
        uint192 key;
        assembly {
            key := owner
        }
        return _entryPoint().getNonce(address(this), key);
    }
}

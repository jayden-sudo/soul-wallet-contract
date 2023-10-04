// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

interface IMerkleTree {
    function insertLeaf(bytes32 slot, bytes32 signingKey) external;
}
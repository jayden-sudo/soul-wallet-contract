// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@source/automation/ClaimInterest.sol";
import "@source/dev/tokens/TokenERC20.sol";

contract ClaimInterestTest is Test {
    ClaimInterest claimInterest;
    address owner;
    uint256 ownerKey;
    address signer;
    uint256 signerKey;
    TokenERC20 token;

    function setUp() public {
        (owner, ownerKey) = makeAddrAndKey("owner");
        (signer, signerKey) = makeAddrAndKey("signer");
        vm.startBroadcast(ownerKey);
        token = new TokenERC20(6);
        claimInterest = new ClaimInterest(owner, signer, address(token));
        // deposit interest to contract
        token.transfer(address(claimInterest), uint256(10000e6));
        vm.stopBroadcast();
    }

    function test_claim_interest() public {
        (address user, uint256 userKey) = makeAddrAndKey("user");
        // test user can claim 100 usdc interest
        uint256 userNonce = claimInterest.nonces(user);
        bytes32 message = keccak256(abi.encodePacked(user, uint256(100e6), userNonce));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.startBroadcast(userKey);
        assertEq(token.balanceOf(user), 0);
        claimInterest.claimInterest(100e6, userNonce, signature);
        assertEq(token.balanceOf(user), 100e6);
        // should not be able to claim again with the same nonce
        vm.expectRevert();
        claimInterest.claimInterest(100e6, userNonce, signature);
        vm.stopBroadcast();
    }

    function test_invalidate_nonce() public {
        (address user, uint256 userKey) = makeAddrAndKey("user");
        uint256 userNonce = claimInterest.nonces(user);
        vm.prank(signer);
        // force increment nonce
        claimInterest.incrementNonce(user);
        bytes32 message = keccak256(abi.encodePacked(user, uint256(100e6), userNonce));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(message);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        vm.startBroadcast(userKey);
        assertEq(token.balanceOf(user), 0);
        vm.expectRevert();
        claimInterest.claimInterest(100e6, userNonce, signature);
        vm.stopBroadcast();
    }

    function test_change_signer() public {
        vm.startBroadcast(ownerKey);
        address oldSigner = claimInterest.signer();
        assertEq(oldSigner, signer);
        address newSigner = makeAddr("newSigner");
        claimInterest.changeSigner(newSigner);
        address currentSigner = claimInterest.signer();
        assertEq(currentSigner, newSigner);
    }
}

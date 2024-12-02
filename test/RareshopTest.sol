// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/templates/RareshopSKUContract.sol";
import "../src/templates/RareshopBrandContract.sol";
import "../src/RareshopPlatformContract.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract RareshopBrandContractTest is Test {

    address constant OWNER_ADDRESS = 0xC565FC29F6df239Fe3848dB82656F2502286E97d;

    address private skuAddress;
    address private brandAddress;
    address private platformAddress;
    RareshopBrandContract private brandInstance;
    RareshopSKUContract private skuInstance;
    RareshopPlatformContract private platformInstance;


    function setUp() public {
        console.log("=======setUp============");

        platformAddress = Upgrades.deployUUPSProxy(
            "RareshopPlatformContract.sol", abi.encodeCall(RareshopPlatformContract.initialize, (OWNER_ADDRESS))
        );
        platformInstance = RareshopPlatformContract(platformAddress);

        brandAddress = Upgrades.deployUUPSProxy(
            "RareshopBrandContract.sol", abi.encodeCall(RareshopBrandContract.initialize, (OWNER_ADDRESS, "brand1", abi.encode("")))
        );
        brandInstance = RareshopBrandContract(brandAddress);

        skuInstance = new RareshopSKUContract();
    }

    function testMint() public {
        console.log("testMint");
        vm.startPrank(OWNER_ADDRESS);
        bytes32 computedHash = 0xb35982d74a73cde17ce7dfc2e51d05a8b40bb591e3639d4bbcd0a0a0b4c0b220;
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0xb35982d74a73cde17ce7dfc2e51d05a8b40bb591e3639d4bbcd0a0a0b4c0b220;
        proof[1] = 0xecab1131eceb01889b5c6eb028a52ae6aceb034f4c9877f9eb2537430301d6e8;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = keccak256(abi.encode(computedHash, proof[i]));
        }
        emit log_named_bytes32("computedHash = ", computedHash);
        bytes2 b1 = 0x0100;
        bytes2 b2 = 0x0001;
        if(b1 > b2){
            emit log(" > ");
        } else{
            emit log(" < ");
        }

        vm.stopPrank();
    }
}

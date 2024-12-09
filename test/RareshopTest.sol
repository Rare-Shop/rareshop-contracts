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
        bytes32[] memory proof1 = new bytes32[](3);
        proof1[0] = 0xdf566fa427a3a8b852b8fc6c45c1518b8be786ce3df5140113b32912d4fd21da;
        proof1[1] = 0xc3fd0f426a6ef628c5f9fe4357c45784af21da5c7a5b59926145d468dfa6f571;
        proof1[2] = 0xf15ecfce7dfe97a35e47d492d6e49e05bf4bdfaf439a734a35a263739478de86;
        assertEq(
            testProof(
                address(0xA6Ec99f3B80229222d5CB457370E36a3870edb06), 
                proof1,
                0x0740bf9e72ca794dadb06a1b5b3d9820e1c34337175372215bc46bc24f7380dc),
            true,
            "test1 failed"
        );

        bytes32[] memory proof2 = new bytes32[](3);
        proof2[0] = 0xb35982d74a73cde17ce7dfc2e51d05a8b40bb591e3639d4bbcd0a0a0b4c0b220;
        proof2[1] = 0xc3fd0f426a6ef628c5f9fe4357c45784af21da5c7a5b59926145d468dfa6f571;
        proof2[2] = 0xf15ecfce7dfe97a35e47d492d6e49e05bf4bdfaf439a734a35a263739478de86;
        assertEq(
            testProof(
                address(0xcBC1955CC42e73A0a7A0c59F6c10118D5f4e37F4), 
                proof2,
                0x0740bf9e72ca794dadb06a1b5b3d9820e1c34337175372215bc46bc24f7380dc),
            true,
            "test2 failed"
        );

        bytes32[] memory proof3 = new bytes32[](1);
        proof3[0] = 0x4ea0eb19361b32ef51f9d807dc1f50a197f2a2858015c5414f86baba42de0387;
        assertEq(
            testProof(
                address(0x41662BAb44A6d289Fd4A58d7acEF9a3167e55b60), 
                proof3,
                0x0740bf9e72ca794dadb06a1b5b3d9820e1c34337175372215bc46bc24f7380dc),
            true,
            "test3 failed"
        );
        vm.stopPrank();
    }

    function testProof(address user, bytes32[] memory proof, bytes32 root) public pure returns(bool) {
        bytes32 computedHash = keccak256(abi.encode(user));
        for (uint256 i = 0; i < proof.length; i++) {
            if(uint256(computedHash) < uint256(proof[i])) {
                computedHash = keccak256(abi.encode(computedHash, proof[i]));
            } else {
                computedHash = keccak256(abi.encode(proof[i], computedHash));
            }
        }
        return computedHash == root;
    }
}

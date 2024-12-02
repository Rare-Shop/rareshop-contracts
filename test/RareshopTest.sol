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
        bytes32 computedHash = keccak256(abi.encode(address(0xA6Ec99f3B80229222d5CB457370E36a3870edb06)));
        emit log_named_bytes32("computedHash = ", computedHash);

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = keccak256(abi.encode(address(0xcBC1955CC42e73A0a7A0c59F6c10118D5f4e37F4)));
        proof[1] = keccak256(abi.encode(address(0x666b088c9ABeEbb2DdEf5149b3FB3907C54b584a)));
        for (uint256 i = 0; i < proof.length; i++) {
            emit log_named_bytes32("1 computedHash = ", computedHash);
            emit log_named_bytes32("2 proof = ", proof[i]);
            emit log_named_uint("1 uint" , uint256(computedHash));
            emit log_named_uint("2 uint" , uint256(proof[i]));

            if(uint256(computedHash) < uint256(proof[i])) {
                computedHash = keccak256(abi.encode(computedHash, proof[i]));
            } else {
                computedHash = keccak256(abi.encode(proof[i], computedHash));
            }
            emit log_named_bytes32("computedHash = ", computedHash);
        }

        assertEq(computedHash, 0xede260af4e45b854a703b1aea86318427979f4d39d05b40088d3138df3db7f40, "whitelist verify failed");
        vm.stopPrank();
    }
}

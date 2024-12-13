// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/templates/RareshopBrandContract.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract RareshopBrandContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.envAddress("OWNER");

        address beacon = Upgrades.deployBeacon("RareshopBrandContract.sol", owner);
        address implAddressV1 = IBeacon(beacon).implementation();
        console.log("beacon -> %s", beacon);
        console.log("implAddressV1 -> %s", implAddressV1);

        bytes memory data;
        address beaconProxy = Upgrades.deployBeaconProxy(beacon, data);
        console.log("beaconProxy -> %s", beaconProxy);

        address cloneBrandProxy = Clones.cloneDeterministic(
            beaconProxy,
            keccak256(abi.encode("cloneBrandProxy"))
        );

        address cloneBrandProxy2 = Clones.cloneDeterministic(
            beaconProxy,
            keccak256(abi.encode("cloneBrandProxy2"))
        );

        console.log("cloneBrandProxy -> %s", cloneBrandProxy);
        console.log("cloneBrandProxy2 -> %s", cloneBrandProxy2);

        // upgrade contract by beacon
        // address beacon = address(0x6cc2246ae83b026394d16EFca5f3bE76c7961d11);
        // Upgrades.upgradeBeacon(beacon, "RareshopBrandContractV2.sol");

        vm.stopBroadcast();
    }
}

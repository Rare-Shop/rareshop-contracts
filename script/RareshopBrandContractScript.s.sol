// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/templates/RareshopBrandContract.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

contract RareshopBrandContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.envAddress("OWNER");

        address beacon = Upgrades.deployBeacon("RareshopBrandContract.sol", owner);
        address implAddressV1 = IBeacon(beacon).implementation();
        console.log("beacon -> %s", beacon);
        console.log("implAddressV1 -> %s", implAddressV1);

        bytes memory data = abi.encodeCall(
            RareshopBrandContract.initialize,
            (address(0xB30435E5c90050127088c90Aa46A7F9f5db4C6c9), "templateBrandName", "0x0")
        );
        address beaconProxy = Upgrades.deployBeaconProxy(beacon, data);
        console.log("beaconProxy -> %s", beaconProxy);

        // contract upgrade
        // address beacon = address(0x156F45b4CEa8866AeEd05B27eB2f6ECB2bc0EBcd);
        // Upgrades.upgradeBeacon(beacon, "RareshopBrandContractV2.sol");

        vm.stopBroadcast();
    }
}

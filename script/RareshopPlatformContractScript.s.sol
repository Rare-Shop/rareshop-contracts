//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../src/RareshopPlatformContract.sol";

contract RareshopPlatformContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");

        address factoryProxy = Upgrades.deployUUPSProxy(
            "RareshopPlatformContract.sol", abi.encodeCall(RareshopPlatformContract.initialize, owner)
        );
        console.log("factoryProxy -> %s", factoryProxy);

        // Upgrades.upgradeProxy(
        // 0xfEcb1A0dc9D120942421f7369f2839c9615047C3,
        // "RareshopPlatformContract.sol",
        // ""
        // );
        vm.stopBroadcast();
    }
}

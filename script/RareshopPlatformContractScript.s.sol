//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../src/RareshopPlatformContract.sol";
import "../src/RareshopPlatformContractV2.sol";

contract RareshopPlatformContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");

        // address factoryProxy = Upgrades.deployUUPSProxy(
        //     "RareshopPlatformContract.sol", abi.encodeCall(RareshopPlatformContract.initialize, owner)
        // );
        // console.log("factoryProxy -> %s", factoryProxy);

        Upgrades.upgradeProxy(
        0xdeb905f0841beC44FE0611522dB90874f2a1d7fB,
        "RareshopPlatformContractV2.sol",
        ""
        );
        vm.stopBroadcast();
    }
}

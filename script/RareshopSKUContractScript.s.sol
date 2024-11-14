// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/templates/RareshopSKUContract.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract RareshopSKUContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.envAddress("OWNER");
        // address brand = address(0x58B4B418719a3557Ae0Dfc1e08063d11eD8D076A);
        // RareshopSKUContract.OptionalFeature memory feature = RareshopSKUContract.OptionalFeature(1, true, 0, 0, 0, 0);
        // bytes memory extendData = abi.encode(feature);

        address uupsProxy =
            Upgrades.deployUUPSProxy("RareshopSKUContract.sol", abi.encodeCall(RareshopSKUContract.initialize, (owner, "skuName", "skuSymbol", "")));

        console.log("uupsProxy deploy at %s", uupsProxy);

        // contract upgrade
        // Upgrades.upgradeProxy(
        //     0x57aA394Cd408c1dB3E0De979e649e82BF8dD395F,
        //     "RareshopSKUContract.sol",
        //     ""
        // );

        vm.stopBroadcast();
    }
}

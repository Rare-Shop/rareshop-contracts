// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/templates/RareshopBrandContract.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract RareshopBrandContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // address owner = vm.envAddress("OWNER");
        address platform = address(0xB30435E5c90050127088c90Aa46A7F9f5db4C6c9);

        address uupsProxy =
            Upgrades.deployUUPSProxy("RareshopBrandContract.sol", abi.encodeCall(RareshopBrandContract.initialize, (platform, platform, "brandName", "brandSymbol", platform, "0x0")));

        console.log("uupsProxy deploy at %s", uupsProxy);

        // contract upgrade
        // Upgrades.upgradeProxy(
        //     0x57aA394Cd408c1dB3E0De979e649e82BF8dD395F,
        //     "RareshopBrandContract.sol",
        //     ""
        // );

        vm.stopBroadcast();
    }
}

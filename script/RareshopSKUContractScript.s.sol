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

        RareshopSKUContract sku1 = new RareshopSKUContract();
        console.log("deploy -> %s", address(sku1));

        vm.stopBroadcast();
    }
}

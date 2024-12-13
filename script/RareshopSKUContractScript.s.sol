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

        // address owner = vm.envAddress("OWNER");
        // RareshopSKUContract.SKUConfig memory config = RareshopSKUContract.SKUConfig(1000000, 11, 1, 0, 9999999999, owner, 0xe58348e2b7d2f3111e238ae05ac3e379eacb42b320552514e9625837a683c34f);
        // RareshopSKUContract.Privilege[] memory privileges = new RareshopSKUContract.Privilege[](2);
        // privileges[0] = RareshopSKUContract.Privilege("name1", "desc1", 1, owner);
        // privileges[1] = RareshopSKUContract.Privilege("name2", "desc2", 0, address(0));
        // bytes memory configData = abi.encode(config);
        // bytes memory extendData = abi.encode(privileges);
        // sku1.initialize(owner, "skuName1", "sku", configData, extendData);

        vm.stopBroadcast();
    }
}

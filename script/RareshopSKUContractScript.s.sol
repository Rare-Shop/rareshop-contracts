// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/templates/RareshopSKUContract.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";

contract RareshopSKUContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.envAddress("OWNER");
        RareshopSKUContract.SKUConfig memory config = RareshopSKUContract.SKUConfig(11, 1, 1000000, 200, 201, owner);
        RareshopSKUContract.Privilege[] memory privileges = new RareshopSKUContract.Privilege[](2);
        privileges[0] = RareshopSKUContract.Privilege("name1", "desc1", 1, owner);
        privileges[1] = RareshopSKUContract.Privilege("name2", "desc2", 0, address(0));
        bytes memory configData = abi.encode(config);
        bytes memory extendData = abi.encode(privileges);
        Options memory opts;

        RareshopSKUContract sku1 = new RareshopSKUContract();
        sku1.initialize(owner, "skuName1", "sku", configData, extendData);

        // address contractAddr = Upgrades.deployImplementation("RareshopSKUContract.sol", opts);
        // address uupsProxy = Upgrades.deployUUPSProxy(
            // "RareshopSKUContract.sol",
            // abi.encodeCall(RareshopSKUContract.initialize, (owner, "skuName", "skuSymbol", configData, extendData))
        // );

        // console.log("deploy at %s", sku1);
        vm.stopBroadcast();
    }
}

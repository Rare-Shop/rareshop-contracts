// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/templates/RareshopSKUContract.sol";
import "../src/templates/RareshopBrandContract.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract RareshopSKUContractTest is Test {
    address constant OWNER_ADDRESS = 0xC565FC29F6df239Fe3848dB82656F2502286E97d;

    // address private proxy;
    // RareshopBrandContract private instance;

    // function setUp() public {
    //     console.log("=======setUp============");
    //         // struct SKUConfig {
    // //     address brandContract;
    // //     string displayName;
    // //     string cover;
    // //     uint256 supply;
    // //     uint256 mintPrice;
    // //     bool mintable;
    // //     uint64 userLimit;
    // //     uint64 mintStartTime;
    // //     uint64 mintEndTime;
    // //     uint64 exerciseStartTime;
    // //     uint64 exerciseEndTime;
    // // }
    //     address pContract = address(0xba8ed53aF0814534FDBDFA1dadF898f7ea6b8473);
    //     // RareshopSKUContract.SKUConfig memory config = RareshopSKUContract.SKUConfig(pContract, "disp", "cover", 11, 1000000, true, 2, 100, 101, 200, 201);
    //     bytes memory extendData = abi.encode("");

    //     proxy = Upgrades.deployUUPSProxy(
    //         "RareshopSKUContract.sol", abi.encodeCall(RareshopBrandContract.initialize, (OWNER_ADDRESS, "name1", "symbol1", pContract, extendData))
    //     );
    //     console.log("uups proxy -> %s", proxy);

    //     instance = RareshopBrandContract(proxy);
    //     assertEq(instance.owner(), OWNER_ADDRESS);

    //     address implAddressV1 = Upgrades.getImplementationAddress(proxy);
    //     console.log("impl proxy -> %s", implAddressV1);
    // }

    // function testMint() public {
    //     console.log("testMint");
    //     vm.startPrank(OWNER_ADDRESS);
    //     // address pContract = address(0xba8ed53aF0814534FDBDFA1dadF898f7ea6b8473);
    //     // RareshopSKUContract.SKUConfig memory config = RareshopSKUContract.SKUConfig(pContract, "disp", "cover", 11, 1000000, true, 2, 100, 101, 200, 201);
    //     // bytes memory extendData = abi.encode(config);
    //     vm.stopPrank();
    // }
}

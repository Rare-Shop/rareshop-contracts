// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/templates/RareshopSKUContract.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract RareshopSKUContractTest is Test {
    address constant OWNER_ADDRESS = 0xC565FC29F6df239Fe3848dB82656F2502286E97d;

    address private proxy;
    RareshopSKUContract private instance;

    function setUp() public {
        console.log("=======setUp============");
            // struct SKUConfig {
    //     address brandContract;
    //     string displayName;
    //     string cover;
    //     uint256 supply;
    //     uint256 mintPrice;
    //     bool mintable;
    //     uint64 userLimit;
    //     uint64 mintStartTime;
    //     uint64 mintEndTime;
    //     uint64 exerciseStartTime;
    //     uint64 exerciseEndTime;
    // }
        address bContract = address(0xe59d9616173f7d9CAbaa12093A5966521b60d9CD);
        RareshopSKUContract.SKUConfig memory config = RareshopSKUContract.SKUConfig(bContract, "disp", "cover", 11, 1000000, true, 2, 100, 101, 200, 201);
        bytes memory extendData = abi.encode(config);
        console.log(string(extendData));
        proxy = Upgrades.deployUUPSProxy(
            "RareshopSKUContract.sol", abi.encodeCall(RareshopSKUContract.initialize, (OWNER_ADDRESS, "name1", "symbol1", extendData))
        );
        console.log("uups proxy -> %s", proxy);

        instance = RareshopSKUContract(proxy);
        assertEq(instance.owner(), OWNER_ADDRESS);

        address implAddressV1 = Upgrades.getImplementationAddress(proxy);
        console.log("impl proxy -> %s", implAddressV1);
    }

    function testMint() public {
        console.log("testMint");
        vm.startPrank(OWNER_ADDRESS);
        address bContract = address(0xe59d9616173f7d9CAbaa12093A5966521b60d9CD);
        RareshopSKUContract.SKUConfig memory config = RareshopSKUContract.SKUConfig(bContract, "disp", "cover", 11, 1000000, true, 2, 100, 101, 200, 201);
        bytes memory extendData = abi.encode(config);
        console.log(string(extendData));

        assertEq(instance.getConfig().cover, "cover", "cover not match");
        assertEq(instance.getConfig().displayName, "disp", "displayName not match");
        assertEq(instance.getConfig().supply, 11, "supply not match");
        assertEq(instance.getConfig().brandContract, bContract, "brandContract not match");
        assertEq(instance.getConfig().mintPrice, 1000000, "mintPrice not match");
        assertEq(instance.getConfig().mintable, true, "mintable not match");
        assertEq(instance.getConfig().userLimit, 2, "userLimit not match");
        assertEq(instance.getConfig().mintStartTime, 100, "userLimit not match");
        assertEq(instance.getConfig().mintEndTime, 101, "userLimit not match");
        assertEq(instance.getConfig().exerciseStartTime, 200, "exerciseStartTime not match");
        assertEq(instance.getConfig().exerciseEndTime, 201, "exerciseEndTime not match");
        vm.stopPrank();
    }
}

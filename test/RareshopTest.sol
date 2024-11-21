// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/templates/RareshopSKUContract.sol";
import "../src/templates/RareshopBrandContract.sol";
import "../src/RareshopPlatformContract.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract RareshopBrandContractTest is Test {
    address constant OWNER_ADDRESS = 0xC565FC29F6df239Fe3848dB82656F2502286E97d;

    address private skuAddress;
    address private brandAddress;
    address private platformAddress;
    RareshopBrandContract private brandInstance;
    RareshopSKUContract private skuInstance;
    RareshopPlatformContract private platformInstance;


    function setUp() public {
        console.log("=======setUp============");

        platformAddress = Upgrades.deployUUPSProxy(
            "RareshopPlatformContract.sol", abi.encodeCall(RareshopPlatformContract.initialize, (OWNER_ADDRESS))
        );
        platformInstance = RareshopPlatformContract(platformAddress);

        brandAddress = Upgrades.deployUUPSProxy(
            "RareshopBrandContract.sol", abi.encodeCall(RareshopBrandContract.initialize, (OWNER_ADDRESS, "brand1", abi.encode("")))
        );
        brandInstance = RareshopBrandContract(brandAddress);

        RareshopSKUContract.SKUConfig memory config = RareshopSKUContract.SKUConfig(11, 2, 1000000, 0, 10000000000000000000, OWNER_ADDRESS, OWNER_ADDRESS, true);
        RareshopSKUContract.Privilege[] memory privileges = new RareshopSKUContract.Privilege[](2);
        privileges[0] = RareshopSKUContract.Privilege("name1", "desc1", 1);
        privileges[1] = RareshopSKUContract.Privilege("name2", "desc2", 0);
        bytes memory configData = abi.encode(config);
        bytes memory extendData = abi.encode(privileges);
        skuAddress = Upgrades.deployUUPSProxy(
            "RareshopSKUContract.sol", abi.encodeCall(RareshopSKUContract.initialize, (OWNER_ADDRESS, "sku1", "skuSymbol1", configData, extendData))
        );
        skuInstance = RareshopSKUContract(skuAddress);
    }

    function testMint() public {
        console.log("testMint");
        vm.startPrank(OWNER_ADDRESS);
        //     assertEq(userCoupons[0].value, 15, "coupon1 value not match");

        vm.stopPrank();
    }
}

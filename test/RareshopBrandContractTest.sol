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

        address[] memory implementations;
        platformAddress = Upgrades.deployUUPSProxy(
            "RareshopPlatformContract.sol", abi.encodeCall(RareshopPlatformContract.initialize, (implementations))
        );
        platformInstance = RareshopPlatformContract(platformAddress);


        bytes memory extendData1 = abi.encode("");
        brandAddress = Upgrades.deployUUPSProxy(
            "RareshopBrandContract.sol", abi.encodeCall(RareshopBrandContract.initialize, (OWNER_ADDRESS, OWNER_ADDRESS, "brand1", "symbol1", platformAddress, extendData1))
        );
        brandInstance = RareshopBrandContract(brandAddress);


        RareshopSKUContract.SKUConfig memory config = RareshopSKUContract.SKUConfig(brandAddress, "disp", "cover", 11, 1000000, true, 2, 100, 101, 200, 201);
        bytes memory extendData = abi.encode(config);
        console.log(string(extendData));
        skuAddress = Upgrades.deployUUPSProxy(
            "RareshopSKUContract.sol", abi.encodeCall(RareshopSKUContract.initialize, (OWNER_ADDRESS, "sku1", "skuSymbol1", extendData))
        );
        skuInstance = RareshopSKUContract(skuAddress);
    }

    function testMint() public {
        console.log("testMint");
        vm.startPrank(OWNER_ADDRESS);
        address[] memory skuAddresses;
        address[] memory skuAddresses2 = new address[](1);
        skuAddresses2[0] = skuAddress;
        brandInstance.setSKUContract(skuAddress, 1);
        uint64 couponId1 = brandInstance.createCoupon(skuAddresses, 15, 0, 0, 1);
        uint64 couponId2 = brandInstance.createCoupon(skuAddresses2, 10, 1, 0, 2);
        uint64 couponId3 = brandInstance.createCoupon(skuAddresses, 10, 0, 0, 3);
        assertEq(couponId1, 1, "couponId not match");
        assertEq(couponId2, 2, "couponId not match");

        RareshopBrandContract.Coupon[] memory userCoupons = brandInstance.getCoupons(OWNER_ADDRESS);
    //  struct Coupon{
    //     uint64[] skuNumbers;
    //     uint64 startTime;
    //     uint64 endTime;
    //     uint64 maxUseTimes;
    //     uint64 value;
    //     bool enable; //禁用 + 判空
    //     uint64 usedTimes;
    // }
        assertEq(userCoupons[0].value, 15, "coupon1 value not match");
        assertEq(userCoupons[0].enable, true, "coupon1 enable not match");
        assertEq(userCoupons[0].usedTimes, 0, "coupon1 usedTimes not match");
        assertEq(userCoupons[0].maxUseTimes, 1, "coupon1 maxUseTimes not match");
        assertEq(userCoupons[0].startTime, 0, "coupon1 startTime not match");
        assertEq(userCoupons[0].endTime, 0, "coupon1 endTime not match");
        assertEq(userCoupons[0].skuNumbers.length, 0, "coupon1 skuNumbers not match");
        assertEq(userCoupons[2].enable, true, "coupon3 enable not match");

        uint64 coupon1Value = brandInstance.useCoupon(couponId1, skuAddress);
        uint64 coupon2Value = brandInstance.useCoupon(couponId2, skuAddress);
        uint64 coupon3Value = brandInstance.useCoupon(couponId2, skuAddress);
        uint64[] memory deleteCoupons = new uint64[](1);
        deleteCoupons[0] = couponId3;
        brandInstance.deleteCoupons(deleteCoupons);

        assertEq(coupon1Value, 15, "coupon1Value not match");
        assertEq(coupon2Value, 10, "coupon2Value not match");

        RareshopBrandContract.Coupon[] memory userCoupons2 = brandInstance.getCoupons(OWNER_ADDRESS);
        assertEq(userCoupons2[0].usedTimes, 1, "coupon1 usedTimes not match after using");

        assertEq(userCoupons2[1].value, 10, "coupon2 value not match");
        assertEq(userCoupons2[1].enable, true, "coupon2 enable not match");
        assertEq(userCoupons2[1].usedTimes, 2, "coupon2 usedTimes not match");
        assertEq(userCoupons2[1].maxUseTimes, 2, "coupon2 maxUseTimes not match");
        assertEq(userCoupons2[1].skuNumbers.length, 1, "coupon2 skuNumbers not match");
        assertEq(userCoupons2[1].skuNumbers[0], 1, "coupon2 skuNumbers not match");
        
        assertEq(userCoupons2[2].enable, false, "coupon3 enable not match after delete");

        vm.stopPrank();
    }
}

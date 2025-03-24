// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/templates/RareshopSKUContract.sol";
import "../src/templates/RareshopBrandContract.sol";
import "../src/RareshopPlatformContract.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

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
        testDeploy();
    }

    function testDeploy() public {
        vm.startPrank(OWNER_ADDRESS);
        platformAddress = Upgrades.deployUUPSProxy(
            "RareshopPlatformContract.sol", abi.encodeCall(RareshopPlatformContract.initialize, (OWNER_ADDRESS))
        );
        platformInstance = RareshopPlatformContract(platformAddress);

        address beacon = Upgrades.deployBeacon("RareshopBrandContract.sol", OWNER_ADDRESS);
        bytes memory data;
        address brandTemplate = Upgrades.deployBeaconProxy(beacon, data);
        address skuTemplate = address(new RareshopSKUContract());

        platformInstance.setBrandImplementationTypes(1, brandTemplate);
        platformInstance.setSKUImplementationTypes(1, skuTemplate);

        bytes memory extendData;
        brandAddress = platformInstance.createBrandCollection("b1", 1, extendData);
        address brandAddress2 = platformInstance.createBrandCollection("b2", 1, extendData);
        brandInstance = RareshopBrandContract(brandAddress);

        RareshopSKUContract.SKUConfig memory config = RareshopSKUContract.SKUConfig({
            mintPrice:1000000,
            supply:3,
            userLimit:1,
            startTime:0,
            endTime:9999999999,
            paymentReceipientAddress:OWNER_ADDRESS,
            whiteListRoot:0x0000000000000000000000000000000000000000000000000000000000000000
        });
        RareshopSKUContract.Privilege[] memory privileges = new RareshopSKUContract.Privilege[](2);
        privileges[0] = RareshopSKUContract.Privilege("name1", "desc1", 1, OWNER_ADDRESS);
        privileges[1] = RareshopSKUContract.Privilege("name2", "desc2", 0, address(0));
        bytes memory configData = abi.encode(config);
        bytes memory privilegeData = abi.encode(privileges);
        skuAddress = brandInstance.createSKUCollection(1, "s1", "sbl1", configData, privilegeData);
        address skuAddress2 = brandInstance.createSKUCollection(1, "s2", "sbl2", configData, privilegeData);
        skuInstance = RareshopSKUContract(skuAddress);

        assertEq(platformInstance.brandImplementationTypes(1), brandTemplate, "plat brand templates err");
        assertEq(platformInstance.skuImplementationTypes(1), skuTemplate, "plat brand templates err");
        assertEq(platformInstance.brandContracts(0), brandAddress, "plat brandContracts err");
        assertEq(platformInstance.brandContracts(1), brandAddress2, "plat brandContracts err");

        assertEq(brandInstance.skuContracts(0), skuAddress, "brand skuContracts err");
        assertEq(brandInstance.skuContracts(1), skuAddress2, "brand skuContracts err");

        assertEq(skuInstance.mintable(), true, "sku mintable err");
        checkSKUConfig(config);
        checkSKUPrivilege(privileges[0], 1);
        checkSKUPrivilege(privileges[1], 2);

        vm.stopPrank();
    }

    function testBrand() public {
        vm.startPrank(OWNER_ADDRESS);
        address user1 = address(0x666b088c9ABeEbb2DdEf5149b3FB3907C54b584a);
        assertEq(brandInstance.isAdmin(OWNER_ADDRESS), true, "brand isAdmin case0 err");
        assertEq(brandInstance.isAdmin(user1), false, "brand isAdmin case1 err");
        brandInstance.addAdmin(user1);
        assertEq(brandInstance.isAdmin(user1), true, "brand isAdmin case2 err");
        brandInstance.removeAdmin(user1);
        assertEq(brandInstance.isAdmin(user1), false, "brand isAdmin case3 err");
        vm.stopPrank();
    }

    function testSKUConfig() public {
        vm.startPrank(OWNER_ADDRESS);
        RareshopSKUContract.Privilege memory newP = RareshopSKUContract.Privilege("name1", "desc1_new", 1, OWNER_ADDRESS);
        skuInstance.updatePrivilege(1, newP.description);
        checkSKUPrivilege(newP, 1);

        RareshopSKUContract.SKUConfig memory config2 = RareshopSKUContract.SKUConfig({
            mintPrice:1000001,
            supply:4,
            userLimit:2,
            startTime:1,
            endTime:9999999998,
            paymentReceipientAddress:address(0x666b088c9ABeEbb2DdEf5149b3FB3907C54b584a),
            whiteListRoot:0xe58348e2b7d2f3111e238ae05ac3e379eacb42b320552514e9625837a683c34f
        });
        skuInstance.updateSKUConfig(
            config2.supply, 
            config2.mintPrice, 
            config2.userLimit, 
            config2.startTime, 
            config2.endTime, 
            config2.paymentReceipientAddress, 
            config2.whiteListRoot
        );
        checkSKUConfig(config2);
        vm.stopPrank();
    }

    // function testSKUMint() public {
    //     bytes32[] memory proof;
    //     deal(skuInstance.USDT_ADDRESS(), OWNER_ADDRESS, 100000);
    //     skuInstance.mint(skuInstance.USDT_ADDRESS(), 1, proof);
    // }

    function checkSKUConfig(RareshopSKUContract.SKUConfig memory config) internal view {
        (uint64 mintPrice, uint64 supply, uint64 userLimit, uint64 startTime, uint64 endTime, address paymentReceipientAddress, bytes32 whiteListRoot) = skuInstance.config();
        assertEq(config.mintPrice, mintPrice, "mintPrice err");
        assertEq(config.supply, supply, "supply err");
        assertEq(config.userLimit, userLimit, "userLimit err");
        assertEq(config.startTime, startTime, "startTime err");
        assertEq(config.endTime, endTime, "endTime err");
        assertEq(config.paymentReceipientAddress, paymentReceipientAddress, "paymentReceipientAddress err");
        assertEq(config.whiteListRoot, whiteListRoot, "whiteListRoot err");
    }

    function checkSKUPrivilege(RareshopSKUContract.Privilege memory privilege, uint256 pIndex) internal view {
        (string memory name, string memory description, uint256 pType, address pAddr) = skuInstance.privileges(pIndex);
        assertEq(privilege.name, name, "name err");
        assertEq(privilege.description, description, "description err");
        assertEq(privilege.pType, pType, "pType err");
        assertEq(privilege.postageReceipientAddress, pAddr, "pAddr err");
    }

    function testWhitelist() public {
        console.log("testMint");
        vm.startPrank(OWNER_ADDRESS);
        bytes32[] memory proof1 = new bytes32[](4);
        proof1[0] = 0x194d4e161cbb37fb9767f0405cfd044db009e9a7587c797a1aa9daa5fc59ddb1;
        proof1[1] = 0xfbd2b70606992d9689fb85ba59505688989957e4a96f254c16509c4c023a616b;
        proof1[2] = 0x2e554555b3be0722f69c58c4cad446ce770ae23469683ff6d0e4469894b69468;
        proof1[3] = 0x5b498a3726b1d643e19c3cd982608c5da732c98b74b5ecfe6663e68e887ad416;
        assertEq(
            testProof(
                address(0x666b088c9ABeEbb2DdEf5149b3FB3907C54b584a), 
                proof1,
                0x662a54844263fb0d4962a35d83fbac7877482d8f9e5fb375ce94aa4a741a5352),
            true,
            "test1 failed"
        );

        bytes32[] memory proof2 = new bytes32[](4);
        proof2[0] = 0x1cbfa542518c365296ca5c8016b0c48e21c1123276e43b16be04350fac010c45;
        proof2[1] = 0xb8fc262cd7941ed3c0cdf556ebb3d49cf6f6c3806aecb6ef541052f28ba349cd;
        proof2[2] = 0xa9cab1701e2b7454203b679f3bdc3ff1a76fa671dd7dd1932590d5d0bf9d1a1b;
        proof2[3] = 0x5b498a3726b1d643e19c3cd982608c5da732c98b74b5ecfe6663e68e887ad416;
        assertEq(
            testProof(
                address(0x9546368849e3711e9E6f7c1Cce9de3d3e93B3cCC), 
                proof2,
                0x662a54844263fb0d4962a35d83fbac7877482d8f9e5fb375ce94aa4a741a5352),
            true,
            "test2 failed"
        );
        vm.stopPrank();
    }

    function testProof(address user, bytes32[] memory proof, bytes32 root) public pure returns(bool) {
        return MerkleProof.verify(proof, root, keccak256(abi.encode(user)));
    }
}

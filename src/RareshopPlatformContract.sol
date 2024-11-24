//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract RareshopPlatformContract is OwnableUpgradeable, UUPSUpgradeable {

    event RareshopBrandCreated(
        address indexed owner, 
        address indexed collectionAddress, 
        uint256 collectionType, 
        string name
    );

    mapping(uint256 => address) public brandImplementationTypes;
    mapping(uint256 => address) public skuImplementationTypes;
    // TODO 存储brandContracts的数组，添加一次性查询所有元素的function
    mapping(string => address) public brandContracts;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner) external initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
    }

    function createBrandCollection(
        string memory _name, 
        uint256 _collectionType, 
        bytes calldata _extendData
        )
        external
        returns (address)
    {
        require(brandImplementationTypes[_collectionType] != address(0), "Invalid Implementation Type");
        // TODO name不去重
        require(brandContracts[_name] == address(0), "Brand Name Already Exist");

        bytes32 salt = keccak256(abi.encode(msg.sender, _name, block.timestamp));
        address brandCollection = Clones.cloneDeterministic(brandImplementationTypes[_collectionType], salt);

        (bool success, bytes memory returnData) =
            // TODO 0x0eb624be 显式
            brandCollection.call(abi.encodeWithSelector(0x0eb624be, msg.sender, _name, _extendData));
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        // TODO 存储brandContracts的数组
        brandContracts[_name] = brandCollection;

        emit RareshopBrandCreated(msg.sender, brandCollection, _collectionType, _name);
        return brandCollection;
    }  

    function setBrandImplementationTypes(uint256 _collectionType, address _implementation) external onlyOwner {
        // TODO zero地址校验
        brandImplementationTypes[_collectionType] = _implementation;
    }

    function setSKUImplementationTypes(uint256 _collectionType, address _implementation) external onlyOwner {
        // TODO zero地址校验
        skuImplementationTypes[_collectionType] = _implementation;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}
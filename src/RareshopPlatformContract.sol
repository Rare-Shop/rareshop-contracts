//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";


contract RareshopPlatformContract is OwnableUpgradeable, UUPSUpgradeable {

    mapping(uint256 => address) public brandImplementationTypes;
    mapping(uint256 => address) public skuImplementationTypes;
    mapping(string => address) public brandContracts;

    event RareshopBrandCreated(address indexed owner, address indexed collectionAddress, uint256 collectionType, string name, string symbol);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address[] memory _implementations
    ) initializer external {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();
        for (uint i = 0; i < _implementations.length; i++) {
            brandImplementationTypes[i] = _implementations[i];
        }
    }

    function createBrandCollection(
        string memory _name,
        string memory _cover,
        uint256 _collectionType,
        bytes calldata _extendData
    ) external returns (address) {
        require(brandImplementationTypes[_collectionType] != address(0), "Invalid Implementation Type");
        require(brandContracts[_name] == address(0), "Brand Name Already Exist");

        address sender = _msgSender();
        bytes32 salt = keccak256(abi.encode(sender, _name, _cover, block.timestamp));
        address brandCollection = Clones.cloneDeterministic(brandImplementationTypes[_collectionType], salt);

        (bool success, bytes memory returnData) = brandCollection.call(abi.encodeWithSelector(
        0x6f7b86be, sender, _name, _cover, address(this), _extendData));
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        brandContracts[_name] = brandCollection;
        emit RareshopBrandCreated(msg.sender, brandCollection, _collectionType, _name, _cover);
        return brandCollection;
    }


    function setBrandImplementationTypes(uint256 _collectionType, address _implementation) external onlyOwner {
        brandImplementationTypes[_collectionType] = _implementation;
    }

    function getBrandImplementationCollection(uint256 _collectionType) external view returns(address) {
        return brandImplementationTypes[_collectionType];
    }

    function setSKUImplementationTypes(uint256 _collectionType, address _implementation) external onlyOwner {
        skuImplementationTypes[_collectionType] = _implementation;
    }

    function getSKUImplementationCollection(uint256 _collectionType) external view returns(address) {
        return skuImplementationTypes[_collectionType];
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}
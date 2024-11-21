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
    mapping(string => address) public brandContracts;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner) external initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
    }

    function createBrandCollection(string memory _name, uint256 _collectionType, bytes calldata _extendData)
        external
        returns (address)
    {
        require(brandImplementationTypes[_collectionType] != address(0), "Invalid Implementation Type");
        require(brandContracts[_name] == address(0), "Brand Name Already Exist");

        address sender = _msgSender();
        bytes32 salt = keccak256(abi.encode(sender, _name, block.timestamp));
        address brandCollection = Clones.cloneDeterministic(brandImplementationTypes[_collectionType], salt);

        (bool success, bytes memory returnData) =
            brandCollection.call(abi.encodeWithSelector(0x0eb624be, sender, _name, _extendData));
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        brandContracts[_name] = brandCollection;
        emit RareshopBrandCreated(msg.sender, brandCollection, _collectionType, _name);
        return brandCollection;
    }

    function setSKUImplementationTypes(uint256 _collectionType, address _implementation) external onlyOwner {
        skuImplementationTypes[_collectionType] = _implementation;
    }

    function setBrandImplementationTypes(uint256 _collectionType, address _implementation) external onlyOwner {
        brandImplementationTypes[_collectionType] = _implementation;
    }

    function getSKUImplementationCollection(uint256 _collectionType) external view returns(address) {
        return skuImplementationTypes[_collectionType];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
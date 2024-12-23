// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./templates/RareshopBrandContract.sol";

contract RareshopPlatformContract is OwnableUpgradeable, UUPSUpgradeable {

    event RareshopBrandCreated(
        address indexed owner, 
        address indexed collectionAddress, 
        uint256 collectionType, 
        string name
    );

    mapping(uint256 => address) public brandImplementationTypes;
    mapping(uint256 => address) public skuImplementationTypes;

    mapping(address => string) public brandNames;
    address[] public brandContracts;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner) external initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
    }

    function createBrandCollection(
        string calldata _name, 
        uint256 _collectionType, 
        bytes calldata _extendData
        )
        external
        returns (address)
    {
        address template = brandImplementationTypes[_collectionType];
        require(template != address(0), "Invalid Implementation Type");

        bytes32 salt = keccak256(abi.encode(msg.sender, _name, block.timestamp));
        address brandCollection = Clones.cloneDeterministic(template, salt);

        (bool success, bytes memory returnData) = brandCollection.call(
            abi.encodeCall(
                RareshopBrandContract.initialize, 
                (msg.sender, _name, _extendData)
            )
        );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        brandNames[brandCollection] = _name;
        brandContracts.push(brandCollection);

        emit RareshopBrandCreated(msg.sender, brandCollection, _collectionType, _name);
        return brandCollection;
    }

    function setBrandImplementationTypes(uint256 _collectionType, address _implementation) external onlyOwner {
        require(_implementation != address(0), "Implementation can not be address(0)");
        brandImplementationTypes[_collectionType] = _implementation;
    }

    function setSKUImplementationTypes(uint256 _collectionType, address _implementation) external onlyOwner {
        require(_implementation != address(0), "Implementation can not be address(0)");
        skuImplementationTypes[_collectionType] = _implementation;
    }

    function getBrandContracts() external view returns (address[] memory){
        return brandContracts;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}
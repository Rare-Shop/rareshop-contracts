// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../RareshopPlatformContract.sol";
import "./RareshopSKUContract.sol";

contract RareshopBrandContract is OwnableUpgradeable {

    string public constant SKU_BASE_URL = "https://image.rare.shop/";

    event RareshopSKUCreated(
        address indexed owner,
        address indexed skuCollectionAddress, 
        uint256 indexed skuId,
        string name
    );

    string public name;
    uint256 public nextSKUId;

    RareshopPlatformContract public platformCollection;

    address[] public skuContracts;

    mapping(address => bool) private admins;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyAdmin() {
        require(owner() == _msgSender() || admins[_msgSender()], "Invalid Admin");
        _;
    }

    function initialize(
        address _initialOwner,
        string calldata _name,
        bytes calldata
    ) external initializer {
        __Ownable_init(_initialOwner);

        name = _name;
        nextSKUId = 1;

        platformCollection = RareshopPlatformContract(_msgSender());
    }

    function createSKUCollection(
        uint256 _skuType,
        string calldata _name,
        string calldata _symbol,
        bytes calldata _skuConfigData,
        bytes calldata _privilegeData
    ) 
        external
        onlyAdmin
        returns (address)
    {
        address skuTemplate = platformCollection.skuImplementationTypes(_skuType);
        require(skuTemplate != address(0), "Invalid SKU Type");

        address skuCollection = Clones.cloneDeterministic(
            skuTemplate, 
            keccak256(abi.encode(msg.sender, _name, block.timestamp))
        );
        initSKUCollection(skuCollection, _name, _symbol, _skuConfigData, _privilegeData);

        skuContracts.push(skuCollection);
        emit RareshopSKUCreated(msg.sender, skuCollection, nextSKUId, _name);
        nextSKUId++;
        return skuCollection;
    }

    function initSKUCollection(
        address _skuCollection,
        string calldata _name,
        string calldata _symbol,
        bytes calldata _skuConfigData,
        bytes calldata _privilegeData
    ) 
        internal 
        onlyAdmin 
    {
        (bool success, bytes memory returnData) = _skuCollection.call(
            abi.encodeCall(
                RareshopSKUContract.initialize, 
                (_name, _symbol, _skuConfigData, _privilegeData)
            )
        );
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
    }

    function addAdmin(address _user) external onlyOwner {
        admins[_user] = true;
    }

    function removeAdmin(address _user) external onlyOwner {
        admins[_user] = false;
    }

    function isAdmin(address _user) external view returns (bool) {
        return admins[_user] || owner() == _user;
    }

    // RPC get all sku contracts at once
    function getSKUAddresses() external view returns (address[] memory) {
        return skuContracts;
    }

}
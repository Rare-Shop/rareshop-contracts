//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../RareshopPlatformContract.sol";

contract RareshopBrandContract is OwnableUpgradeable {

    string public constant SKU_BASE_URL = "https://images.rare.shop/";

    bytes4 private constant SKU_INIT_SELECTOR = 
        bytes4(keccak256("initialize(address,string,string,bytes,bytes)"));

    event RareshopSKUCreated(
        address indexed owner,
        address indexed skuCollectionAddress, 
        uint256 indexed skuId,
        string name
    );

    string public name;
    uint256 public nextSKUId;

    RareshopPlatformContract public platformCollection;

    mapping(uint256 => address) public skuContracts;
    mapping(address => uint256) public skuContractIds;

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
        require(platformCollection.skuImplementationTypes(_skuType) != address(0), "Invalid SKU Type");

        address skuCollection = Clones.cloneDeterministic(
            platformCollection.skuImplementationTypes(_skuType), 
            keccak256(abi.encode(msg.sender, _name, block.timestamp))
        );
        (bool success, bytes memory returnData) = skuCollection.call(abi.encodeWithSelector(
            SKU_INIT_SELECTOR, address(this), _name, _symbol, _skuConfigData, _privilegeData));
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        skuContracts[nextSKUId] = skuCollection;
        skuContractIds[skuCollection] = nextSKUId;

        emit RareshopSKUCreated(msg.sender, skuCollection, nextSKUId, _name);
        nextSKUId++;
        return skuCollection;
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

    function getSKUAddresses() external view returns (address[] memory) {
        address[] memory skuAddresses = new address[](nextSKUId - 1);
        for (uint256 i = 1; i < nextSKUId;) {
            skuAddresses[i - 1] = skuContracts[i];
            unchecked {
                ++i;
            }
        }
        return (skuAddresses);
    }

}
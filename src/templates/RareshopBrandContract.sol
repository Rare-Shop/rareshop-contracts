//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../RareshopPlatformContract.sol";

// TODO Beacon模式，不需要UUPS
contract RareshopBrandContract is OwnableUpgradeable, UUPSUpgradeable {

    event RareshopSKUCreated(
        address indexed owner,
        address indexed skuCollectionAddress, 
        uint256 indexed skuId,
        string name
    );

    string public name;
    uint256 public nextSKUId;

    RareshopPlatformContract public platformCollection;

    // TODO 添加查询skuCollections的function
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
        string memory _name,
        bytes calldata
    ) external initializer {
        __Ownable_init(_initialOwner);

        name = _name;
        nextSKUId = 1;

        platformCollection = RareshopPlatformContract(_msgSender());
    }

    function createSKUCollection(
        uint256 _skuType,
        string memory _name,
        string memory _symbol,
        bytes calldata _skuConfigData,
        bytes calldata _extendData
    ) external onlyAdmin returns (address) {
        address skuTemplate = platformCollection.skuImplementationTypes(_skuType);
        require(skuTemplate != address(0), "Invalid SKU Type");

        bytes32 salt = keccak256(abi.encode(msg.sender, _name, block.timestamp));
        address skuCollection = Clones.cloneDeterministic(skuTemplate, salt);

        (bool success, bytes memory returnData) = skuCollection.call(
            // TODO 0x75997620 显式
            // TODO address(this) 问题
            abi.encodeWithSelector(0x75997620, address(this), _name, _symbol, _skuConfigData, _extendData));
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

    // TODO 问题
    function updateSKUContract(address _skuAddress, bool forSale) external onlyAdmin {
        require(skuContractIds[_skuAddress] != 0, "skuAddress not exist");
        if (forSale) {
            skuContractIds[_skuAddress] = skuContractIds[_skuAddress] % 10000000000000000000;
        } else {
            skuContractIds[_skuAddress] = skuContractIds[_skuAddress] % 10000000000000000000 + 10000000000000000000;
        }
    }

    // TODO 问题
    function setName(string memory _name) external onlyAdmin {
        name = _name;
    }

    function addAdmin(address _user) external onlyOwner {
        admins[_user] = true;
    }

    function removeAdmin(address _user) external onlyOwner {
        admins[_user] = false;
    }

    function isAdmin(address _user) external view returns (bool) {
        return admins[_user];
    }

    // TODO 问题
    function getSKUAddresses() external view returns (address[] memory, bool[] memory) {
        address[] memory skuAddresses = new address[](nextSKUId-1);
        bool[] memory skuAddressStats = new bool[](nextSKUId-1);
        for (uint64 i = 1; i < nextSKUId;) {
            skuAddresses[i-1] = skuContracts[i];
            skuAddressStats[i-1] = skuContractIds[skuContracts[i]] > 10000000000000000000;
            unchecked {
                ++i;
            }
        }
        return (skuAddresses, skuAddressStats);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

}
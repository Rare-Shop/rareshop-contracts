//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../RareshopPlatformContract.sol";

contract RareshopBrandContract is OwnableUpgradeable, UUPSUpgradeable {

    event RareshopSKUCreated(
        address indexed skuCollectionAddress, 
        uint64 indexed id,
        string indexed name,
        address owner
    );

    string public name;
    uint64 public nextSKUId;
    RareshopPlatformContract public platformCollection;

    mapping(uint64 => address) public skuContracts;
    mapping(address => uint64) public skuContractIds;
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
        bytes calldata _extendData //暂时不用，方便后面扩展
    ) external initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        name = _name;
        platformCollection = RareshopPlatformContract(_msgSender());
        nextSKUId = 1;
    }

    function createSKUCollection(
        uint64 _skuType,
        string memory _name,
        string memory _symbol,
        bytes calldata _skuConfigData,
        bytes calldata _extendData
    ) external onlyAdmin returns (address) {
        address skuTemplate = platformCollection.getSKUImplementationCollection(_skuType);
        require(skuTemplate != address(0), "Invalid SKU Type");

        address sender = _msgSender();
        bytes32 salt = keccak256(abi.encode(sender, _name, block.timestamp));
        address skuCollection = Clones.cloneDeterministic(skuTemplate, salt);

        (bool success, bytes memory returnData) = skuCollection.call(
            abi.encodeWithSelector(0x75997620, address(this), _name, _symbol, _skuConfigData, _extendData));
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        skuContracts[nextSKUId] = skuCollection;
        skuContractIds[skuCollection] = nextSKUId;

        emit RareshopSKUCreated(skuCollection, nextSKUId, _name, sender);
        nextSKUId++;
        return skuCollection;
    }

    function updateSKUContract(address _skuAddress, bool forSale) external onlyAdmin {
        require(skuContractIds[_skuAddress] != 0, "skuAddress not exist");
        if(forSale){
            skuContractIds[_skuAddress] = skuContractIds[_skuAddress] % 10000000000000000000;
        } else {
            skuContractIds[_skuAddress] = skuContractIds[_skuAddress] % 10000000000000000000 + 10000000000000000000;
        }
    }

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
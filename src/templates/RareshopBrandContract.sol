//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../RareshopPlatformContract.sol";
contract RareshopBrandContract is OwnableUpgradeable, UUPSUpgradeable {
    struct Coupon{
        uint64 value;
        uint64 startTime;
        uint64 endTime;
        uint64 maxUseTimes;
        uint64 usedTimes;
        bool disable; 
        bool whiteList;
        bool skuLimit;
        uint64[] skuIds;
    }

    event RareshopSKUCreated(address indexed owner, address indexed collectionAddress, string name, string brandName);

    string public name;
    RareshopPlatformContract public platformCollection;
    uint64 public nextSKUId;

    mapping (address => bool) private admins;
    mapping (uint64 => address) public skuContracts;
    mapping (address => uint64) public skuContractIds;

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
    ) initializer external {
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
        bytes calldata _extendData
    ) external onlyAdmin returns (address) {
        address skuTemplate = platformCollection.getSKUImplementationCollection(_skuType);
        require(skuTemplate != address(0), "Invalid SKU Type");

        address sender = _msgSender();
        bytes32 salt = keccak256(abi.encode(sender, _name, block.timestamp));
        address skuCollection = Clones.cloneDeterministic(skuTemplate, salt);

        (bool success, bytes memory returnData) = skuCollection.call(abi.encodeWithSelector(0x267eb9ed, address(this), _name, _symbol, _extendData));
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        } 

        emit RareshopSKUCreated(sender, skuCollection, _name, name);
        skuContracts[nextSKUId] = skuCollection;
        skuContractIds[skuCollection] = nextSKUId++;
        return skuCollection;
    }

    function setSKUContract(address _skuAddress, uint64 _skuId) external onlyAdmin {
        require(_skuId > 0 && _skuId < nextSKUId, "skuId is illegal");
        skuContracts[_skuId] = _skuAddress;
        skuContractIds[_skuAddress] = _skuId;
    }

    function setName(string memory _name) external onlyAdmin() {
        name = _name;
    }

    function addAdmin(address _user) external onlyOwner {
        admins[_user] = true;
    }

    function removeAdmin(address _user) external onlyOwner {
        admins[_user] = false;
    }

    function isAdmin(address _user) external view returns(bool){
        return admins[_user];
    }

    function getSKUAddresses() external view returns (address[] memory) {
        address[] memory skuAddresses = new address[](nextSKUId-1);
        for(uint64 i = 0; i < nextSKUId - 1;){
            skuAddresses[i] = skuContracts[i+1];
        }
        return skuAddresses;
    }

    // todo 支持 owner(品牌方) 和 updater(平台方) becon 模式
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}
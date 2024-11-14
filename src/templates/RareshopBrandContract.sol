//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../RareshopPlatformContract.sol";
contract RareshopBrandContract is OwnableUpgradeable, UUPSUpgradeable {
    struct Coupon{
        uint64[] skuNumbers;
        uint64 startTime;
        uint64 endTime;
        uint64 maxUseTimes;
        uint64 value;
        bool enable; //禁用 + 判空
        uint64 usedTimes;
    }

    string public name;
    string public cover;
    address public platformCollection;
    address public updater;
    RareshopPlatformContract public platform;
    uint64 public nextSKUNumber;
    uint64 public nextCouponNumber;
    mapping (address => uint64) public skuContracts;
    mapping (uint64 => Coupon) public coupons;
    mapping (address => mapping (uint64 => uint64)) public usedCoupons;

    event RareshopSKUCreated(address indexed owner, address indexed collectionAddress, string name, string brandName);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyUpdater() {
        require(owner() == _msgSender() || updater == _msgSender(), "Invalid updater");
        _;
    }

    function initialize(
        address _initialOwner, 
        address _initialUpdater, 
        string memory _name, 
        string memory _cover,
        address _platformCollection,
        bytes calldata _extendData //暂时不用，方便后面扩展
    ) initializer external {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        updater = _initialUpdater;
        name = _name;
        cover = _cover;
        platformCollection = _platformCollection;
        platform = RareshopPlatformContract(_platformCollection);
        nextCouponNumber = 1;
        nextSKUNumber = 1;
    }

    function createSKUCollection(
        uint64 _skuType,
        string memory _name,
        string memory _symbol,
        bytes calldata _extendData
    ) external onlyOwner returns (address) {
        address skuTemplate = platform.getSKUImplementationCollection(_skuType);
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
        skuContracts[skuCollection] = nextSKUNumber++;
        return skuCollection;
    }

    function createCoupon(address[] memory _skuAddresses, uint64 _value, uint64 _startTime, uint64 _endTime, uint64 _maxUseTimes) external onlyOwner returns (uint64) {
        require(_value > 0, "value must greater than 0");
        require(_maxUseTimes > 0, "maxUseTimes must greater than 0");
        require(_endTime >= _startTime, "endTime must >= startTime");

        uint64[] memory skuNumbers = new uint64[](_skuAddresses.length);
        if(_skuAddresses.length > 0){
            for (uint i = 0; i < _skuAddresses.length; i++) {
                uint64 skuId = skuContracts[_skuAddresses[i]];
                require(skuId > 0, "sku address is not available");
                skuNumbers[i] = skuId;
            }
        }

        Coupon memory newCoupon = Coupon(skuNumbers, _startTime, _endTime, _maxUseTimes, _value, true, 0);
        coupons[nextCouponNumber] = newCoupon;
        return nextCouponNumber++;
    }

    function useCoupon(uint64 _couponNumber, address _skuAddress) external returns (uint64 value){
        require(_couponNumber > 0, "couponNumber must greater than 0");
        uint64 skuNumber = skuContracts[_skuAddress];
        require(skuNumber > 0, "skuNumber must greater than 0");
        Coupon memory coupon = coupons[_couponNumber];
        require(coupon.enable, "couponNumber is not available");
        uint64 usedTimes = usedCoupons[_msgSender()][_couponNumber];
        require(usedTimes < coupon.maxUseTimes, "coupon already used up");
        usedCoupons[_msgSender()][_couponNumber] = usedTimes + 1;

        if(coupon.skuNumbers.length > 0){
            uint16 index = 65535;
            for(uint16 i = 0; i < coupon.skuNumbers.length; i++){
                if(coupon.skuNumbers[i] == skuNumber){
                    index = i;
                    break;
                }
            }
            // 使用数组，95%的场景是单个商品或者所有商品，发券时避免动态新建 mapping 
            require(index != 65535, "coupon does not match");
        }

        return coupon.value;
    }

    function getCoupons(address user) external view returns(Coupon[] memory){
        Coupon[] memory myCoupons = new Coupon[](nextCouponNumber-1);
        for(uint64 i=1; i< nextCouponNumber; i++){
            Coupon memory coupon = coupons[i];
            coupon.usedTimes = usedCoupons[user][i];
            myCoupons[i] = coupon;
        }
        return myCoupons;
    }

    function deleteCoupons(uint64[] memory couponNumbers) external onlyOwner {
        for(uint i = 0; i< couponNumbers.length; i++){
            if(coupons[couponNumbers[i]].enable){
                delete coupons[couponNumbers[i]];
                // usedCoupons 怎么清理 todo
            }
        }
    }

    function setPlatformCollection(address _collection) external onlyOwner {
        platformCollection = _collection;
        platform = RareshopPlatformContract(_collection);
    }

    function setCover(string memory _cover) external onlyOwner {
        cover = _cover;
    }

    function setName(string memory _name) external onlyOwner {
        name = _name;
    }

    // todo 支持 owner(品牌方) 和 updater(平台方)
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyUpdater
        override
    {}
}
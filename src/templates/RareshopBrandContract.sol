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

    event RareshopCouponCreated(uint64 indexed couponId, uint64 indexed value, uint64 indexed maxUseTimes,         uint64 startTime, uint64 endTime, bool skuLimit);
    event RareshopCouponUsed(uint64 indexed couponId, address indexed user, address indexed sku, uint64 usedTimes);
    event RareshopCouponDeleted(uint64[] indexed couponIds);

    string public name;
    string public cover;
    address public updater;
    RareshopPlatformContract public platformCollection;
    uint64 public nextSKUId;
    uint64 public nextCouponId;

    mapping (uint64 => address) public skuContracts;
    mapping (address => uint64) public skuContractIds;

    mapping (uint64 => Coupon) public coupons;
    mapping (uint64 => mapping(address => bool)) public couponWhiteList;
    mapping (address => mapping (uint64 => uint64)) public usedCoupons;

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
        string memory _name, 
        bytes calldata _extendData //暂时不用，方便后面扩展
    ) initializer external {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        name = _name;
        platformCollection = RareshopPlatformContract(_msgSender());
        nextCouponId = 1;
        nextSKUId = 1;
    }

    function createSKUCollection(
        uint64 _skuType,
        string memory _name,
        string memory _symbol,
        bytes calldata _extendData
    ) external onlyOwner returns (address) {
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

    function createCoupon(address[] memory _skuAddresses, address[] memory _whiteList, uint64 _value, uint64 _startTime, uint64 _endTime, uint64 _maxUseTimes) external onlyOwner returns (uint64) {
        require(_value > 0, "value must greater than 0");
        require(_maxUseTimes > 0, "maxUseTimes must greater than 0");
        require(_endTime == 0 || _endTime >= _startTime, "endTime must >= startTime");
        require(_whiteList.length <= 200, "whiteList length exceed 200");

        uint64[] memory skuIds = new uint64[](_skuAddresses.length);
        bool skuLimit = false;
        if(_skuAddresses.length > 0){
            for (uint i = 0; i < _skuAddresses.length; i++) {
                uint64 skuId = skuContractIds[_skuAddresses[i]];
                require(skuId > 0, "sku address is not available");
                skuIds[i] = skuId;
            }
            skuLimit = true;
        }
        bool whiteListEnable = _whiteList.length > 0;
        for(uint64 i=0; i<_whiteList.length;i++){
            couponWhiteList[nextCouponId][_whiteList[i]] = true;
        }

        Coupon memory newCoupon = Coupon(_value, _startTime, _endTime, _maxUseTimes, 0, false, whiteListEnable, skuLimit, skuIds);
        coupons[nextCouponId] = newCoupon;
        emit RareshopCouponCreated(nextCouponId, _value, _maxUseTimes, _startTime, _endTime, skuLimit);
        return nextCouponId++;
    }

    function useCoupon(address _user, uint64 _couponId, address _skuAddress) external returns (uint64 value){
        require(_couponId > 0 && _couponId < nextCouponId, "couponId not available");
        uint64 skuId = skuContractIds[_skuAddress];
        require(skuId > 0, "skuAddress not available");
        Coupon memory coupon = coupons[_couponId];
        require(!coupon.disable, "couponId not available");
        require(!coupon.whiteList || couponWhiteList[_couponId][_user], "user not in whiteList");
        require(coupon.startTime <= block.timestamp && coupon.endTime >= block.timestamp, "coupon time range not match");

        uint64 usedTimes = usedCoupons[_user][_couponId];
        require(usedTimes < coupon.maxUseTimes, "coupon already used up");
        usedCoupons[_user][_couponId] = usedTimes + 1;

        if(coupon.skuLimit){
            uint16 index = 65535;
            for(uint16 i = 0; i < coupon.skuIds.length; i++){
                if(coupon.skuIds[i] == skuId){
                    index = i;
                    break;
                }
            }
            // 使用数组，95%的场景是单个商品或者所有商品，发券时避免动态新建 mapping 
            require(index != 65535, "coupon does not match");
        }
        emit RareshopCouponUsed(_couponId, _user, _skuAddress, usedCoupons[_user][_couponId]);
        return coupon.value;
    }

    function getCoupons(address user) external view returns(Coupon[] memory){
        Coupon[] memory myCoupons = new Coupon[](nextCouponId-1);
        for(uint64 i=1; i< nextCouponId; i++){
            Coupon memory coupon = coupons[i];
            coupon.usedTimes = usedCoupons[user][i];
            myCoupons[i-1] = coupon;
        }
        return myCoupons;
    }

    function deleteCoupons(uint64[] memory couponIds) external onlyOwner {
        for(uint i = 0; i< couponIds.length; i++) {
            coupons[couponIds[i]].disable = true;
        }
        emit RareshopCouponDeleted(couponIds);
    }

    function setSKUContract(address _skuAddress, uint64 _skuId) external onlyOwner {
        require(_skuId > 0 && _skuId < nextSKUId, "skuId is illegal");
        skuContracts[_skuId] = _skuAddress;
        skuContractIds[_skuAddress] = _skuId;
    }

    function setCover(string memory _cover) external onlyOwner {
        cover = _cover;
    }

    function setName(string memory _name) external onlyOwner {
        name = _name;
    }

    function getSKUAddresses() external view returns (address[] memory) {
        address[] memory skuAddresses = new address[](nextCouponId-1);
        for(uint64 i = 0; i < nextCouponId - 1;){
            skuAddresses[i] = skuContracts[i+1];
        }
        return skuAddresses;
    }

    // todo 支持 owner(品牌方) 和 updater(平台方)
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyUpdater
        override
    {}
}
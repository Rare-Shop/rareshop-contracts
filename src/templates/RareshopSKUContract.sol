// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IERC7765.sol";
import "../interfaces/IERC7765Metadata.sol";
import "../interfaces/IMetadataRenderer.sol";
import "./RareshopBrandContract.sol";


contract RareshopSKUContract is
    Initializable,
    ERC721Upgradeable,
    IERC7765,
    IERC7765Metadata,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    struct TimeRange {
        uint64 startTime;
        uint64 endTime;
    }

    struct Privilege {
        string name;
        string description;
        string imageUrl;
        string usedImageUrl;
        bool postable;
    }

    struct SKUConfig {
        uint64 supply;
        uint64 userLimit;
        uint64 mintPrice;
        bool mintable;
        string cover;
        TimeRange mintTime;
        TimeRange exerciseTime;
    }

    event RareshopSKUMinted(address indexed user, uint256[] indexed tokenIds, uint64 indexed couponId, uint256 originPrice, uint256 finalPrice );

    address public constant PAYMENT_RECEIPIENT_ADDRESS = 0xC0f068774D46ba26013677b179934Efd7bdefA3F;
    address public constant POSTAGE_RECEIPIENT_ADDRESS = 0xC0f068774D46ba26013677b179934Efd7bdefA3F;
    address public constant USDT_ADDRESS = 0xED85184DC4BECf731358B2C63DE971856623e056;
    address public constant USDC_ADDRESS = 0xBAfC2b82E53555ae74E1972f3F25D8a0Fc4C3682;

    uint256 private _nextTokenId;
    RareshopBrandContract internal brandCollection;
    SKUConfig public config;
    uint64 public sold;
    uint256 public maxPrivilegeId;

    mapping(address to => uint256 times) public mintTimes;
    mapping(uint256 privilegeId => Privilege item) privileges;
    mapping(uint256 tokenId => mapping(uint256 privilegeId => address to)) privilegeExercisedAddresses;
    mapping(uint256 tokenId => mapping(uint256 privilegeId => uint256 postage)) privilegeExercisedPostages;
    mapping(address owner => mapping(uint256 privilegeId => uint256[] tokenIds)) addressExercisedPrivileges;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier checkPrivilegeId(uint256 _privilegeId) {
        require(_privilegeId > 0 && _privilegeId <= maxPrivilegeId, "Invalid _privilegeId");
        _;
    }

    // 部署模板时调用, name symbol 不允许修改
    function initialize(
        address _initialOwner, 
        string memory _name,
        string memory _symbol,
        bytes calldata _configData,
        bytes calldata _extendData) external initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        
        brandCollection = RareshopBrandContract(_msgSender());
        if(_extendData.length > 0) {
            config = abi.decode(_configData, (SKUConfig));
            Privilege[] memory initPrivileges = abi.decode(_extendData, (Privilege[]));
            for(uint64 i=1; i<= initPrivileges.length;i++){
                privileges[i] = initPrivileges[i-1];
            }
            maxPrivilegeId = initPrivileges.length;
        }
    }

        // 创建商品时调用, 所有属性都可以修改
    function updateInfo(
        string memory _cover,
        uint64 _supply,
        uint64 _mintPrice,
        address _brandContract,
        bool _mintable,
        uint64 _userLimit,
        uint64 _mintStartTime,
        uint64 _mintEndTime,
        uint64 _exerciseStartTime,
        uint64 _exerciseEndTime) external onlyOwner returns (bytes memory) {
        config.cover = _cover;
        config.supply = _supply;
        config.mintPrice = _mintPrice;
        brandCollection = RareshopBrandContract(_brandContract);
        config.mintable = _mintable;
        config.userLimit = _userLimit;
        config.mintTime = TimeRange(_mintStartTime, _mintEndTime);
        config.exerciseTime = TimeRange(_exerciseStartTime, _exerciseEndTime);
        return abi.encode(config);
    }

    function getConfig() external view returns(SKUConfig memory) {
        return config;
    }

    function mint(
        address _payTokenAddress, 
        uint256 _amounts, 
        uint64 _couponId
    ) external {
        require(config.mintable, "mint not available");
        require(block.timestamp >= config.mintTime.startTime && block.timestamp <= config.mintTime.endTime, "Invalid Time Range");
        require(sold + _amounts <= config.supply, "mint amounts exceed limit");
        address sender = _msgSender();
        require(mintTimes[sender] + _amounts < config.userLimit, "user mint amounts exceed limit");

        require(
            _payTokenAddress == USDT_ADDRESS || _payTokenAddress == USDC_ADDRESS,
            "Only support USDT/USDC"
        );

        uint256 originPrice = config.mintPrice * _amounts;
        uint256 payPrice = originPrice;
        if(_couponId > 0){
            uint256 discountPrice = brandCollection.useCoupon(sender, _couponId, address(this));
            payPrice = originPrice - discountPrice;
        }

        IERC20 erc20Token = IERC20(_payTokenAddress);
        require(
            erc20Token.balanceOf(sender) >= payPrice,
            "Insufficient USD balance"
        );
        require(
            erc20Token.allowance(sender, address(this)) >= payPrice,
            "Allowance not set for USD"
        );

        erc20Token.safeTransferFrom(
            sender,
            PAYMENT_RECEIPIENT_ADDRESS,
            payPrice
        );

        mintTimes[sender] = mintTimes[sender] + _amounts;
        uint256[] memory mintedTokenIds = new uint256[](_amounts);
        for (uint256 i = 0; i < _amounts; ) {
            _mint(sender, ++_nextTokenId);
            mintedTokenIds[i] = _nextTokenId;
            unchecked {
                ++i;
            }
        }
        emit RareshopSKUMinted(sender, mintedTokenIds, _couponId, originPrice, payPrice);
    }

    function exercisePrivilege(
        address _to,
        uint256 _tokenId,
        uint256 _privilegeId,
        bytes calldata _data
    ) external override checkPrivilegeId(_privilegeId) {
        _requireOwned(_tokenId);
        require(block.timestamp >= config.exerciseTime.startTime && block.timestamp <= config.exerciseTime.endTime, "Invalid Time Range");

        address tokenOwner = _ownerOf(_tokenId);
        address sender = _msgSender();
        require(
            sender == tokenOwner,
            "Invalid address: sender must be owner of tokenID"
        );
        require(
            _to == tokenOwner,
            "Invalid address: _to must be owner of _tokenId"
        );

        if(privileges[_privilegeId].postable){
            (address payTokenAddress, uint256 postage) = abi.decode(_data,(address, uint256));
            require(
                payTokenAddress == USDT_ADDRESS || payTokenAddress == USDC_ADDRESS,
                "Only support USDT/USDC"
            );
            require(
                privilegeExercisedAddresses[_tokenId][_privilegeId] == address(0),
                "The tokenID has been exercised"
            );
            IERC20 erc20Token = IERC20(payTokenAddress);
            if (postage > 0) {
                erc20Token.safeTransferFrom(
                    sender,
                    POSTAGE_RECEIPIENT_ADDRESS,
                    postage
                );
                privilegeExercisedPostages[_tokenId][_privilegeId] = postage;
            }
            privilegeExercisedAddresses[_tokenId][_privilegeId] == _to;
            addressExercisedPrivileges[sender][_privilegeId].push(_tokenId);
        }

        emit PrivilegeExercised(sender, _to, _tokenId, _privilegeId);
    }

    function isExercisable(
        address _to,
        uint256 _tokenId,
        uint256 _privilegeId
    )
        external
        view
        override
        checkPrivilegeId(_privilegeId)
        returns (bool _exercisable)
    {
        _requireOwned(_tokenId);

        return
            _to == _ownerOf(_tokenId) &&
            privilegeExercisedAddresses[_tokenId][_privilegeId] == address(0);
    }

    function isExercised(
        address _to,
        uint256 _tokenId,
        uint256 _privilegeId
    )
        external
        view
        override
        checkPrivilegeId(_privilegeId)
        returns (bool _exercised)
    {
        _requireOwned(_tokenId);

        return
            privilegeExercisedAddresses[_tokenId][_privilegeId] != address(0) &&
            privilegeExercisedAddresses[_tokenId][_privilegeId] == _to;
    }

    function hasBeenExercised(
        uint256 _tokenId,
        uint256 _privilegeId
    ) external view checkPrivilegeId(_privilegeId) returns (bool _exercised) {
        _requireOwned(_tokenId);

        return privilegeExercisedAddresses[_tokenId][_privilegeId] != address(0);
    }

    function getPrivilegeIds(
        uint256 _tokenId
    ) external view returns (uint256[] memory privilegeIds) {
        _requireOwned(_tokenId);
        privilegeIds = new uint256[](maxPrivilegeId);
        for(uint64 i = 1; i<= maxPrivilegeId; i++){
            privilegeIds[i-1] = i;
        }
    }

    function setPrivilegeDescription(uint _privilegeId, string memory description) external onlyOwner checkPrivilegeId(_privilegeId){
        privileges[_privilegeId].description = description;
    }

    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        _requireOwned(_tokenId);
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(tokenURIJSON(_tokenId)))
                )
            );
    }

    function tokenURIJSON(uint256 _tokenId) public view returns (string memory) {
        string memory result = "[";
        for(uint64 privilegeId=1; privilegeId<maxPrivilegeId;privilegeId++){
            bool privilegeUsed = this.hasBeenExercised(_tokenId, privilegeId);
            string memory url = privilegeUsed ? privileges[privilegeId].usedImageUrl : privileges[privilegeId].imageUrl;
            string memory privilegeJSON = string(
                abi.encodePacked(
                    "{",
                    '"name": "',
                    privileges[privilegeId].name,
                    " #",
                    Strings.toString(_tokenId),
                    '",',
                    '"description": "',
                    privileges[privilegeId].description,
                    '",',
                    '"image": "',
                    url,
                    '",',
                    '"privilegeUsed": "',
                    privilegeUsed ? "true" : "false",
                    '"}'
                )
            );
            if(privilegeId > 1){
                result = string(abi.encodePacked(result,",", privilegeJSON));
            } else {
                result = string(abi.encodePacked(result,privilegeJSON));   
            }
        }

        return string(abi.encodePacked(result,"]"));
    }

    function privilegeURI(
        uint256 _privilegeId
    ) external view override checkPrivilegeId(_privilegeId) returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(privilegeURIJSON(_privilegeId)))
                )
            );
    }

    function privilegeURIJSON(
        uint256 _privilegeId
    ) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "{",
                    '"name": "',
                    privileges[_privilegeId].name,
                    " #",
                    Strings.toString(_privilegeId),
                    '",',
                    '"privilegeId": "',
                    Strings.toString(_privilegeId),
                    '",',
                    '"description": "',
                    privileges[_privilegeId].description,
                    '"}'
                )
            );
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(IERC7765).interfaceId ||
            interfaceId == type(IERC7765Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}

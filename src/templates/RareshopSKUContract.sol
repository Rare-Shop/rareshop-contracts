// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
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
    struct SKUConfig {
        address brandContract;
        string displayName;
        string cover;
        uint256 supply;
        uint256 mintPrice;
        bool mintable;
        uint64 userLimit;
        uint64 mintStartTime;
        uint64 mintEndTime;
        uint64 exerciseStartTime;
        uint64 exerciseEndTime;
    }

    using SafeERC20 for IERC20;
    address public metadataRenderer;
    address public privilegeMetadataRenderer;
    uint256 private _nextTokenId;

    address public constant PAYMENT_RECEIPIENT_ADDRESS =
        0xC0f068774D46ba26013677b179934Efd7bdefA3F;
    address public constant POSTAGE_RECEIPIENT_ADDRESS =
        0xC0f068774D46ba26013677b179934Efd7bdefA3F;
    address public constant USDT_ADDRESS =
        0xED85184DC4BECf731358B2C63DE971856623e056;
    address public constant USDC_ADDRESS =
        0xBAfC2b82E53555ae74E1972f3F25D8a0Fc4C3682;

    uint256 public constant PRIVILEGE_ID = 1;
    RareshopBrandContract internal brandCollection;
    SKUConfig public config;

    mapping(uint256 tokenId => address to) public tokenPrivilegeAddress;
    mapping(address to => uint256[] tokenIds) public addressPrivilegedUsedToken;
    mapping(uint256 tokenId => uint256 postage) public postageMessage;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // 部署模板时调用, name symbol 不允许修改
    function initialize(
        address _initialOwner, 
        string memory _name,
        string memory _symbol,
        bytes calldata _extendData) external initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();

        if(_extendData.length > 0) {
            config = abi.decode(_extendData, (SKUConfig));
        }
    }

        // 创建商品时调用, 所有属性都可以修改
    function updateInfo(
        string memory _displayName,
        string memory _cover,
        uint256 _supply,
        uint256 _mintPrice,
        address _brandContract,
        bool _mintable,
        uint64 _userLimit,
        uint64 _mintStartTime,
        uint64 _mintEndTime,
        uint64 _exerciseStartTime,
        uint64 _exerciseEndTime) external onlyOwner returns (bytes memory) {
        config.displayName = _displayName;
        config.cover = _cover;
        config.supply = _supply;
        config.mintPrice = _mintPrice;
        config.brandContract = _brandContract;
        brandCollection = RareshopBrandContract(_brandContract);
        config.mintable = _mintable;
        config.userLimit = _userLimit;
        config.mintStartTime = _mintStartTime;
        config.mintEndTime = _mintEndTime;
        config.exerciseStartTime = _exerciseStartTime;
        config.exerciseEndTime = _exerciseEndTime;
        return abi.encode(config);
    }

    modifier checkPrivilegeId(uint256 _privilegeId) {
        require(_privilegeId == PRIVILEGE_ID, "Invalid _privilegeId");
        _;
    }

    function getConfig() external view returns(SKUConfig memory) {
        return config;
    }

    function mint(address payTokenAddress, uint256 amounts, uint64 couponNumber) external {
        require(config.mintable, "mint not available");
        address sender = _msgSender();
        require(balanceOf(sender) < config.userLimit, "balance exceed limit");
        require(block.timestamp >= config.mintStartTime, "mint not start");
        require(config.mintEndTime == 0 || block.timestamp <= config.mintEndTime, "mint timeout");

        require(
            payTokenAddress == USDT_ADDRESS || payTokenAddress == USDC_ADDRESS,
            "Only support USDT/USDC"
        );
        require(
            amounts > 0 && amounts <= 10000,
            "One times max limit mint 10000"
        );
        
        uint64 discountPrice = brandCollection.useCoupon(couponNumber, address(this));
        uint256 payPrice = config.mintPrice * amounts - discountPrice; // todo 买十个可以用几张券？？

        IERC20 erc20Token = IERC20(payTokenAddress);
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

        for (uint256 i = 0; i < amounts; ) {
            _mint(sender, ++_nextTokenId);
            unchecked {
                ++i;
            }
        }
    }

    function exercisePrivilege(
        address _to,
        uint256 _tokenId,
        uint256 _privilegeId,
        bytes calldata _data
    ) external override checkPrivilegeId(_privilegeId) {
        require(block.timestamp >= config.exerciseStartTime, "exercisePrivilege not start");
        require(config.exerciseEndTime == 0 || block.timestamp <= config.exerciseEndTime, "exercisePrivilege timeout");

        _requireOwned(_tokenId);
        address tokenOwner = _ownerOf(_tokenId);
        address sender = _msgSender();
        (address payTokenAddress, uint256 postage) = abi.decode(
            _data,
            (address, uint256)
        );
        IERC20 erc20Token = IERC20(payTokenAddress);

        require(
            sender == tokenOwner,
            "Invalid address: sender must be owner of tokenID"
        );
        require(
            _to == tokenOwner,
            "Invalid address: _to must be owner of _tokenId"
        );

        require(
            tokenPrivilegeAddress[_tokenId] == address(0),
            "The tokenID has been exercised"
        );

        require(
            payTokenAddress == USDT_ADDRESS || payTokenAddress == USDC_ADDRESS,
            "Only support USDT/USDC"
        );

        if (postage > 0) {
            erc20Token.safeTransferFrom(
                sender,
                POSTAGE_RECEIPIENT_ADDRESS,
                postage
            );
            postageMessage[_tokenId] = postage;
        }

        tokenPrivilegeAddress[_tokenId] = _to;
        addressPrivilegedUsedToken[_to].push(_tokenId);

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
            tokenPrivilegeAddress[_tokenId] == address(0);
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
            tokenPrivilegeAddress[_tokenId] != address(0) &&
            tokenPrivilegeAddress[_tokenId] == _to;
    }

    function hasBeenExercised(
        uint256 _tokenId,
        uint256 _privilegeId
    ) external view checkPrivilegeId(_privilegeId) returns (bool _exercised) {
        _requireOwned(_tokenId);

        return tokenPrivilegeAddress[_tokenId] != address(0);
    }

    function getPrivilegeIds(
        uint256 _tokenId
    ) external view returns (uint256[] memory privilegeIds) {
        _requireOwned(_tokenId);
        privilegeIds = new uint256[](1);
        privilegeIds[0] = PRIVILEGE_ID;
    }

    function setMetadataRenderer(address _metadataRenderer) external onlyOwner {
        require(_metadataRenderer != address(0), "Invalid address");
        metadataRenderer = _metadataRenderer;
    }
    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        _requireOwned(_tokenId);
        return IMetadataRenderer(metadataRenderer).tokenURI(_tokenId);
    }

    function setPrivilegeMetadataRenderer(
        address _privilegeMetadataRenderer
    ) external onlyOwner {
        require(_privilegeMetadataRenderer != address(0), "Invalid address");
        privilegeMetadataRenderer = _privilegeMetadataRenderer;
    }

    function privilegeURI(
        uint256 _privilegeId
    )
        external
        view
        override
        checkPrivilegeId(_privilegeId)
        returns (string memory)
    {
        return
            IERC7765Metadata(privilegeMetadataRenderer).privilegeURI(
                _privilegeId
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

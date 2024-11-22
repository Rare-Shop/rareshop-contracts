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

    struct Privilege {
        string name;
        string description;
        uint64 pType; // 1 = postable
    }

    struct SKUConfig {
        uint64 supply;
        uint64 userLimit;
        uint64 mintPrice;
        uint64 startTime;
        uint64 endTime;
        address paymentReceipientAddress;
        address postageReceipientAddress;
        bool mintable;
    }

    event RareshopSKUMinted (
        address indexed user, 
        uint256[] indexed tokenIds, 
        uint256 indexed payPrice
    );

    address public constant USDT_ADDRESS = 0xED85184DC4BECf731358B2C63DE971856623e056;
    address public constant USDC_ADDRESS = 0xBAfC2b82E53555ae74E1972f3F25D8a0Fc4C3682;

    uint256 private _nextTokenId;
    RareshopBrandContract internal brandCollection;
    SKUConfig public config;
    string public baseUrl;
    uint64 public sold;
    uint256 public maxPrivilegeId;

    mapping(address to => uint256 times) public mintAmounts;
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

    modifier onlyAdmin() {
        require(owner() == _msgSender() || brandCollection.isAdmin(_msgSender()), "Invalid Admin");
        _;
    }

    function initialize(
        address _initialOwner,
        string memory _name,
        string memory _symbol,
        bytes calldata _configData,
        bytes calldata _extendData
    ) external initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        baseUrl = "https://rare.shop.images/";
        brandCollection = RareshopBrandContract(_msgSender());
        require(_configData.length > 0, "configData can not be empty");
        require(_extendData.length > 0, "extendData can not be empty");

        config = abi.decode(_configData, (SKUConfig));
        require(config.paymentReceipientAddress != address(0), "paymentReceipientAddress can not be empty");

        Privilege[] memory initPrivileges = abi.decode(_extendData, (Privilege[]));
        bool postable = false;
        for (uint64 i = 1; i <= initPrivileges.length;) {
            privileges[i] = initPrivileges[i - 1];
            if(initPrivileges[i - 1].pType == 1){
                require(!postable, "sku only have 1 postable privilege");
                postable = true;
            }
            unchecked {
                ++i;
            }
        }
        if(postable){
            require(config.postageReceipientAddress != address(0), "postageReceipientAddress can not be empty");
        }

        maxPrivilegeId = initPrivileges.length;
        require(maxPrivilegeId >= 1, "privileges can not be empty");
    }

    function mint(address _payTokenAddress, uint256 _amounts) external returns(uint256[] memory){
        require(config.mintable, "mint not available");
        require(block.timestamp >= config.startTime && block.timestamp <= config.endTime, "Invalid Time Range");
        require(sold + _amounts <= config.supply, "mint amounts exceed limit");
        
        address sender = _msgSender();
        require(mintAmounts[sender] + _amounts <= config.userLimit, "user mint amounts exceed limit");

        require(_payTokenAddress == USDT_ADDRESS || _payTokenAddress == USDC_ADDRESS, "Only support USDT/USDC");
        uint256 payPrice = config.mintPrice * _amounts;
        IERC20 erc20Token = IERC20(_payTokenAddress);
        require(erc20Token.balanceOf(sender) >= payPrice, "Insufficient USD balance");
        require(erc20Token.allowance(sender, address(this)) >= payPrice, "Allowance not set for USD");

        erc20Token.safeTransferFrom(sender, config.paymentReceipientAddress, payPrice);

        mintAmounts[sender] = mintAmounts[sender] + _amounts;
        uint256[] memory mintedTokenIds = new uint256[](_amounts);
        for (uint256 i = 0; i < _amounts;) {
            _mint(sender, _nextTokenId);
            mintedTokenIds[i] = ++_nextTokenId;
            unchecked {
                ++i;
            }
        }
        emit RareshopSKUMinted(sender, mintedTokenIds, payPrice);
        return mintedTokenIds;
    }

    function exercisePrivilege(address _to, uint256 _tokenId, uint256 _privilegeId, bytes calldata _data)
        external
        override
        checkPrivilegeId(_privilegeId)
    {
        _requireOwned(_tokenId);
        address tokenOwner = _ownerOf(_tokenId);
        address sender = _msgSender();
        require(sender == tokenOwner, "Invalid address: sender must be owner of tokenID");
        require(_to == tokenOwner, "Invalid address: _to must be owner of _tokenId");
        // 可以行权时 赠送给他人么？ todo
        // require(_to == tokenOwner, "Invalid address: _to must be owner of _tokenId");

        if (privileges[_privilegeId].pType == 1) {
            (address payTokenAddress, uint256 postage) = abi.decode(_data, (address, uint256));
            require(payTokenAddress == USDT_ADDRESS || payTokenAddress == USDC_ADDRESS, "Only support USDT/USDC");
            require(privilegeExercisedAddresses[_tokenId][_privilegeId] == address(0), "The tokenID has been exercised");
            IERC20 erc20Token = IERC20(payTokenAddress);
            if (postage > 0) {
                erc20Token.safeTransferFrom(sender, config.postageReceipientAddress, postage);
                privilegeExercisedPostages[_tokenId][_privilegeId] = postage;
            }
        }

        privilegeExercisedAddresses[_tokenId][_privilegeId] == _to;
        addressExercisedPrivileges[sender][_privilegeId].push(_tokenId);

        emit PrivilegeExercised(sender, _to, _tokenId, _privilegeId);
    }

    function isExercisable(address _to, uint256 _tokenId, uint256 _privilegeId)
        external
        view
        override
        checkPrivilegeId(_privilegeId)
        returns (bool _exercisable)
    {
        _requireOwned(_tokenId);

        return _to == _ownerOf(_tokenId) && privilegeExercisedAddresses[_tokenId][_privilegeId] == address(0);
    }

    function isExercised(address _to, uint256 _tokenId, uint256 _privilegeId)
        external
        view
        override
        checkPrivilegeId(_privilegeId)
        returns (bool _exercised)
    {
        _requireOwned(_tokenId);

        return privilegeExercisedAddresses[_tokenId][_privilegeId] != address(0)
            && privilegeExercisedAddresses[_tokenId][_privilegeId] == _to;
    }

    function hasBeenExercised(uint256 _tokenId, uint256 _privilegeId)
        external
        view
        checkPrivilegeId(_privilegeId)
        returns (bool _exercised)
    {
        _requireOwned(_tokenId);

        return privilegeExercisedAddresses[_tokenId][_privilegeId] != address(0);
    }

    function getPrivilegeIds(uint256 _tokenId) external view returns (uint256[] memory privilegeIds) {
        _requireOwned(_tokenId);

        privilegeIds = new uint256[](maxPrivilegeId);
        for (uint64 i = 1; i <= maxPrivilegeId;) {
            privilegeIds[i - 1] = i;
            unchecked {
                ++i;
            }
        }
    }

    function setPrivilege(uint256 _privilegeId, string memory _description, uint64 _type)
        external
        checkPrivilegeId(_privilegeId)
        onlyAdmin
    {
        privileges[_privilegeId].description = _description;
        privileges[_privilegeId].pType = _type;
    }

    function setSKUConfig(
        uint64 _supply,
        uint64 _mintPrice,
        uint64 _userLimit,
        uint64 _startTime,
        uint64 _endTime,
        bool _mintable
    ) external onlyAdmin {
        config.supply = _supply;
        config.mintPrice = _mintPrice;
        config.mintable = _mintable;
        config.userLimit = _userLimit;
        config.startTime = _startTime;
        config.endTime = _endTime;
    }

    function setBaseUrl(string memory _baseUrl) external onlyAdmin {
        baseUrl = _baseUrl;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        _requireOwned(_tokenId);
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(tokenURIJSON(_tokenId)))));
    }

    function tokenURIJSON(uint256 _tokenId) public view returns (string memory) {
        bytes memory privilegeIds = abi.encodePacked("1");
        for (uint64 privilegeId = 2; privilegeId < maxPrivilegeId;) {
            privilegeIds = abi.encodePacked(privilegeIds, ",", privilegeId);
            unchecked {
                ++privilegeId;
            }
        }

        return string(
            abi.encodePacked(
                "{",
                '"name": "',
                this.name(),
                " #",
                Strings.toString(_tokenId),
                '",',
                '"image": "',
                baseUrl,
                Strings.toHexString(uint160(address(this)), 20),
                ".jpg",
                '",',
                '"privilegeIds": "',
                string(privilegeIds),
                '"}'
            )
        );
    }

    function privilegeURI(uint256 _privilegeId)
        external
        view
        override
        checkPrivilegeId(_privilegeId)
        returns (string memory)
    {
        return string(
            abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(privilegeURIJSON(_privilegeId))))
        );
    }

    function privilegeURIJSON(uint256 _privilegeId) public view returns (string memory) {
        return string(
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

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC7765).interfaceId || interfaceId == type(IERC7765Metadata).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    function mockConfigData(
        SKUConfig memory _config,
        Privilege[] memory _privileges
    ) external view onlyOwner returns (bytes memory, bytes memory) {
        return (abi.encode(_config), abi.encode(_privileges));//调试时使用 todo，用完删掉
    }
}

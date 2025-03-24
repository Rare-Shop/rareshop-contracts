// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IERC7765.sol";
import "../interfaces/IERC7765Metadata.sol";
import "./RareshopBrandContract.sol";

contract RareshopSKUContract is
    Initializable,
    OwnableUpgradeable,
    ERC721Upgradeable,
    IERC7765,
    IERC7765Metadata
{
    using SafeERC20 for IERC20;

    struct Privilege {
        string name;
        string description;
        uint256 pType; // 1 = postage
        address postageReceipientAddress;
    }

    struct SKUConfig {
        uint64 mintPrice;
        uint64 supply;
        uint64 userLimit;
        uint64 startTime;
        uint64 endTime;
        address paymentReceipientAddress;
        bytes32 whiteListRoot;
    }

    event RareshopSKUMinted (
        address indexed minter, 
        uint256 indexed mintPrice,
        uint256[] tokenIds
    );

    event RareshopSKUPosted (
        address indexed to, 
        uint256 indexed tokenId, 
        uint256 indexed privilegeId, 
        uint256 postage
    );

    address public constant USDT_ADDRESS = 0xED85184DC4BECf731358B2C63DE971856623e056;
    address public constant USDC_ADDRESS = 0xBAfC2b82E53555ae74E1972f3F25D8a0Fc4C3682;

    uint256 public nextTokenId;
    uint256 public minted;
    uint256 public maxPrivilegeId;
    bool public mintable;
    RareshopBrandContract public brandCollection;
    address public brandCollectionAddr;
    SKUConfig public config;
    string private thisAddr;

    mapping(address to => uint256 amounts) public mintAmounts;
    mapping(uint256 privilegeId => Privilege privilege) public privileges;

    mapping(uint256 tokenId => mapping(uint256 privilegeId => address to)) 
        public privilegeExercisedAddresses;
    mapping(uint256 tokenId => mapping(uint256 privilegeId => uint256 postage)) 
        public privilegeExercisedPostages;
    mapping(address owner => mapping(uint256 privilegeId => uint256[] tokenIds)) 
        public addressExercisedPrivileges;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier checkPrivilegeId(uint256 _privilegeId) {
        require(_privilegeId > 0 && _privilegeId <= maxPrivilegeId, "Invalid _privilegeId");
        _;
    }

    modifier onlyAdmin() {
        require(brandCollection.isAdmin(_msgSender()), "Invalid Admin");
        _;
    }

    modifier checkWhiteList(bytes32[] calldata proof) {
        if(config.whiteListRoot != 0){
            bytes32 computedHash = keccak256(abi.encode(_msgSender()));
            for (uint256 i = 0; i < proof.length;) {
                if(uint256(computedHash) < uint256(proof[i])) {
                    computedHash = keccak256(abi.encode(computedHash, proof[i]));
                } else {
                    computedHash = keccak256(abi.encode(proof[i], computedHash));
                }
                unchecked {
                    ++i;
                }
            }
            require(computedHash == config.whiteListRoot, "msgSender not in whitelist");
        }
        _;
    }

    function initialize(
        address _initialOwner,
        string calldata _name,
        string calldata _symbol,
        bytes calldata _configData,
        bytes calldata _privilegeData
    ) external initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init(_initialOwner);

        __SKUConfig_init(_configData);
        __PrivilegeConfig_init(_privilegeData);
        brandCollectionAddr = _msgSender();
        brandCollection = RareshopBrandContract(brandCollectionAddr);
        mintable = true;
        thisAddr = toAsciiString(address(this));
    }

    function __SKUConfig_init(bytes calldata _configData) internal {
        require(_configData.length > 0, "_configData can not be empty");
        
        config = abi.decode(_configData, (SKUConfig));
        require(config.supply > 0, "supply must be larger than 0");
        require(config.startTime < config.endTime, "startTime must be smaller than endTime");
        require(config.userLimit > 0, "userLimit must be larger than 0");
        require(config.paymentReceipientAddress != address(0), "paymentReceipientAddress can not be empty");
    }

    function __PrivilegeConfig_init(bytes calldata _privilegeData) internal {
        require(_privilegeData.length > 0, "_privilegeData can not be empty");
        
        Privilege[] memory initPrivileges = abi.decode(_privilegeData, (Privilege[]));
        require(initPrivileges.length > 0, "privileges can not be empty");
        maxPrivilegeId = initPrivileges.length;

        bool postable = false;

        for (uint256 i = 1; i <= maxPrivilegeId;) {
            privileges[i] = initPrivileges[i - 1];

            if (initPrivileges[i - 1].pType == 1) {
                require(!postable, "Only one postage privilege can be configured");
                require(initPrivileges[i - 1].postageReceipientAddress != address(0), "postageReceipientAddress can not be empty");
                postable = true;
            }

            unchecked {
                ++i;
            }
        }
    }

    function mint(
        address _payTokenAddress, 
        uint256 _amounts, 
        bytes32[] calldata _whiteListProof
        ) 
        external 
        checkWhiteList(_whiteListProof)
        returns(uint256[] memory) 
    {
        require(mintable, "mint not available");
        require(_payTokenAddress == USDT_ADDRESS || _payTokenAddress == USDC_ADDRESS, "Only supporting USDT/USDC");
        require(block.timestamp >= config.startTime && block.timestamp <= config.endTime, "Out of sell time range");
        require((minted + _amounts) <= config.supply, "mint amounts exceed supply");
        
        address sender = _msgSender();
        require((mintAmounts[sender] + _amounts) <= config.userLimit, "user mint amounts exceed limit");
        
        IERC20 erc20Token = IERC20(_payTokenAddress);

        uint256 payPriceAll = config.mintPrice * _amounts;
        require(erc20Token.balanceOf(sender) >= payPriceAll, "Insufficient USD balance");
        require(erc20Token.allowance(sender, address(this)) >= payPriceAll, "Allowance not enough for USD");

        uint256 platformShare = payPriceAll * brandCollection.platformCollection().getPlatformShare(brandCollectionAddr) / 10000;
        if(platformShare > 0) {
            erc20Token.safeTransferFrom(
                sender, 
                brandCollection.platformCollection().receipientAddress(), 
                platformShare
            );
        }
        uint256 payPrice = payPriceAll - platformShare;
        if(payPrice > 0) {
            erc20Token.safeTransferFrom(
                sender,
                config.paymentReceipientAddress,
                payPrice
            );
        }

        mintAmounts[sender] = mintAmounts[sender] + _amounts;
        uint256[] memory mintedTokenIds = new uint256[](_amounts);
        for (uint256 i = 0; i < _amounts;) {
            _mint(sender, nextTokenId);
            mintedTokenIds[i] = nextTokenId++;
            unchecked {
                ++i;
            }
        }

        emit RareshopSKUMinted(sender, payPrice, mintedTokenIds);
        return mintedTokenIds;
    }

    function exercisePrivilege(
        address _to, 
        uint256 _tokenId, 
        uint256 _privilegeId, 
        bytes calldata _data
        )
        external
        override
        checkPrivilegeId(_privilegeId)
    {
        _requireOwned(_tokenId);

        address tokenOwner = _ownerOf(_tokenId);
        address sender = _msgSender();

        require(sender == tokenOwner, "Invalid address: _sender must be owner of tokenID");
        require(_to == tokenOwner, "Invalid address: _to must be owner of tokenID");

        require(privilegeExercisedAddresses[_tokenId][_privilegeId] == address(0), "The tokenID with privilegeID has been exercised");

        if (privileges[_privilegeId].pType == 1) {
            post(sender, _to, _tokenId, _privilegeId, _data);
        }

        privilegeExercisedAddresses[_tokenId][_privilegeId] = _to;
        addressExercisedPrivileges[_to][_privilegeId].push(_tokenId);

        emit PrivilegeExercised(sender, _to, _tokenId, _privilegeId);
    }

    function post(
        address _sender,
        address _to, 
        uint256 _tokenId, 
        uint256 _privilegeId, 
        bytes calldata _data
        )
        internal
    {
        (address payTokenAddress, uint256 postage) = abi.decode(_data, (address, uint256));
        require(payTokenAddress == USDT_ADDRESS || payTokenAddress == USDC_ADDRESS, "Only supporting USDT/USDC");

        if (postage > 0) {
            IERC20 erc20Token = IERC20(payTokenAddress);
            require(erc20Token.balanceOf(_sender) >= postage, "Insufficient USD balance");
            require(erc20Token.allowance(_sender, address(this)) >= postage, "Allowance not enough for USD");

            erc20Token.safeTransferFrom(_sender, privileges[_privilegeId].postageReceipientAddress, postage);
            privilegeExercisedPostages[_tokenId][_privilegeId] = postage;
            emit RareshopSKUPosted(_to, _tokenId, _privilegeId, postage);
        }
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

        return _to != address(0) && privilegeExercisedAddresses[_tokenId][_privilegeId] == _to;
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
        for (uint256 i = 1; i <= maxPrivilegeId;) {
            privilegeIds[i - 1] = i;
            unchecked {
                ++i;
            }
        }
    }

    function updatePrivilege(uint256 _privilegeId, string calldata _description)
        external
        checkPrivilegeId(_privilegeId)
        onlyAdmin
    {
        privileges[_privilegeId].description = _description;
    }

    function updateSKUConfig(
        uint64 _supply,
        uint64 _mintPrice,
        uint64 _userLimit,
        uint64 _startTime,
        uint64 _endTime,
        address _paymentReceipientAddress,
        bytes32 _whiteListRoot
    ) external onlyAdmin {
        require(_supply > 0, "supply must be larger than 0");
        require(_startTime < _endTime, "startTime must be smaller than endTime");
        require(_userLimit > 0, "userLimit must be larger than 0");
        require(_paymentReceipientAddress != address(0), "paymentReceipientAddress can not be empty");
        
        config.mintPrice = _mintPrice;
        config.supply = _supply;
        config.userLimit = _userLimit;
        config.startTime = _startTime;
        config.endTime = _endTime;
        config.paymentReceipientAddress = _paymentReceipientAddress;
        config.whiteListRoot = _whiteListRoot;
    }

    function setMintable(bool _mintable) external onlyAdmin {
        mintable = _mintable;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        _requireOwned(_tokenId);
        return string(abi.encodePacked("data:application/json;base64,", 
            Base64.encode(bytes(tokenURIJSON(_tokenId)))));
    }

    function tokenURIJSON(uint256 _tokenId) public view returns (string memory) {
        return string(
            abi.encodePacked(
                "{",
                '"name": "',
                name(),
                " #",
                Strings.toString(_tokenId),
                '",',
                '"image": "',
                brandCollection.SKU_BASE_URL(),
                thisAddr,
                ".png",
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
        return string(abi.encodePacked("data:application/json;base64,", 
            Base64.encode(bytes(privilegeURIJSON(_privilegeId)))));
    }

    function privilegeURIJSON(uint256 _privilegeId) 
        public 
        view 
        returns (string memory) 
    {
        return string(
            abi.encodePacked(
                "{",
                '"id": "',
                Strings.toString(_privilegeId),
                '",',
                '"name": "',
                privileges[_privilegeId].name,
                '",',
                '"description": "',
                privileges[_privilegeId].description,
                '"}'
            )
        );
    }

    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20;) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);
            unchecked {
                ++i;
            }
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC7765).interfaceId 
            || interfaceId == type(IERC7765Metadata).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function mockConfigData(
        SKUConfig memory _config,
        Privilege[] memory _privileges
    ) external pure returns (bytes memory, bytes memory) {
        return (abi.encode(_config), abi.encode(_privileges)); // for debugging
    }
}

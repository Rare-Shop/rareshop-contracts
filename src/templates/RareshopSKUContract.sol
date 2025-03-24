// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract RareshopSKUContract is
    Initializable,
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

    uint256 private nextTokenId;
    RareshopBrandContract public brandCollection;
    address public brandCollectionAddr;
    string private thisAddr;

    SKUConfig public config;
    bool public mintable;
    mapping(address to => uint256 amounts) public mintAmounts;
    uint256 public maxPrivilegeId;
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

    modifier checkWhiteList(bytes32[] memory proof) {
        if(config.whiteListRoot != 0) {
            require(
                MerkleProof.verify(proof, config.whiteListRoot, keccak256(abi.encode(_msgSender()))), 
                "MsgSender not in whitelist"
            );
        }
        _;
    }

    function initialize(
        string calldata _name,
        string calldata _symbol,
        bytes calldata _configData,
        bytes calldata _privilegeData
    ) external initializer {
        __ERC721_init(_name, _symbol);
        __SKUConfig_init(_configData);
        __PrivilegeConfig_init(_privilegeData);

        nextTokenId = 1;
        brandCollectionAddr = _msgSender();
        brandCollection = RareshopBrandContract(brandCollectionAddr);
        mintable = true;
        thisAddr = Strings.toHexString(address(this));
    }

    function __SKUConfig_init(bytes calldata _configData) internal {
        require(_configData.length > 0, "_configData can not be empty");
        
        config = abi.decode(_configData, (SKUConfig));
        require(config.userLimit > 0, "userLimit must be larger than 0");
        require(config.userLimit <= config.supply, "userLimit must be smaller than supply");
        require(config.paymentReceipientAddress != address(0), "paymentReceipientAddress can not be empty");
        require(config.startTime < config.endTime, "startTime must be smaller than endTime");
        require(config.endTime > block.timestamp, "endTime must be larger than block.timestamp");
    }

    function __PrivilegeConfig_init(bytes calldata _privilegeData) internal {
        require(_privilegeData.length > 0, "_privilegeData can not be empty");
        
        Privilege[] memory initPrivileges = abi.decode(_privilegeData, (Privilege[]));
        require(initPrivileges.length > 0, "Privileges can not be empty");
        maxPrivilegeId = initPrivileges.length;

        bool postable = false;

        for (uint256 i = 1; i <= maxPrivilegeId;) {
            privileges[i] = initPrivileges[i - 1];

            if (initPrivileges[i - 1].pType == 1) {
                require(!postable, "Only one postage privilege can be configured");
                require(initPrivileges[i - 1].postageReceipientAddress != address(0), "PostageReceipientAddress can not be empty");
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
        require(mintable, "Mint not available");
        require(_payTokenAddress == USDT_ADDRESS || _payTokenAddress == USDC_ADDRESS, "Only supporting USDT/USDC");
        require(block.timestamp >= config.startTime && block.timestamp <= config.endTime, "Out of sell time range");
        require((nextTokenId - 1 + _amounts) <= config.supply, "Mint amounts exceed supply");
        
        address sender = _msgSender();
        uint256 userMinted = mintAmounts[sender];
        require((userMinted + _amounts) <= config.userLimit, "User mint amounts exceed limit");
        mintAmounts[sender] = userMinted + _amounts;
        
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
            _safeMint(sender, nextTokenId);
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
        require(_userLimit > 0, "userLimit must be larger than 0");
        require(_userLimit <= _supply, "userLimit must be smaller than supply");
        require(_paymentReceipientAddress != address(0), "paymentReceipientAddress can not be empty");
        require(_startTime < _endTime, "startTime must be smaller than endTime");
        require(_endTime > block.timestamp, "endTime must be larger than block.timestamp");

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

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC7765).interfaceId 
            || interfaceId == type(IERC7765Metadata).interfaceId
            || super.supportsInterface(interfaceId);
    }
}

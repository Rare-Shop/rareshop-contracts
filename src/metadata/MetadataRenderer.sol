// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "../interfaces/IMetadataRenderer.sol";
import "../templates/RareshopSKUContract.sol";

contract MetadataRenderer is IMetadataRenderer, Ownable {
    string private imageURI;
    string private privilegeUsedimageURI;
    string private name;
    string private description;

    RareshopSKUContract skuContract;

    constructor(
        string memory _defaultName,
        string memory _description
    ) Ownable(_msgSender()) {
        name = _defaultName;
        description = _description;
    }

    function tokenURI(
        uint256 tokenID
    ) external view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(tokenURIJSON(tokenID)))
                )
            );
    }

    function tokenURIJSON(uint256 tokenID) public view returns (string memory) {
        require(
            address(skuContract) != address(0),
            "MetadataRenderer: Contract instance is not set"
        );
        bool privilegeUsed = skuContract.hasBeenExercised(
            tokenID,
            skuContract.PRIVILEGE_ID()
        );

        string memory url = privilegeUsed ? privilegeUsedimageURI : imageURI;
        return
            string(
                abi.encodePacked(
                    "{",
                    '"name": "',
                    name,
                    " #",
                    Strings.toString(tokenID),
                    '",',
                    '"description": "',
                    description,
                    '",',
                    '"image": "',
                    url,
                    '",',
                    '"privilegeUsed": "',
                    privilegeUsed ? "true" : "false",
                    '"}'
                )
            );
    }

    function setName(string calldata _newName) external onlyOwner {
        name = _newName;
    }

    function setImageUri(string calldata _newURI) external onlyOwner {
        imageURI = _newURI;
    }
    function setPrivilegeUsedimageURI(
        string calldata _newPrivilegeUsedimageURI
    ) external onlyOwner {
        privilegeUsedimageURI = _newPrivilegeUsedimageURI;
    }

    function setDescription(string calldata _description) external onlyOwner {
        description = _description;
    }
    function setNFTContract(
        address _skuContractAddress
    ) external onlyOwner {
        skuContract = RareshopSKUContract(_skuContractAddress);
    }
}

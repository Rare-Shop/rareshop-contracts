// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "../interfaces/IERC7765Metadata.sol";

contract ERC7765Metadata is IERC7765Metadata, Ownable {
    string private name;
    string private description;

    constructor(
        string memory _defaultName,
        string memory _description
    ) Ownable(_msgSender()) {
        name = _defaultName;
        description = _description;
    }

    function privilegeURI(
        uint256 _privilegeId
    ) external view returns (string memory) {
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
                    name,
                    " #",
                    Strings.toString(_privilegeId),
                    '",',
                    '"privilegeId": "',
                    Strings.toString(_privilegeId),
                    '",',
                    '"description": "',
                    description,
                    '"}'
                )
            );
    }

    function setName(string calldata _newName) external onlyOwner {
        name = _newName;
    }

    function setDescription(string calldata _description) external onlyOwner {
        description = _description;
    }
}

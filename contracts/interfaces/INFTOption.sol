// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INFTOption {

    
    
    // function mintOption(uint8 tokenId) external;
    // function mintOptions(uint8[] memory tokenId) external;

    // function withdrawNft() external;
    // function withdrawAllNft() external;

    function settle(uint256 strike_, address buyersVaultAddress) external;


}
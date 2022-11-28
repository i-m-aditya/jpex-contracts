// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

interface IVault {
    function create(
        string memory nft,
        uint256 capacity, 
        uint256 premium
    ) external ;
}
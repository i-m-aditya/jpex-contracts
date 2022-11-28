// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./libraries/Authorizable.sol";
import "./NftOptionBuyersVault.sol";
import "@rari-capital/solmate/src/utils/Bytes32AddressLib.sol";

contract NftOptionBuyersVaultFactory is Authorizable {
    using Bytes32AddressLib for address;
    using Bytes32AddressLib for bytes32;

    function deployVault(
        string memory nft
    ) external returns (NftOptionBuyersVault vault) {
        bytes32 salt = keccak256(abi.encode(nft));
        vault = new NftOptionBuyersVault{salt: salt}(
            nft
        );
    }

    /*///////////////////////////////////////////////////////////////
                            VAULT LOOKUP LOGIC
    //////////////////////////////////////////////////////////////*/

    /***
     @notice Computes a Vault's address from its accepted NFT, strike, expiry.
     @param nft Underlying NFT
     @return The address of a Vault which accepts the provided underlying token.
     @dev The Vault returned may not be deployed yet. 
     */
    function getVaultFromOptionParams(
        string memory nft
    ) external view returns (NftOptionBuyersVault) {
        return
            NftOptionBuyersVault(
                keccak256(
                    abi.encodePacked(
                        // Prefix:
                        bytes1(0xFF),
                        // Creator:
                        address(this),
                        // Salt:
                        keccak256(abi.encode(nft)),
                        // Bytecode hash:
                        keccak256(
                            abi.encodePacked(
                                // Deployment bytecode:
                                type(NftOptionBuyersVault).creationCode,
                                // Constructor arguments:
                                abi.encode(nft)
                            )
                        )
                    )
                ).fromLast20Bytes() // Convert the CREATE2 hash into an address.
                
            );
    }

    /***
    @notice Returns if a Vault at an address has already been deployed.
     @param vault The address of a Vault which may not have been deployed yet.
     @return A boolean indicating whether the Vault has been deployed already.
      */
    function isVaultDeployed(NftOptionBuyersVault vault) external view returns (bool) {
        return address(vault).code.length > 0;
    }

}
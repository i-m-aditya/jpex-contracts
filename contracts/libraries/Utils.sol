// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";

library Utils {
    using FixedPointMathLib for uint256;

    uint256 public constant BASE_UNIT = 10**18;
    uint256 public constant ONE = 10 ** 18;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 public constant PRE_LIQUIDATION_WINDOW = 2 hours;


    function getNftOptionVaultName(
        string memory nft,
        uint256 strike,
        uint256 expiry,
        uint8 optionType
    ) external pure returns (string memory nftOptionVaultName) {
        
        // To update expiry in format ddmmyy
        // DateString.timestampToDateString(expiry, expiryInDateString);
        return string(
                        abi.encode(
                            (optionType == 0) ? "C-" : "P-",
                            nft,
                            "-",
                            strike.mulDivDown(1, BASE_UNIT),
                            "-",
                            expiry
                        )   
                );
    }

    function concatenate(string memory a, string memory b) external pure returns (string memory) {
        return string(abi.encode(a, b));
    }

    
}
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library Constants {
    uint256 public constant BASE_UNIT = 10**18;
    uint256 public constant ONE = 10 ** 18;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 public constant PRE_LIQUIDATION_WINDOW = 2 hours;
}
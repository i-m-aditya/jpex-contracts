# Jpex

On-chain NFTs option trading platform which allows user to **speculate**, **hedge** and **earn income** from NFTs. 

## Contracts

```ml
contracts
├─ NftOptionBuyersVaultFactory — "Create buyers vaults using this contract eg: Bayc Vault, Cryptopunks Vault"
├─ NftOptionBuyersVault — "Entry point for creation and start of epoch. It offers following functionalities" 
│  ├─ startNewEpoch
│  ├─ depositInOptionBuyersVault
│  ├─ withdrawFromOptionBuyersVault
│  ├─ claimEarningForStrike
│  ├─ provideLiquidityToOptionSellersVault
├─ NftOptionSellersVaultFactory - "Create sellers vault which allows option writers to deposit NFT and mint option"
├─ NftOptionSellersVault — "It offers following functionalities:"
│  ├─ bootstrap - "Bootstraps a new epoch and mints option tokens equivalent to user deposits for the epoch"
│  ├─ depositNftAndMintOption
│  ├─ depositMultipleNftAndMintOptions
│  ├─ withdrawAllClaimableNFTs
│  ├─ settle
│  ├─ liquidateNFT - "When option writer have not deposited the settlement difference in the alloted settlement window"
```

## Safety

This is **experimental software** and is provided on an "as is" and "as available" basis. Contracts are not optimized, will be optimizing them in public.

## Acknowledgements

These contracts were inspired by or directly modified from many sources, primarily:

- [solmate](https://github.com/transmissions11/solmate)
- [Uniswap](https://github.com/Uniswap/uniswap-lib)
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [UMA](https://github.com/UMAprotocol/protocol)

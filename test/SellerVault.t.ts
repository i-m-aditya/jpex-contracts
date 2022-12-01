import { expect, util } from "chai";
import { Contract } from "ethers";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  IERC20,
  IERC721,
  NftOptionSellersVault,
  NftOptionSellersVaultFactory,
  Utils,
} from "../typechain";
import { getNumInUnits } from "./helpers/deploytest";
import { JsonRpcSigner } from "@ethersproject/providers";
import { impersonate } from "./helpers/impersonate";

describe("NftOptionSellersVaultFactory test", function () {
  let utilsLib: Utils;
  let nosvFactory: NftOptionSellersVaultFactory;
  let deployer: SignerWithAddress,
    governance: SignerWithAddress,
    manager: SignerWithAddress,
    tempBuyerVault: SignerWithAddress,
    nftOwner: SignerWithAddress;
  let tx;
  let sellersVault: NftOptionSellersVault;
  let whaleAddress = "0x0c4809be72f9e117d75381438c5daec8abe75bad";

  let whale: SignerWithAddress;
  let wethAddress = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";
  let $weth: IERC20;
  let epochStrikeTokens = ["", ""];
  let nftContract: IERC721;
  /**
   * NFT Constants
   */
  const nft = "World Of Women";
  const contractAddress = "0xe785e82358879f061bc3dcac6f0444462d4b5330";
  const tokenId = 6025;
  const nftOwnerAddress = "0x7A9fe22691c811ea339D9B73150e6911a5343DcA";
  const strikes = [getNumInUnits(8, 18), getNumInUnits(9, 18)];
  const premiums = [getNumInUnits(2, 18), getNumInUnits(1, 18)];

  before(async () => {
    [deployer, tempBuyerVault] = await ethers.getSigners();
    const Utils = await ethers.getContractFactory("Utils");
    utilsLib = await Utils.deploy();
    await utilsLib.deployed();

    const SellerVaultFactory = await ethers.getContractFactory(
      "NftOptionSellersVaultFactory"
    );
    nosvFactory = await SellerVaultFactory.deploy();
    await nosvFactory.deployed();

    /**
     * Contract address of the underlying NFT
     */
    nftContract = await ethers.getContractAt("IERC721", contractAddress);

    /**
     * Impersonating whale account to load sellersVault with weth
     */
    whale = await impersonate(whaleAddress);

    /**
     * Weth ERC20 contract
     */
    $weth = await ethers.getContractAt("IERC20", wethAddress);

    /**
     * Impersonating nft owner
     */
    nftOwner = await impersonate(nftOwnerAddress);
  });

  it("Nft option sellers deployment check and loading weth in sellers vault", async function () {
    tx = await nosvFactory
      .connect(deployer)
      .deployNftOptionVault(nft, contractAddress);
    const nosvOwner = await nosvFactory["owner()"]();
    console.log("NOSV owner", nosvOwner);

    const nosv = await nosvFactory["getVaultFromOptionParams(string,address)"](
      nft,
      contractAddress
    );
    // console.log("NOSV", nosv);

    sellersVault = await ethers.getContractAt("NftOptionSellersVault", nosv);
    // const amount = getNumInUnits(100, )

    const balanceOfWhale = await $weth["balanceOf(address)"](whaleAddress);
    console.log("Balalnce of whale", balanceOfWhale);

    const amount = getNumInUnits(100, 18);
    await $weth
      .connect(whale)
      ["transfer(address,uint256)"](sellersVault.address, amount);

    const postFillBalance = await $weth.balanceOf(sellersVault.address);
    expect(postFillBalance).to.be.eq(amount);

    const sNft = await sellersVault["nft()"]();
    console.log("NFT", sNft);
  });

  // it("Transferring WOW nft", async () => {

  //   const ownerOf6025 = await nftContract["ownerOf(uint256)"](tokenId);
  //   expect(ownerOf6025).to.be.eq(nftOwnerAddress);

  //   tx = await nftContract.connect(nftOwner)["safeTransferFrom(address,address,uint256)"](
  //     nftOwnerAddress,
  //     user0.address,
  //     tokenId
  //   )

  // });

  it("Testing epoch and premium configuration", async () => {
    const expiry = 1650547800;
    tx = await sellersVault
      .connect(deployer)
      ["startNewEpochWithExpiry(uint256)"](expiry);
    // Creating new epoch
    const newEpoch = await sellersVault["currentEpoch()"]();
    console.log("New Epoch", newEpoch);

    // set strikes
    tx = await sellersVault["setStrikes(uint256[])"](strikes);

    // set premium
    tx = await sellersVault.setPremiumsForStrikes(strikes, premiums);

    const premiumForStrike = await sellersVault[
      "epochStrikesToPremium(uint256,uint256)"
    ](newEpoch, strikes[0]);
    expect(premiumForStrike).to.be.eq(premiums[0]);
  });

  it("Bootsrap Test", async () => {
    tx = await sellersVault["bootstrap()"]();

    const currentEpoch = await sellersVault["currentEpoch()"]();

    epochStrikeTokens[0] = await sellersVault[
      "epochStrikeTokens(uint256,uint256)"
    ](currentEpoch, strikes[0]);
    epochStrikeTokens[1] = await sellersVault[
      "epochStrikeTokens(uint256,uint256)"
    ](currentEpoch, strikes[1]);
    console.log("Token 1", epochStrikeTokens[0]);
    console.log("Token 2", epochStrikeTokens[1]);
    const epochToken1 = await sellersVault["getEpochTokensName(uint256)"](strikes[0])
    console.log("Epoch token 1", epochToken1);
    
  });


  it("Deposit NFT and Mint option test", async () => {
    console.log("NFT owner address", nftOwnerAddress);
    const res = await nftContract["ownerOf(uint256)"](tokenId);
    console.log("Owner", res);
    const preMintUserWethBal = await $weth["balanceOf(address)"](
      nftOwner.address
    );
    tx = await nftContract
      .connect(nftOwner)
      ["approve(address,uint256)"](sellersVault.address, tokenId);
    tx = await sellersVault
      .connect(nftOwner)
      ["depositNftAndMintOption(uint256,uint256)"](tokenId, strikes[0]);

    const postDepositOwner = await nftContract["ownerOf(uint256)"](tokenId);
    expect(postDepositOwner).to.be.eq(sellersVault.address);

    const strikeTokenContract = await ethers.getContractAt(
      "IERC20",
      epochStrikeTokens[0]
    );

    const postMintUserWethBal = await $weth["balanceOf(address)"](
      nftOwner.address
    );
    const preBalPlusPremium = ethers.BigNumber.from(premiums[0]).add(
      preMintUserWethBal
    );
    expect(postMintUserWethBal).to.be.eq(preBalPlusPremium);
  });

  it("Settlement: OTM option and user can claim: Test", async () => {
    /**
     * Expire epoch with OTM
     */
    const currentEpoch = await sellersVault["currentEpoch()"]();
    tx = await sellersVault["expireEpoch(uint256)"](getNumInUnits(7.5, 18));

    // Expiring with OTM sp
    const settlementPrice = await sellersVault["epochSettlementPrice(uint256)"](currentEpoch)
    console.log("Settlement Price", settlementPrice);

    await sellersVault.connect(deployer)["settle(uint256,address)"](strikes[0], tempBuyerVault.address)

    const claimableStatus = await sellersVault["isNftClaimable(address,uint256)"](nftOwner.address, tokenId);

    const userForEpochStrike = await sellersVault.usersForThatEpochStrike(currentEpoch, strikes[0], 0);
    console.log("Users for epoch strike", userForEpochStrike);

    console.log("Claimable Status", claimableStatus);

    tx = await sellersVault.connect(nftOwner)["withdrawAllClaimableNFTs()"]();

    const nftOwnerPostWithdrawal = await nftContract["balanceOf(address)"](nftOwner.address);

    console.log("Owner : ", nftOwnerPostWithdrawal);

  });

  // it("Settlement: ITM option and user can claim: Test", async () => {
  //   const currentEpoch = await sellersVault["currentEpoch()"]();
  //   tx = await sellersVault["expireEpoch(uint256)"](getNumInUnits(9, 18));
  //   console.log("Hello");

  //   // Expiring with OTM sp
  //   const settlementPrice = await sellersVault["epochSettlementPrice(uint256)"](
  //     currentEpoch
  //   );
  //   console.log("Settlement Price", settlementPrice);

  //   const nftOwnerWethBal = await $weth.balanceOf(nftOwner.address);
  //   console.log("NFT owner weth bal", nftOwnerWethBal);

  //   const requiredWethToReclaim = await sellersVault[
  //     "wethRequiredToReclaimNFT(address,uint256)"
  //   ](nftOwner.address, strikes[0]);

  //   /**
  //    *  Depositing weth to reclaim nft
  //    */
  //   tx = await $weth
  //     .connect(nftOwner)
  //     ["approve(address,uint256)"](sellersVault.address, requiredWethToReclaim);
  //   await sellersVault
  //     .connect(nftOwner)
  //     ["depositWethForStrikeToReclaimNFT(uint256)"](requiredWethToReclaim);

  //   // Settle
  //   await sellersVault
  //     .connect(deployer)
  //     ["settle(uint256,address)"](strikes[0], tempBuyerVault.address);

    
  //   const claimableStatus = await sellersVault[
  //     "isNftClaimable(address,uint256)"
  //   ](nftOwner.address, tokenId);

  //   // Reclaiming nft post settlement
  //   tx = await sellersVault.connect(nftOwner)["withdrawAllClaimableNFTs()"]();

  //   const nftOwnerPostWithdrawal = await nftContract["ownerOf(uint256)"](
  //     tokenId
  //   );

  //   console.log("Owner : ", nftOwnerPostWithdrawal);
  // });
});

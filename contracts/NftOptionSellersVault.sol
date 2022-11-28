// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./libraries/Authorizable.sol";

import "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";

contract NftOptionSellersVault is IERC721Receiver, Authorizable{

    using FixedPointMathLib for uint256;
    using SafeERC20 for IERC20;
    using Strings for uint256;

    /*///////////////////////////////////////////////////////////////
                           Constants
    //////////////////////////////////////////////////////////////*/
    uint256 public constant BASE_UNIT = 10**18;
    address public constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    uint256 public constant PRE_LIQUIDATION_WINDOW = 2 hours;
    

    /*///////////////////////////////////////////////////////////////
                        constructor and key state variables
    //////////////////////////////////////////////////////////////*/

    string public nft;
    // Nft contract address
    address public contractAddress;

    /*///////////////////////////////////////////////////////////////
                        NftVault params
    //////////////////////////////////////////////////////////////*/
    
    uint256 public currentEpoch;
    
    mapping (uint256 => uint256) public epochExpiry;

    
    // EpochStatus 1 -> Bootstrap the epoch
    // EpochStatus 2 -> ETH depositors / speculators
    // EpochStatus 3 -> Option writers
    // EpochStatus 4 -> running
    // EpochStatus 5 -> expired
    mapping (uint256 => uint256) epochState;

    // ERC20 implementation for create2 purposes
    address public immutable erc20Implementation;

    // Selected Strikes for this epoch
    mapping (uint256 => uint256[]) public epochStrikes;
    // Epoch Strikes to Premium map
    mapping (uint256=> mapping (uint256 => uint256)) public epochStrikesToPremium;

    constructor (string memory nft_,address contractAddress_) {
        nft = nft_;
        contractAddress = contractAddress_;
        erc20Implementation = address(new ERC20PresetMinterPauserUpgradeable());
    }


    /*///////////////////////////////////////////////////////////////
                           Premium and epoch CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    event EpochUpdated(uint256 epoch);
    event PremiumUpdatedForCurrentEpoch(uint256 indexed epoch, uint256[] indexed strikes, uint256[] indexed premiums);


    /// @notice start a new epoch and set expiry
    function startNewEpochWithExpiry(uint256 expiry) external {
        currentEpoch += 1;
        epochState[currentEpoch] = 1;
        epochExpiry[currentEpoch] = expiry;
        emit EpochUpdated(currentEpoch);
    }

    /// @dev Check deposits haven't begun yet before setting strikes (later)
    function setStrikes(uint256[] memory strikes) public {
       
        epochStrikes[currentEpoch] = strikes;
    }

    function setPremiumsForStrikes(uint256[] memory strikes, uint256[] memory premiums) external {
        
        for (uint256 i = 0; i < strikes.length; i++) {
            epochStrikesToPremium[currentEpoch][strikes[i]] = premiums[i];
        }
        emit PremiumUpdatedForCurrentEpoch(currentEpoch, strikes, premiums);
    }
    /*///////////////////////////////////////////////////////////////
                           Settlement Price CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    
    event Settled(uint256 epoch, uint256 strike);
    event SettlementPriceUpdated(uint256 settlementPrice);
    event EpochExpired(uint256 epoch, uint256 settlementPrices);
    
    /// @notice Set the settlement price for the epoch
    mapping (uint256 => uint256) public epochSettlementPrice;

    /// @notice Epoch deposits by user for each strike
    mapping (uint256 => mapping (bytes32 => uint256[])) public userEpochNFTDepositsForStrike; 

    /// @dev mapping(abi.encoded(epoch, user) => (tokenId => 0,1,2)), valid values : 0(Unclaimable), 1(Claimable), 2(Claimed)
    mapping (bytes32 => mapping (uint256=>uint256)) public userEpochNftClaimableStatus;

    /// @notice Needed to display on frontend
    /// @dev mapping (epoch => strike => tokenIds) 
    mapping (uint256 => mapping (uint256 => uint256[])) public totalEpochNftDepositsForStrike;
    
    /// @dev 0: Settlement not done
    mapping(uint256 => uint256) public epochSettlement;

    
    /// @notice Needed at the time of settlement
    /// @dev mapping (address => (strike => deposit))
    mapping (address => uint256) public userWethBalance;

    /// @dev mapping (epoch => (strike => usersParticipatedInThatStrike))
    mapping(uint256 => mapping (uint256=>address[])) public  usersForThatEpochStrike;


    /// @dev Mapping of (epoch => (strike => tokens))
    mapping(uint256 => mapping (uint256 => address)) public epochStrikeTokens;


    /*///////////////////////////////////////////////////////////////
                Core events & Implementing INFTOption methods
    //////////////////////////////////////////////////////////////*/

    /**
    * @notice Bootstraps a new epoch and mints option tokens equivalent to user deposits for the epoch
    * @return Whether bootstrap was successful or not
    */
    function bootstrap() external returns (bool) {
        
        require(epochState[currentEpoch] == 1, "Not active state");
        require(epochStrikes[currentEpoch].length > 0, "Strikes not set");

        for (uint256 index = 0; index < epochStrikes[currentEpoch].length; index++) {
            // Cryptopunk-Call-85-epoch-1
            uint256 strike = epochStrikes[currentEpoch][index];
            string memory name =string(
            abi.encodePacked(
                nft,
                "-Call-",
                (strike/BASE_UNIT).toString(),
                "ETH",
                "-",
                epochExpiry[currentEpoch].toString()
            )
        );
            ERC20PresetMinterPauserUpgradeable _erc20 = ERC20PresetMinterPauserUpgradeable(
                Clones.clone(erc20Implementation)
            );
            _erc20.initialize(name, name);
            epochStrikeTokens[currentEpoch][strike] = address(_erc20);
        }
        return true;
    }

    function getEpochTokensName(uint256 strike_) external view returns (string memory) {
        return string(
            abi.encodePacked(
                nft,
                "-Call-",
                (strike_/BASE_UNIT).toString(),
                "ETH",
                "-",
                epochExpiry[currentEpoch].toString()
            )
        );
    }

    /// @dev transfer premium worth of option to the minter
    function depositNftAndMintOption(uint256 tokenId, uint256 strike_) external{
        // Check whether user holds that tokenId or not
        
        require(IERC721(contractAddress).ownerOf(tokenId) == msg.sender, "Writer not owner");

        // For v1: lets go with one option per strike minting
        require( true , "One option mint per user");
        // Depositing NFT
        IERC721(contractAddress).safeTransferFrom(msg.sender, address(this), tokenId);

        userEpochNFTDepositsForStrike[currentEpoch][keccak256(abi.encodePacked(msg.sender, strike_))].push(tokenId);
        totalEpochNftDepositsForStrike[currentEpoch][strike_].push(tokenId);

        usersForThatEpochStrike[currentEpoch][strike_].push(msg.sender);

         
        IERC20(WETH).safeTransfer(msg.sender, epochStrikesToPremium[currentEpoch][strike_]);


        ERC20PresetMinterPauserUpgradeable(epochStrikeTokens[currentEpoch][strike_])
            .mint(address(this), BASE_UNIT);
        
    }

    /// @notice WIP, not yet completely implemented
    function depositMultipleNftAndMintOptions(uint256[] memory tokenIds, uint256[] memory strikes) external {
        // Check whether user holds all the tokenIds
        for (uint256 index = 0; index < tokenIds.length; index++) {
            require(IERC721(contractAddress).ownerOf(tokenIds[index]) == msg.sender, "Writer doesn't own NFT");
        }

        uint256 amount = tokenIds.length;

        // Transfer tokenIds from user to this contract
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(contractAddress).safeTransferFrom(msg.sender, address(this), tokenIds[i]);
            userEpochNFTDepositsForStrike[currentEpoch][keccak256(abi.encodePacked(msg.sender, strikes[i]))].push(tokenIds[i]);
            totalEpochNftDepositsForStrike[currentEpoch][strikes[i]].push(tokenIds[i]);
            
            // Minting amount options and transferring to this address i.e. call buyers
            ERC20PresetMinterPauserUpgradeable(epochStrikeTokens[currentEpoch][strikes[i]])
                .mint(address(this), amount * BASE_UNIT);
        }
    }


    /**
    @notice Claim all NFTs once the epoch has expired
    @dev This function is called by the user who has bought the option, authorization still missing
    */
    function withdrawAllClaimableNFTs() external {
        require(epochState[currentEpoch] == 5, "Epoch not expired");
        uint256 _strike;
        bytes32 userStrikeEncoded;
        uint256 tokenId;
        
        for (uint256 i = 0; i < epochStrikes[currentEpoch].length; i++) {
            _strike = epochStrikes[currentEpoch][i];
            userStrikeEncoded = keccak256(abi.encodePacked(msg.sender, _strike));
            for (uint256 j = 0; j < userEpochNFTDepositsForStrike[currentEpoch][userStrikeEncoded].length; j++) {
                tokenId = userEpochNFTDepositsForStrike[currentEpoch][userStrikeEncoded][j];
                 // Wont be able to withdraw unclaimable NFTs unless you deposit the settlement before the window ends otherwise liquidated
                if(userEpochNftClaimableStatus[keccak256(abi.encodePacked(currentEpoch, msg.sender))][tokenId] == 1) {
                    IERC721(contractAddress).safeTransferFrom(address(this), msg.sender, tokenId);
                    userEpochNftClaimableStatus[keccak256(abi.encodePacked(currentEpoch, msg.sender))][tokenId] = 2; // Claimed
                }
            }
        }
    }

    function isNftClaimable(address user, uint256 tokenId) internal view returns(uint256) {
        return userEpochNftClaimableStatus[keccak256(abi.encodePacked(currentEpoch, user))][tokenId];
    }
    
    /**
    * @notice settle the strike and transfer pnl amount(if any) to the buyersVaultAddress
    */
    function settle(uint256 strike_, address buyersVaultAddress) external {

        // Check option expired or not
        require(epochState[currentEpoch] == 5, "Epoch not expired");

        address user;
        bytes32 userStrikeEncoded;
        uint256 tokenId;
        if(epochSettlementPrice[currentEpoch] <= strike_) {
            // Option expired OTM
            // Make all NFTs claimable for this strike
            for (uint256 i = 0; i < usersForThatEpochStrike[currentEpoch][strike_].length; i++) {
                user = usersForThatEpochStrike[currentEpoch][strike_][i];
                userStrikeEncoded = keccak256(abi.encodePacked(user, strike_));
    
                // Updating NFT claimable status for user
                for (uint256 j = 0; j < userEpochNFTDepositsForStrike[currentEpoch][userStrikeEncoded].length; j++) {
                    tokenId = userEpochNFTDepositsForStrike[currentEpoch][userStrikeEncoded][j];
                    // 1 means user can claim now
                    userEpochNftClaimableStatus[keccak256(abi.encodePacked(currentEpoch, user))][tokenId] = 1;

                } 
            }
        } else {
            // Option expired ITM
            uint256 numOfOptions = IERC20(epochStrikeTokens[currentEpoch][strike_]).balanceOf(address(this));
    
            // PNL if one option is exercised
            uint256 pnl = calculatePNL(strike_);
            
            for (uint256 i = 0; i < usersForThatEpochStrike[currentEpoch][strike_].length; i++) {
                user = usersForThatEpochStrike[currentEpoch][strike_][i];
                // Under the assumption, user minted one option per strike
                require(userWethBalance[user] >= pnl, "User deposits less than pnl");
            }
    
    
            for (uint256 i = 0; i < usersForThatEpochStrike[currentEpoch][strike_].length; i++) {
                user = usersForThatEpochStrike[currentEpoch][strike_][i];
                userStrikeEncoded = keccak256(abi.encodePacked(user, strike_));
                userWethBalance[user] -= pnl;
    
                // Updating NFT claimable status for user
                for (uint256 j = 0; j < userEpochNFTDepositsForStrike[currentEpoch][userStrikeEncoded].length; j++) {
                    tokenId = userEpochNFTDepositsForStrike[currentEpoch][userStrikeEncoded][j];
                    // 1 means user can claim now
                    userEpochNftClaimableStatus[keccak256(abi.encodePacked(currentEpoch, user))][tokenId] = 1;
                } 
            }
    
            IERC20(WETH).safeTransfer(buyersVaultAddress, numOfOptions.mulWadDown(pnl));
    
            
        }
        emit Settled(currentEpoch, strike_);
        
    }

    function calculatePNL(uint256 strike_) internal view returns (uint256) {
        require(epochState[currentEpoch] == 5, "Epoch not expired");
        return (epochSettlementPrice[currentEpoch] > strike_) ? epochSettlementPrice[currentEpoch] - strike_ : 0;
    }

    /// @dev Liquidation to be done manually in the beginning
    function liquidateNFT(uint256 tokenId, address manualLiquidationAccount) external {
        
        require(block.timestamp > epochExpiry[currentEpoch] + PRE_LIQUIDATION_WINDOW, "Still in pre-liquidation window" );
        IERC721(WETH).safeTransferFrom(address(this), manualLiquidationAccount, tokenId);
    }

    function depositWethForStrikeToReclaimNFT(uint256 amount) external {
        userWethBalance[msg.sender] += amount;
        IERC20(WETH).safeTransferFrom(msg.sender, address(this), amount);
    }

    function wethRequiredToReclaimNFT(address user, uint strike_)
     external 
     view 
     returns (uint256) {
        uint256 pnl = calculatePNL(strike_);
        if(userWethBalance[user] >= pnl) {
            return 0;
        }  else {
            return pnl - userWethBalance[user];
        }
    }

    

    

    // For now, expiring epoch with Settlement price until we get the NFT oracle
    function expireEpoch(uint256 settlementPrice) external  {
        require(epochState[currentEpoch] != 5, "Already Expired");
        // Expire Epoch
        epochState[currentEpoch] = 5;

        epochSettlementPrice[currentEpoch] = settlementPrice;
        emit EpochExpired(currentEpoch, settlementPrice);
        
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata 
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /*///////////////////////////////////////////////////////////////
                Temporary hack incase some things go wrong to recover NFTs
    //////////////////////////////////////////////////////////////*/
    function rescue() external {
        uint256 _strike;
        bytes32 userStrikeEncoded;
        uint256 tokenId;
        
        for (uint256 i = 0; i < epochStrikes[currentEpoch].length; i++) {
            _strike = epochStrikes[currentEpoch][i];
            userStrikeEncoded = keccak256(abi.encodePacked(msg.sender, _strike));
            for (uint256 j = 0; j < userEpochNFTDepositsForStrike[currentEpoch][userStrikeEncoded].length; j++) {
                tokenId = userEpochNFTDepositsForStrike[currentEpoch][userStrikeEncoded][j];
                IERC721(contractAddress).safeTransferFrom(address(this), msg.sender, tokenId);
                // Claimed | Rescued
                userEpochNftClaimableStatus[keccak256(abi.encodePacked(currentEpoch, msg.sender))][tokenId] = 2; 
            }
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;


import "./libraries/Authorizable.sol";
import "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NftOptionBuyersVault is Authorizable {

    using FixedPointMathLib for uint256;
    using SafeERC20 for IERC20;


    /*///////////////////////////////////////////////////////////////
                           Constants
    //////////////////////////////////////////////////////////////*/
    address public immutable WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    uint256 public immutable BASE_UNIT = 10**18;

    uint256 public currentEpoch;
    string public nft;
    uint8 public optionType;

    mapping (uint256 => mapping (bytes32 => uint256)) public userDepositInStrike;
    mapping (uint256 => mapping (uint256 => uint256)) public totalDepositInStrike;

    /// @dev (epoch => (strike => earnings))
    mapping (uint256 => mapping (uint256 => uint256)) public totalEarningsForStrike;

    
    mapping (uint256=> uint256[]) public epochStrikes;

    mapping (uint256 => uint256) public epochExpiry;

    mapping(uint256 => mapping (uint256=>uint256)) public epochStrikesToPremium;

    // EpochStatus 1 -> Bootstrap the epoch
    // EpochStatus 2 -> ETH depositors / speculators
    // EpochStatus 3 -> Option writers
    // EpochStatus 4 -> running
    // EpochStatus 5 -> expired
    mapping(uint256 => uint256) public epochState;

    address public NFT_OPTIONS_SELLER_VAULT_ADDRESS;

    constructor (
        string memory nft_
    ) {
        nft = nft_;
        optionType = 0; // Call hardcoded
    }

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposited(address indexed user, uint256 depositAmount);

    event PartialWithdraw(address indexed user, uint256 withdrawAmount);

    event CompleteWithdraw(address indexed user, uint256 withdrawAmount);

    event EarningsClaimed(address indexed user, uint256 earnings);

    /*///////////////////////////////////////////////////////////////
                            Configuring epoch
    //////////////////////////////////////////////////////////////*/

    event NewEpoch(uint256 epoch);
    function startNewEpochWithExpiry(uint256[] calldata strikes, uint256[] calldata premiums, uint256 expiry) external {
        unchecked {   
            currentEpoch += 1;
        }

        epochStrikes[currentEpoch] = strikes; 
        epochState[currentEpoch] = 1;
        epochExpiry[currentEpoch] = expiry;


        for (uint256 i = 0; i < strikes.length; i++) {
            epochStrikesToPremium[currentEpoch][strikes[i]] = premiums[i];
        }

        emit NewEpoch(currentEpoch);
    }

    
    /*///////////////////////////////////////////////////////////////
                            CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    

    function setOptionWriterVaultAddress(address nftOptionSellerVaultAddr) external{
        NFT_OPTIONS_SELLER_VAULT_ADDRESS = nftOptionSellerVaultAddr;
    }
    /*///////////////////////////////////////////////////////////////
                            Deposit/Withdrawal Logic
    //////////////////////////////////////////////////////////////*/

    function depositInOptionBuyersVault(uint256 depositAmount, uint256 strike_) external {
        // Check round/option writing has begun or not
        require(epochState[currentEpoch] == 2, "Option Writing has already begun");

        // // Check depositAmount is greater than 0
        // require(depositAmount > 0, "Deposit Amount 0");

        unchecked {
            userDepositInStrike[currentEpoch][keccak256(abi.encodePacked(msg.sender, strike_))] += depositAmount;
            totalDepositInStrike[currentEpoch][strike_] += depositAmount;
        }
        IERC20(WETH).safeTransferFrom(msg.sender, address(this), depositAmount);
        emit Deposited(msg.sender, depositAmount);
    }

    function withdrawFromOptionBuyersVault(uint256 withdrawAmount, uint256 strike_) external {
        // Check round/option writing has begun or not
        require(epochState[currentEpoch] == 2, "Round already started");
        // Withdraw Amount should be greater than 0
        bytes32 userStrikeEncoded = keccak256(abi.encodePacked(msg.sender, strike_));

        // withdraw amount should not be greater than total deposits
        require(withdrawAmount <= userDepositInStrike[currentEpoch][userStrikeEncoded], "Withdraw Amount 0");

       unchecked {
        userDepositInStrike[currentEpoch][userStrikeEncoded] -= withdrawAmount;
       }
        IERC20(WETH).safeTransfer(msg.sender, withdrawAmount);
    }

    /*///////////////////////////////////////////////////////////////
                        Earnings LOGIC
    //////////////////////////////////////////////////////////////*/

    function claimEarningsForStrike(uint256 strike_) external {
        // We are not allowing for invalid strike
        require(true, "check for valid strike");
        // Only after options have expired
        require(epochState[currentEpoch] == 5, "Epoch not expired");
        require(totalEarningsForStrike[currentEpoch][strike_] > 0, "Earning 0");
        
        // Earning of user should be greater than 0
        bytes32 userStrikeEncoded = keccak256(abi.encodePacked(msg.sender, strike_));
        uint256 userShares = userDepositInStrike[currentEpoch][userStrikeEncoded].divWadDown(totalDepositInStrike[currentEpoch][strike_]);
        userDepositInStrike[currentEpoch][userStrikeEncoded] = 0;
        require(userShares > 0, "User have either 0 shares or already withdrawn");
        uint256 userEarnings = totalEarningsForStrike[currentEpoch][strike_].mulWadDown(userShares);
        IERC20(WETH).transferFrom(address(this), msg.sender, userEarnings);
        emit EarningsClaimed(msg.sender, userEarnings);
    }

    function setTotalEarningsForStrike(uint256 strike_, uint256 earnings) external {
        totalEarningsForStrike[currentEpoch][strike_] = earnings;
     }

     function expireEpoch() external  {
        require(epochState[currentEpoch] != 5, "Already Expired");
        // Expire Epoch
        epochState[currentEpoch] = 5;
        
    }

    function setEpochState(uint256 state) external { 
        require(state >0 && state < 6, "invalid state vaule");
        epochState[currentEpoch] = state;
    }

    /*///////////////////////////////////////////////////////////////
                        Provide Liquidity
    //////////////////////////////////////////////////////////////*/
    function provideLiquidityToOptionSellersVault() external {

        uint256 totalLiquidity = IERC20(WETH).balanceOf(address(this));
        
        // Transfer total liquidity to Option writer vault 
        IERC20(WETH).transferFrom(address(this), NFT_OPTIONS_SELLER_VAULT_ADDRESS, totalLiquidity);
    }

    /*///////////////////////////////////////////////////////////////
                        View functions
    //////////////////////////////////////////////////////////////*/

    function getUserDepositsForStrike(address user, uint256 strike_) external view  returns (uint256) {
        
        return userDepositInStrike[currentEpoch][keccak256(abi.encodePacked(user, strike_))];
    }

    function getByteEncodedUserAndStrike(address user, uint256 strike_) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, strike_));
    }

    function getEpochStrikes() external view returns(uint256[] memory) {
        return epochStrikes[currentEpoch];
    }   
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@chainlink/contracts/src/v0.8/dev/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title UnifiedLiquidityPool Contract
 */

contract RandomNumberConsumer is VRFConsumerBase, Ownable {
    using Address for address;

    bytes32 internal keyHash;
    uint256 internal fee;

    address public ULPAddress;

    bytes32 currentRequestID;
    mapping(bytes32 => uint256) requestToRandom;

    /// @notice Event emitted when ULP address is changed
    event newULP(address ULP);

    /// @notice Event emitted when chainlink verified random number arrived.
    event randomNumberArrived(bool arrived, uint256 number);

    modifier onlyULP() {
        require(ULPAddress == msg.sender, "RNG: Caller is not the ULP address");
        _;
    }

    /**
     * Constructor inherits VRFConsumerBase
     *
     * Network: Mumbai
     * Chainlink VRF Coordinator address: 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255
     * LINK token address:                0x326C977E6efc84E512bB9C30f76E30c160eD06FB
     * Key Hash: 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4
     * Fee : 0.0001LINK
     */
    constructor(
        address _vrfCoordinator,
        address _link,
        bytes32 _keyHash,
        uint256 _fee
    )
        VRFConsumerBase(
            _vrfCoordinator, // VRF Coordinator
            _link // LINK Token
        )
    {
        keyHash = _keyHash;
        fee = _fee;
    }

    /**
     * @dev Public function for request randomness from a user-provided seed and returns request Id. This function can be called by only apporved games.
     */
    function requestRandomNumber()
        public
        onlyULP
        returns (bytes32 requestID)
    {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        uint256 rand = requestToRandom[currentRequestID];
        emit randomNumberArrived(false, rand);
        currentRequestID = requestRandomness(keyHash, fee, 2021);
        requestToRandom[currentRequestID] = rand;
        return currentRequestID;
    }

    /**
     * @dev Callback function used by VRF Coordinator. This function sets new random number with unique request Id.
     * @param _randomness Random Number
     */
    function fulfillRandomness(bytes32 requestID, uint256 _randomness)
        internal
        override
    {
        requestToRandom[requestID] = _randomness;
        emit randomNumberArrived(true, _randomness);
    }

    /**
     * @dev Public function for returning verified random number. This function can be called by only ULP.
     */
    function getVerifiedRandomNumber(bytes32 activeID)
        public
        view
        onlyULP
        returns (uint256)
    {
        return requestToRandom[activeID];
    }

    /**
     * @dev Public function for setting ULP address. This function can be called by only owner.
     * @param _ulpAddr Address of ULP
     */
    function setULPAddress(address _ulpAddr) public onlyOwner {
        require(
            _ulpAddr.isContract() == true,
            "RNG: This is not a Contract Address"
        );
        ULPAddress = _ulpAddr;
        emit newULP(ULPAddress);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
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
    mapping(bytes32 => bool) hasReturned;

    /// @notice Event emitted when ULP address is changed
    event newULP(address ULP);

    /// @notice Event emitted when chainlink verified random number arrived.
    event randomNumberArrived(
        bool arrived,
        uint256 randomNumber,
        bytes32 batchID
    );

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
     * Key Hash:                          0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4
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
     * @dev Public function to request randomness and returns request Id. This function can be called by only apporved games.
     */
    function requestRandomNumber() public onlyULP returns (bytes32 requestID) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "RandomNumberConsumer: Not enough LINK - fill contract with faucet"
        );

        uint256 prevRandomNumber = requestToRandom[currentRequestID];

        emit randomNumberArrived(false, prevRandomNumber, currentRequestID);

        currentRequestID = requestRandomness(keyHash, fee);
        hasReturned[currentRequestID] = false;

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
        hasReturned[requestID] = true;
        emit randomNumberArrived(true, _randomness, requestID);
    }

    /**
     * @dev Public function to return verified random number. This function can be called by only ULP.
     * @param _reqeustId Batching Id of random number.
     */
    function getVerifiedRandomNumber(bytes32 _reqeustId)
        public
        view
        onlyULP
        returns (uint256)
    {
        require(
            hasReturned[_reqeustId] == true,
            "RandomNumberConsumer: Random number is not arrived yet"
        );
        return requestToRandom[_reqeustId];
    }

    /**
     * @dev Public function to set ULP address. This function can be called by only owner.
     * @param _ulpAddr Address of ULP
     */
    function setULPAddress(address _ulpAddr) public onlyOwner {
        require(
            _ulpAddr.isContract() == true,
            "RandomNumberConsumer: This is not a Contract Address"
        );
        ULPAddress = _ulpAddr;
        emit newULP(ULPAddress);
    }
}

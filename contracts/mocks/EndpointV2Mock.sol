// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EndpointV2Mock {
    uint16 public immutable eid;
    mapping(address => address) public destLzEndpoint;
    mapping(address => address) public delegates;
    uint256 public defaultFee;

    error NotPassportHolder();
    error InsufficientFee();

    constructor(uint16 _eid) {
        eid = _eid;
    }

    function setDestLzEndpoint(address _contract, address _endpoint) external {
        destLzEndpoint[_contract] = _endpoint;
    }

    function setDelegate(address _delegate) external {
        delegates[msg.sender] = _delegate;
    }

    function setDefaultFee(uint256 _fee) external {
        defaultFee = _fee;
    }

    // Mock function to simulate receiving messages
    function lzReceive(
        address _contract,
        uint16 _srcEid,
        bytes calldata _payload,
        address _from,
        bytes calldata _extraData
    ) external {
        // You can add any necessary logic here
    }

    // Add this function to handle send() calls from OAppSender
    function send(
        uint16 _dstEid,
        bytes calldata _destination,
        bytes calldata _payload,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable {
        if (msg.value < defaultFee) {
            revert InsufficientFee();
        }
        // Mock implementation - you can add logic here if needed
    }

    // Add this function to handle quote() calls
    function quote(
        uint16 _dstEid,
        MessagingParams memory _params,
        bytes memory _options
    ) external view returns (MessagingFee memory) {
        return MessagingFee(defaultFee, 0);
    }

    struct MessagingParams {
        address dstAddress;
        bytes payload;
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }
} 
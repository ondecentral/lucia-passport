// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EndpointV2Mock {
    uint16 public immutable eid;
    mapping(address => address) public destLzEndpoint;
    mapping(address => address) public delegates;
    uint256 public defaultFee;

    error NotPassportHolder();

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

    // Mock function to quote fees
    function quoteFee(
        uint16 _dstEid,
        uint256 _passportId,
        uint256 _points
    ) external view returns (uint256 nativeFee, bytes memory calldataBid) {
        return (defaultFee, "");  // Return the default fee and empty calldata
    }
} 
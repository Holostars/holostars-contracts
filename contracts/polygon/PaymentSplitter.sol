// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract PaymentSplitter {
    mapping(address => uint256) public _agentRoyalties;
    mapping(address => uint256) public _sellerRevenue;

    event HolostarsPayment(
        uint256 nftId,
        uint256 total,
        address indexed sellerAddress,
        uint256 sellerCut,
        address indexed agentAddress,
        uint256 agentRoyalty
    );

    address payable holostarsAddress;
    uint96 holostarsFeeNumerator;
    address payable chainstartersAddress;
    uint96 chainstartersFeeNumerator;

    constructor(
        address _holostarsAddress,
        uint96 _holostarsFeeNumerator,
        address _chainstartersAddress,
        uint96 _chainstartersFeeNumerator
    ) payable {
        holostarsAddress = payable(_holostarsAddress);
        holostarsFeeNumerator = _holostarsFeeNumerator;
        chainstartersAddress = payable(_chainstartersAddress);
        chainstartersFeeNumerator = _chainstartersFeeNumerator;
    }

    function splitPayment(
        uint256 _nftId,
        address payable _agentAddress,
        uint256 _agentRoyalty,
        address payable _sellerAddress
    ) public payable {
        uint256 _holostarsRoyalty = (msg.value * holostarsFeeNumerator) / 10000;
        uint256 _chainstartersRoyalty = (msg.value * chainstartersFeeNumerator) / 10000;
        uint256 _sellerCut = msg.value - (_agentRoyalty + _holostarsRoyalty + _chainstartersRoyalty);

        (bool sentSellerCut, ) = _sellerAddress.call{value: _sellerCut}("");
        require(sentSellerCut, "Failed to send seller cut.");
        _sellerRevenue[_sellerAddress] += _sellerCut;

        (bool sentAgentRoyalty, ) = _agentAddress.call{value: _agentRoyalty}("");
        require(sentAgentRoyalty, "Failed to send agent royalty.");
        _agentRoyalties[_agentAddress] += _agentRoyalty;

        (bool sentHolostarsRoyalty, ) = holostarsAddress.call{value: _holostarsRoyalty}("");
        require(sentHolostarsRoyalty, "Failed to send Holostars royalty.");

        (bool sentChainstartersRoyalty, ) = chainstartersAddress.call{value: _chainstartersRoyalty}("");
        require(sentChainstartersRoyalty, "Failed to send Chainstarters royalty.");

        emit HolostarsPayment(_nftId, msg.value, _sellerAddress, _sellerCut, _agentAddress, _agentRoyalty);
    }
}

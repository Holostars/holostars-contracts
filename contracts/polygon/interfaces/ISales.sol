// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISales {
    event OnSale(uint256 nftId, uint256 price);
    event OfferEvent(uint256 nftId, address indexed offererAddress, uint256 amount);
    event OutBid(uint256 nftId, address indexed offererAddress, uint256 newAmount);
    event ResendOffer(uint256 nftId, address indexed offererAddress);
    event OfferAccepted(uint256 nftId, address indexed seller, address indexed buyer, uint256 amount);

    function putOnSale(uint256 _nftId, uint256 _price) external;
    function purchaseNft(uint256 _nftId) external payable;
    function makeOffer(uint256 _nftId) external payable;
    function acceptOffer(uint256 _nftId) external;
    function resendOffer(uint256 _nftId) external;
}

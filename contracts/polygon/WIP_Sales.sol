// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./oz-contracts/security/Pausable.sol";
import "./Holostars.sol";
import "./PaymentSplitter.sol";

import "./interfaces/ISales.sol";

contract Sales is ISales, Pausable {
    struct Offer {
        address offererAddress;
        uint256 amount;
    }

    struct Sale {
        address seller;
        uint256 price;
    }

    Holostars public holostars;
    PaymentSplitter public paymentSplitter;

    mapping(uint256 => Offer) offers;
    mapping(uint256 => Sale) sales;

    constructor(
        address _nftAddress,
        address _paymentSplitterAddress
    ) payable {
        holostars = Holostars(_nftAddress);
        paymentSplitter = PaymentSplitter(_paymentSplitterAddress);
    }

    function putOnSale(uint256 _nftId, uint256 _price) override external whenNotPaused {
        require(holostars.ownerOf(_nftId) == msg.sender, "Sender is not the owner.");

        Sale storage sale = sales[_nftId];
        sale.price = _price;
        sale.seller = msg.sender;

        emit OnSale(_nftId, _price);
    }

    function purchaseNft(uint256 _nftId) override external payable whenNotPaused {
        Sale memory sale = sales[_nftId];
        require(msg.value == sale.price);

        holostars.safeTransferFrom(sale.seller, msg.sender, _nftId);
        (address _agentAddress, uint256 _agentRoyalty) = holostars.royaltyInfo(_nftId, sale.price);
        paymentSplitter.splitPayment{value: sale.price}(_nftId, payable(_agentAddress), _agentRoyalty, payable(sale.seller));
    }

    function makeOffer(uint256 _nftId) override external payable whenNotPaused {
        Offer memory offer = offers[_nftId];
        require(msg.value > offer.amount, "Not enough to outbid.");

        if (offer.offererAddress != address(0)) {
            (bool previousOfferReturned, ) = payable(offer.offererAddress).call{value: offer.amount}("");
            require(previousOfferReturned, "Failed to return previous offer.");

            emit OutBid(_nftId, offer.offererAddress, msg.value);
        }

        Offer storage newOffer = offers[_nftId];
        newOffer.amount = msg.value;
        newOffer.offererAddress = msg.sender;

        emit OfferEvent(_nftId, msg.sender, msg.value);
    }

    function acceptOffer(uint256 _nftId) override external whenNotPaused {
        require(holostars.ownerOf(_nftId) == msg.sender, "Sender is not the owner.");

        Offer memory offer = offers[_nftId];

        if (offer.offererAddress != address(0)) {
            holostars.safeTransferFrom(msg.sender, offer.offererAddress, _nftId);

            (address _agentAddress, uint256 _agentRoyalty) = holostars.royaltyInfo(_nftId, offer.amount);
            paymentSplitter.splitPayment{value: offer.amount}(_nftId, payable(_agentAddress), _agentRoyalty, payable(msg.sender));

            emit OfferAccepted(_nftId, msg.sender, offer.offererAddress, offer.amount);
        }
    }

    function resendOffer(uint256 _nftId) override external whenNotPaused {
        Offer memory offer = offers[_nftId];
        require(offer.offererAddress == msg.sender, "Sender is not the highest offerer.");

        (bool success, ) = payable(msg.sender).call{value: offer.amount}("");
        require(success, "Failed to send Ether");

        Offer storage resetOffer = offers[_nftId];
        resetOffer.amount = 0;
        resetOffer.offererAddress = address(0);

        emit ResendOffer(_nftId, msg.sender);
    }
}
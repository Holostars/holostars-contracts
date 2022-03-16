// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint tokenId
    ) external;

    function transferFrom(
        address,
        address,
        uint
    ) external;

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

interface IPaymentSplitter {
    function splitPayment(
        uint256 _nftId,
        address payable _agentAddress,
        uint256 _agentRoyalty,
        address payable _sellerAddress
    ) external payable;
}

contract EnglishAuction {
    event Start();
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address winner, uint amount);

    IERC721 public nft;
    IPaymentSplitter public paymentSplitter;

    uint public nftId;
    address payable public seller;
    uint public endAt;
    bool public started;
    bool public ended;
    uint public numberOfDays;
    address public highestBidder;
    uint public highestBid;

    mapping(address => uint) public bids;

    constructor(
        address _nft,
        address _paymentSplitter,
        uint _nftId,
        uint _startingBid,
        uint _numberOfDays,
        address payable _seller
    ) {
        nft = IERC721(_nft);
        paymentSplitter = IPaymentSplitter(_paymentSplitter);

        nftId = _nftId;
        seller = _seller;
        highestBid = _startingBid;
        numberOfDays = _numberOfDays;
    }

    function start() external {
        require(!started, "started");

        nft.transferFrom(seller, address(this), nftId);
        started = true;
        endAt = block.timestamp + numberOfDays * 1 days;

        emit Start();
    }

    function bid() external payable {
        require(started, "not started");
        require(block.timestamp < endAt, "ended");
        require(msg.value > highestBid, "value < highest");

        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit Bid(msg.sender, msg.value);
    }

    function withdraw() external {
        uint bal = bids[msg.sender];
        bids[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: bal}("");
        require(success, "Failed to send Ether");

        emit Withdraw(msg.sender, bal);
    }

    function end() external {
        require(started, "not started");
        require(block.timestamp >= endAt, "not ended");
        require(!ended, "ended");

        ended = true;
        if (highestBidder != address(0)) {
            nft.safeTransferFrom(address(this), highestBidder, nftId);
            (address _agentAddress, uint256 _agentRoyalty) = nft.royaltyInfo(nftId, highestBid);
            paymentSplitter.splitPayment{value: highestBid}(nftId, payable(_agentAddress), _agentRoyalty, seller);
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }

        emit End(highestBidder, highestBid);
    }
}
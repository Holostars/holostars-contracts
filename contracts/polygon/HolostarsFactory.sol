// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./oz-contracts/access/AccessControl.sol";
import "./oz-contracts/security/Pausable.sol";
import "./oz-contracts/access/Ownable.sol";
import "./oz-contracts/utils/Strings.sol";
import "./oz-contracts/utils/math/SafeMath.sol";

import "./Holostars.sol";
import "./PaymentSplitter.sol";

import "./interfaces/IHolostarsFactory.sol";

contract HolostarsFactory is IHolostarsFactory, Ownable, AccessControl, Pausable {
    using Strings for string;
    using SafeMath for uint256;

    address public proxyRegistryAddress;
    address public paymentSplitterAddress;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant VERIFIED = keccak256("VERIFIED");

    mapping(uint8 => bool) public _whitelistOpen;
    mapping(address => mapping(uint8 => bool)) public _whitelists;

    uint256 MAX_SUPPLY;
    uint256 HOLOSTARS_COST;

    string private _name;
    string private _symbol;

    Holostars public holostars;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 _defaultTokenPrice,
        uint256 _initialMaxSupply,
        address _nftAddress,
        address _proxyRegistryAddress,
        address _paymentSplitterAddress
    ) payable {
        proxyRegistryAddress = _proxyRegistryAddress;
        paymentSplitterAddress = _paymentSplitterAddress;
        MAX_SUPPLY = _initialMaxSupply;
        HOLOSTARS_COST = _defaultTokenPrice;

        holostars = Holostars(_nftAddress);

        _setupRole(ADMIN, owner());
        _setupRole(VERIFIED, owner());
        _setupRole(DEFAULT_ADMIN_ROLE, owner());

        _name = name_;
        _symbol = symbol_;
        _whitelistOpen[1] = true;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function supportsFactoryInterface() public pure override returns (bool) {
        return true;
    }

    function setMaxSupply(uint256 _maxSupply) override external onlyRole(ADMIN) {
        MAX_SUPPLY = _maxSupply;

        emit MaxSupplyChanged(_maxSupply);
    }

    function joinWhitelist(uint8 _whitelistNumber) override external {
        require(_whitelistOpen[_whitelistNumber], "Whitelist is not open.");
        _whitelists[_msgSender()][_whitelistNumber] = true;

        emit JoinedWhitelist(_whitelistNumber, _msgSender());
    }

    function tokenURI(uint256 _tokenId) external view override returns (string memory) {
        string memory uri = holostars.tokenURI(_tokenId);
        return uri;
    }

    function updateDefaultTokenPrice(uint256 _tokenPrice) override external onlyRole(ADMIN) {
        HOLOSTARS_COST = _tokenPrice;

        emit DefaultTokenPriceChanged(_tokenPrice);
    }

    function updateTokenPrice(uint256 _tokenId, uint256 _newPrice) override external {
        require(
            hasRole(ADMIN, _msgSender()) || holostars._tokenIdToCreatorsAddress(_tokenId) == _msgSender(),
            "Must be the creator to change price."
        );
        holostars.updateTokenPrice(_tokenId, _newPrice);

        emit TokenPriceChanged(_tokenId, _newPrice);
    }

    function createNFT(
        string memory _tokenURI,
        uint256 _tokenPrice,
        address _royaltyReceiver,
        uint96 _royaltyFeeNumerator
    ) override external {
        require(
            hasRole(VERIFIED, _msgSender()) || hasRole(ADMIN, _msgSender()),
            "Caller does not have ADMIN or VERIFIED role."
        );

        uint256 _tokenId = holostars.makeAvailableForMinting(_tokenURI, _tokenPrice, _royaltyReceiver, _royaltyFeeNumerator, _msgSender());

        emit NewAvailableToken(_tokenId, _msgSender(), _tokenPrice);
    }

    function mint(uint256 _tokenId, address _toAddress) public payable override whenNotPaused {
        require(bytes(this.tokenURI(_tokenId)).length != 0, "This token is not available for minting.");

        uint256 _tokenPrice = holostars._tokenIdToMintPrice(_tokenId);

        uint256 _cost;
        if (_tokenPrice == 0) {
            _cost = HOLOSTARS_COST;
        } else {
            _cost = _tokenPrice;
        }

        require(msg.value == _cost, "Incorrect value sent");
        address _creatorAddress = holostars._tokenIdToCreatorsAddress(_tokenId);
        (address _agentAddress, uint256 _agentRoyalty) = holostars.royaltyInfo(_tokenId, _cost);

        PaymentSplitter paymentSplitter = PaymentSplitter(paymentSplitterAddress);
        paymentSplitter.splitPayment{value: _cost}(
            _tokenId,
            payable(_agentAddress),
            _agentRoyalty,
            payable(_creatorAddress)
        );

        uint256 holostarsSupply = holostars.totalSupply();
        require(holostarsSupply < (MAX_SUPPLY - 1), "The max supply has been reached");
        holostars.mintTo(_toAddress, _tokenId);

        emit Mint(_tokenId, _toAddress);
    }

    function tokenInfo(uint256 _tokenId)
        override
        external
        view
        returns (
            address,
            address,
            uint96,
            string memory,
            uint256
        )
    {
        (address _royaltyReceiver, uint96 _royaltyFeeNumerator) = holostars.tokenRoyaltyInfo(_tokenId);

        return (
            holostars._tokenIdToCreatorsAddress(_tokenId),
            _royaltyReceiver,
            _royaltyFeeNumerator,
            this.tokenURI(_tokenId),
            holostars._tokenIdToMintPrice(_tokenId)
        );
    }

    function isApprovedForAll(address _owner, address _operator) override public view returns (bool) {
        if (owner() == _owner && _owner == _operator) {
            return true;
        }

        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (owner() == _owner && address(proxyRegistry.proxies(_owner)) == _operator) {
            return true;
        }

        return false;
    }

    function ownerOf(uint256) override public view returns (address _owner) {
        return owner();
    }
}

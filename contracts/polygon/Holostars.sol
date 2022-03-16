// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./oz-contracts/token/ERC721/ERC721Royalty.sol";
import "./oz-contracts/access/Ownable.sol";
import "./oz-contracts/access/AccessControl.sol";
import "./oz-contracts/utils/Counters.sol";
import "./oz-contracts/utils/Strings.sol";
import "./oz-contracts/utils/math/SafeMath.sol";

import "./ContentMixin.sol";
import "./NativeMetaTransaction.sol";

import "./interfaces/IHolostars.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract Holostars is IHolostars, ERC721Royalty, ContextMixin, NativeMetaTransaction, Ownable, AccessControl {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _nextTokenId;
    Counters.Counter private _mintedTokens;

    bytes32 public constant HOLOSTARS_CONTRACTS = keccak256("HOLOSTARS_CONTRACTS");

    address public proxyRegistryAddress;
    address public salesAddress;
    string contractMetadataURI;

    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => uint256) public _tokenIdToMintPrice;
    mapping(uint256 => address) public _tokenIdToCreatorsAddress;

    constructor(
        string memory _name,
        string memory _symbol,
        address _proxyRegistryAddress,
        string memory _contractMetadataURI,
        address _salesAddress
    ) ERC721(_name, _symbol) {
        proxyRegistryAddress = _proxyRegistryAddress;
        salesAddress = _salesAddress;
        contractMetadataURI = _contractMetadataURI;

        _setupRole(HOLOSTARS_CONTRACTS, owner());
        _setupRole(DEFAULT_ADMIN_ROLE, owner());

        _nextTokenId.increment();
        _initializeEIP712(_name);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Royalty, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function baseTokenURI() override public pure returns (string memory) {
        return "";
    }

    function contractURI() override public view returns (string memory) {
        return contractMetadataURI;
    }

    function updateTokenPrice(uint256 _tokenId, uint256 _newPrice)
        override
        external
        onlyRole(HOLOSTARS_CONTRACTS)
    {
        require(!_exists(_tokenId), "This token has already been minted");
        _tokenIdToMintPrice[_tokenId] = _newPrice;

        emit TokenPriceChanged(_tokenId, _newPrice);
    }

    function makeAvailableForMinting(
        string memory _tokenURI,
        uint256 _tokenPrice,
        address _royaltyReceiver,
        uint96 _royaltyFeeNumerator,
        address _creator
    ) override external onlyRole(HOLOSTARS_CONTRACTS) returns (uint256) {
        uint256 _currentTokenId = _nextTokenId.current();

        _tokenIdToCreatorsAddress[_currentTokenId] = _creator;
        _setTokenRoyalty(_currentTokenId, _royaltyReceiver, _royaltyFeeNumerator);
        _tokenURIs[_currentTokenId] = _tokenURI;
        _tokenIdToMintPrice[_currentTokenId] = _tokenPrice;
        _nextTokenId.increment();

        return _currentTokenId;
    }

    function mintTo(address _to, uint256 _tokenId) override public onlyRole(HOLOSTARS_CONTRACTS) {
        require(!_exists(_tokenId), "This token has already been minted");
        require(bytes(_tokenURIs[_tokenId]).length != 0, "No tokenURI set.");
        _mintedTokens.increment();
        _safeMint(_to, _tokenId);
    }

    function tokenRoyaltyInfo(uint256 _tokenId)
        override
        public
        view
        onlyRole(HOLOSTARS_CONTRACTS)
        returns (address, uint96)
    {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];
        return (royalty.receiver, royalty.royaltyFraction);
    }

    function totalSupply() override public view returns (uint256) {
        return _mintedTokens.current();
    }

    function isApprovedForAll(address owner, address operator)
        override
        public
        view
        returns (bool)
    {
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(owner)) == operator || salesAddress == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    function _msgSender() internal view override returns (address sender) {
        return ContextMixin.msgSender();
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        string memory _tokenURI = _tokenURIs[tokenId];
        return _tokenURI;
    }

    function updateTokenURI(uint256 tokenId, string memory _tokenURI)
        override
        public
        onlyRole(HOLOSTARS_CONTRACTS)
    {
        require(!_exists(tokenId), "Token has already been minted");
        _tokenURIs[tokenId] = _tokenURI;

        emit TokenURIChanged(tokenId, _tokenURI);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}

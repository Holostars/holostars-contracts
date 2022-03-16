// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHolostarsFactory {
    event NewAvailableToken(uint256 tokenId, address indexed creator, uint256 price);
    event MaxSupplyChanged(uint256 newMaxSupply);
    event JoinedWhitelist(uint8 listNumber, address indexed member);
    event DefaultTokenPriceChanged(uint256 newDefaultPrice);
    event TokenPriceChanged(uint256 tokenId, uint256 newPrice);
    event Mint(uint256 tokenId, address indexed recipient);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 _optionId) external view returns (string memory);
    function supportsFactoryInterface() external view returns (bool);
    function setMaxSupply(uint256 _maxSupply) external;
    function joinWhitelist(uint8 _whitelistNumber) external;
    function updateDefaultTokenPrice(uint256 _tokenPrice) external;
    function updateTokenPrice(uint256 _tokenId, uint256 _newPrice) external;
    function createNFT(
        string memory _tokenURI,
        uint256 _tokenPrice,
        address _royaltyReceiver,
        uint96 _royaltyFeeNumerator
    ) external;
    function mint(uint256 _tokenId, address _toAddress) external payable;
    function tokenInfo(uint256 _tokenId)
        external
        view
        returns (address, address, uint96, string memory, uint256);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
    function ownerOf(uint256) external view returns (address _owner);
}

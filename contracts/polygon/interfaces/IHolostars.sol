// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHolostars {
    event TokenURIChanged(uint256 tokenId, string _tokenURI);
    event TokenPriceChanged(uint256 tokenId, uint256 _newPrice);

    function baseTokenURI() external pure returns (string memory);
    function contractURI() external view returns (string memory);
    function updateTokenPrice(uint256 _tokenId, uint256 _newPrice) external;
    function makeAvailableForMinting(
        string memory _tokenURI,
        uint256 _tokenPrice,
        address _royaltyReceiver,
        uint96 _royaltyFeeNumerator,
        address _creator
    ) external returns (uint256);
    function mintTo(address _to, uint256 _tokenId) external;
    function tokenRoyaltyInfo(uint256 _tokenId) external view returns (address, uint96);
    function totalSupply() external view returns (uint256);
    function updateTokenURI(uint256 tokenId, string memory _tokenURI) external;
}

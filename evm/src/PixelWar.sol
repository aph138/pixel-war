// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// import {Test, console} from "forge-std/Test.sol";

import "@openzeppelin-contracts-5.3.0/token/ERC721/ERC721.sol";
import "@openzeppelin-contracts-5.3.0/token/ERC721/extensions/ERC721Enumerable.sol";
import "./Ownable.sol";

contract PixelWar is ERC721Enumerable, Ownable {
    event NewCanvas(uint256 indexed id);
    event PixelMinted(uint256 indexed canvas, uint256 indexed id);

    error DuplicatedID(uint8 id);
    error ShortName();
    error InvalidSize();
    error InvalidCanvas();
    error InvalidPixel();
    error InvalidPurchase();
    error InvalidAction();
    error InsufficientBalance();
    error LowPrice();
    error LowValue();
    error FailedRefund();
    error FailedTransaction();

    uint256 private constant MINIMUM_PRICE = 10_000; // for calculating with bps
    uint256 private feeRateInBPS; // must be initialized in constructor

    // nftCounter keeps the track of NFTs' ID, preventing duplicate ERC721 ID
    uint256 private nftCounter;
    uint256 private canvasCounter;

    // consider saving color off-chain for free changing color.
    struct Pixel {
        uint256 nft;
        uint256 x;
        uint256 y;
        bool isMinted;
        bytes3 color; //3-byte(24-bit) for RGB and 4-byte(32-bit) for RGBA (1 hex digit = 4-bit)
        uint256 price;
        address owner;
    }

    struct Canvas {
        string name;
        uint256 height;
        uint256 width;
        uint256 initialPrice;
        uint256 minted;
        mapping(uint256 => Pixel) map;
    }

    mapping(uint256 => Canvas) canvases;

    constructor(uint256 _fee) payable ERC721("MyPixel", "mpx") {
        if (_fee >= 10000) {
            revert();
        }
        feeRateInBPS = _fee;
    }

    function newCanvas(
        string calldata _name,
        uint256 _height,
        uint256 _width,
        bytes3 _initialColor,
        uint256 _initialPrice
    ) external onlyOwner returns (uint256) {
        // check for short name
        if (bytes(_name).length <= 3) {
            revert ShortName();
        }
        // check for invalid size
        if (_height < 10 || _width < 10) {
            revert InvalidSize();
        }

        //check for minimum price
        require(_initialPrice >= MINIMUM_PRICE, LowPrice());

        // increase canvas id counter
        canvasCounter++;

        canvases[canvasCounter].name = _name;
        canvases[canvasCounter].height = _height;
        canvases[canvasCounter].width = _width;
        canvases[canvasCounter].initialPrice = _initialPrice;

        // initialize the map
        uint256 pxID = 0;
        for (uint256 x = 0; x < _width; x++) {
            for (uint256 y = 0; y < _height; y++) {
                pxID++;
                nftCounter++;

                canvases[canvasCounter].map[pxID].nft = nftCounter;
                canvases[canvasCounter].map[pxID].x = x;
                canvases[canvasCounter].map[pxID].y = y;
                canvases[canvasCounter].map[pxID].color = _initialColor;
            }
        }
        emit NewCanvas(canvasCounter);
        return canvasCounter;
    }

    function getNftCounter() external view returns (uint256) {
        return nftCounter;
    }

    function getCanvasCounter() external view returns (uint256) {
        return canvasCounter;
    }

    function getCanvasName(
        uint256 _id
    ) external view returns (string memory name_) {
        require(_checkCanvas(_id), InvalidCanvas());
        name_ = canvases[_id].name;
    }

    function getCanvasSize(
        uint256 _id
    ) external view returns (uint256 height_, uint256 width_) {
        require(_checkCanvas(_id), InvalidCanvas());
        width_ = canvases[_id].width;
        height_ = canvases[_id].height;
    }

    function getPixel(
        uint256 _canvas,
        uint256 _pixel
    )
        external
        view
        returns (
            uint256 nft_,
            uint256 x_,
            uint256 y_,
            uint256 price_,
            bytes3 color_,
            address owner_
        )
    {
        // check for canvas
        require(_checkCanvas(_canvas), InvalidCanvas());
        // check for pixel
        require(_checkPixel(_canvas, _pixel), InvalidPixel());
        Pixel storage pixel = canvases[_canvas].map[_pixel];
        nft_ = pixel.nft;
        x_ = pixel.x;
        y_ = pixel.y;
        price_ = pixel.price;

        color_ = pixel.color;
        owner_ = pixel.owner;
    }

    function purchase(
        uint256 _canvas,
        uint256 _pixel,
        bytes3 _color
    ) external payable {
        // check for canvas
        require(_checkCanvas(_canvas), InvalidCanvas());

        // check for id range
        require(_checkPixel(_canvas, _pixel), InvalidPixel());

        Pixel storage pixel = canvases[_canvas].map[_pixel];
        // check for price
        require(msg.value >= pixel.price, LowValue());

        // refund excess value
        uint256 refund = msg.value - pixel.price;
        if (refund > 0) {
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            require(success, FailedRefund());
        }

        if (_ownerOf(pixel.nft) == address(0)) {
            // minting the NFT
            _safeMint(msg.sender, pixel.nft);
            pixel.price = canvases[_canvas].initialPrice;
            emit PixelMinted(_canvas, _pixel);
        } else {
            // prevent users from purchasing their own pixel
            require(msg.sender != pixel.owner, InvalidPurchase());

            uint256 fee = (pixel.price * feeRateInBPS) / 10000;
            (bool success, ) = payable(pixel.owner).call{
                value: pixel.price - fee
            }("");
            require(success, FailedTransaction());
            _safeTransfer(pixel.owner, msg.sender, pixel.nft);
            pixel.price = pixel.price * 2;
        }
        pixel.owner = msg.sender;
        pixel.color = _color;
    }

    function changeColor(
        uint256 _canvas,
        uint256 _pixel,
        bytes3 _color
    ) external {
        // check for canvas
        require(_checkCanvas(_canvas), InvalidCanvas());
        // check for pixel
        require(_checkPixel(_canvas, _pixel), InvalidPixel());

        // check for ownership
        require(
            msg.sender == canvases[_canvas].map[_pixel].owner,
            InvalidAction()
        );
        // change color
        canvases[_canvas].map[_pixel].color = _color;
    }

    function _checkCanvas(uint256 _id) internal view returns (bool) {
        return bytes(canvases[_id].name).length > 0;
    }

    function _checkPixel(
        uint256 _canvas,
        uint256 _pixel
    ) internal view returns (bool) {
        return _pixel <= canvases[_canvas].height * canvases[_canvas].width;
    }

    function sendFromTreasury(uint256 _value, address _to) external onlyOwner {
        if (_to == address(0)) {
            revert();
        }
        if (address(this).balance < _value) {
            revert InsufficientBalance();
        }
        (bool success, ) = payable(_to).call{value: _value}("");
        require(success, "");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PixelWar} from "../src/PixelWar.sol";
import {Ownable} from "../src/Ownable.sol";
import "@openzeppelin-contracts-5.3.0/token/ERC721/IERC721Receiver.sol";

contract PixelTest is Test, IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    PixelWar public game;
    address public owner = address(this);
    address public user1 = address(0x1111);
    address public user2 = address(0x2222);
    address public unauthorized = address(0x9999);
    bytes3 private constant BLACK = 0xffffff;
    bytes3 private constant WHITE = 0x000000;

    function newCanvas() internal returns (uint256) {
        return game.newCanvas("name", 100, 100, 0x000000, 10000);
    }

    function setUp() public {
        game = new PixelWar(1000); // 10% fee
    }

    function test_ShortNameForCanvas() public {
        vm.expectRevert(PixelWar.ShortName.selector);
        game.newCanvas("a", 100, 100, 0x111111, 1000);
    }

    function test_UnauthorizedAccess() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(unauthorized);
        game.newCanvas("abcd", 10, 10, 0x111111, 10000);
    }

    function test_InvalidSizeForCanvas() public {
        vm.expectRevert(PixelWar.InvalidSize.selector);
        game.newCanvas("abcd", 9, 10, 0x111111, 10000);
        vm.expectRevert(PixelWar.InvalidSize.selector);
        game.newCanvas("abcd", 10, 9, 0x111111, 10000);
    }

    function test_InvalidCanvas() public {
        vm.expectRevert(PixelWar.InvalidCanvas.selector);
        game.getCanvasName(1);
    }

    function test_NewCanvas() public {
        uint256 id = game.newCanvas("game1", 10, 10, 0x000000, 10000);
        assertEq(id, 1);
        assertEq(game.getCanvasCounter(), 1);
        assertEq(game.getNftCounter(), 100);

        uint256 id_2 = game.newCanvas("game2", 30, 20, 0xffffff, 1000000);
        assertEq(id_2, 2);
        assertEq(game.getCanvasCounter(), 2);
        assertEq(game.getNftCounter(), 700);

        string memory name_1 = game.getCanvasName(1);
        assertEq(name_1, "game1");

        (uint256 height_2, uint256 width_2) = game.getCanvasSize(2);
        assertEq(height_2, 30);
        assertEq(width_2, 20);

        (uint256 nft_1, uint256 x_1, uint256 y_1, uint256 price_1, bytes3 color_1, address owner_1) =
            game.getPixel(1, 1);
        assertEq(nft_1, 1);
        assertEq(x_1, 0);
        assertEq(y_1, 0);
        assertEq(price_1, 0);
        assertEq(owner_1, address(0));
        // (
        //     uint nft_2,
        //     uint x_2,
        //     uint y_2,
        //     uint price_2,
        //     bytes3 color_2,
        //     address owner_2
        // ) = game.getPixel(2, 600);
        // assertEq(nft_2, 700);
        // assertEq(x_2, 19);
        // assertEq(y_2, 29);
    }

    function test_LowPrice() public {
        vm.expectRevert(PixelWar.LowPrice.selector);
        game.newCanvas("abcd", 100, 100, 0x000000, 1000);
    }

    receive() external payable {}

    function test_Purchase() public {
        uint256 id = game.newCanvas("name", 100, 100, 0x000000, 10000);

        vm.deal(user1, 2 ether);
        vm.deal(user2, 2 ether);

        (,,, uint256 price,,) = game.getPixel(id, 1);
        assertEq(price, 0);

        vm.prank(user1);
        game.purchase(1, 1, 0xFFFFFF);

        (,,, price,,) = game.getPixel(id, 1);
        assertEq(price, 10000);

        vm.deal(user1, 0);
        vm.prank(user2);
        game.purchase{value: 10000 wei}(id, 1, 0xF0F0F0);
        (,,, price,,) = game.getPixel(id, 1);
        assertEq(price, 20000);
        assertEq(user1.balance, 9000);
        assertEq(address(game).balance, 1000);
    }

    function test_Refund() public {
        uint256 id = newCanvas();

        vm.deal(user1, 10000);
        vm.prank(user1);
        game.purchase{value: 10000}(id, 1, 0xffffff);

        (,,,,, address owner) = game.getPixel(id, 1);
        assertEq(owner, user1);
        assertEq(user1.balance, 10000);
    }

    function test_InvalidPurchase() public {
        uint256 id = newCanvas();

        vm.deal(user1, 1 ether);
        vm.prank(user1);
        game.purchase(id, 1, BLACK);

        (,,,,, address owner) = game.getPixel(1, 1);
        assertEq(owner, user1);

        vm.prank(user1);
        vm.expectRevert(PixelWar.InvalidPurchase.selector);
        game.purchase{value: 10000}(1, 1, WHITE);
    }

    function test_ChangeColor() public {
        uint256 id = newCanvas();

        game.purchase(id, 1, BLACK);
        (,,,, bytes3 color,) = game.getPixel(id, 1);
        assertEq(color, BLACK);

        game.changeColor(id, 1, WHITE);
        (,,,, color,) = game.getPixel(id, 1);
        assertEq(color, WHITE);

        vm.prank(user1);
        vm.expectRevert(PixelWar.InvalidAction.selector);
        game.changeColor(id, 1, BLACK);
    }

    function test_SendFromTreasury() public {
        vm.deal(address(game), 2 ether);
        assertEq(address(game).balance, 2 ether);

        // unauthorized
        vm.prank(user1);
        vm.expectRevert(Ownable.Unauthorized.selector);
        game.sendFromTreasury(1 ether, user2);

        // successful
        vm.deal(user2, 0);
        game.sendFromTreasury(1 ether, user2);
        assertEq(address(game).balance, 1 ether);
        assertEq(user2.balance, 1 ether);

        // insufficient balance
        vm.expectRevert(PixelWar.InsufficientBalance.selector);
        game.sendFromTreasury(2 ether, user2);
    }
}

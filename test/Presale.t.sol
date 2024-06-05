// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Presale.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract PresaleTest is Test {
    Presale presale;
    MockERC20 token;
    address owner = address(1);
    address buyer = address(2);

    function setUp() public {
        vm.startPrank(owner);
        token = new MockERC20("Mock Token", "MKT", 100_000 * 1e18); // 100,000 tokens with 18 decimals
        presale = new Presale(
            IERC20(address(token)),
            100,
            block.timestamp + 10,
            block.timestamp + 1000
        );
        vm.stopPrank();
    }

    // helper functions start
    function addToWhitelist(address account) public {
        vm.startPrank(owner);
        presale.addToWhitelist(account);
        vm.stopPrank();
    }

    function depositTokens(uint256 amount) public {
        vm.startPrank(owner);
        token.approve(address(presale), amount);
        presale.depositTokens(amount);
        vm.stopPrank();
    }

    // helper functions end

    function testInitialValues() public view {
        assertEq(address(presale.token()), address(token));
        assertEq(presale.price(), 100);
    }

    //constructor tests start
    function testConstructorValid() public {
        Presale _presale = new Presale(
            IERC20(address(token)),
            100,
            block.timestamp + 10,
            block.timestamp + 1000
        );
        assertEq(address(_presale.token()), address(token));
        assertEq(_presale.price(), 100);
        assertEq(_presale.startTime(), block.timestamp + 10);
        assertEq(_presale.endTime(), block.timestamp + 1000);
    }

    function testConstructorInvalidToken() public {
        vm.startPrank(owner);
        vm.expectRevert();
        new Presale(
            IERC20(address(0)),
            100,
            block.timestamp + 10,
            block.timestamp + 1000
        );
    }

    function testConstructorInvalidPrice() public {
        vm.startPrank(owner);
        vm.expectRevert();
        new Presale(
            IERC20(address(token)),
            0,
            block.timestamp + 10,
            block.timestamp + 1000
        );
    }

    function testConstructorInvalidStart() public {
        vm.startPrank(owner);
        vm.warp(block.timestamp + 100);
        vm.expectRevert("Start time must be in future");
        new Presale(
            IERC20(address(token)),
            100,
            block.timestamp,
            block.timestamp + 1000
        );
    }

    function testConstructorInvalidEnd() public {
        vm.startPrank(owner);
        vm.expectRevert("Start time must be before end time");
        new Presale(
            IERC20(address(token)),
            100,
            block.timestamp + 1000,
            block.timestamp
        );
    }

    // constructor tests end

    // buyTokens tests start
    function testBuyBeforeSaleStart() public {
        vm.startPrank(buyer);
        vm.deal(buyer, 1 ether);
        vm.warp(block.timestamp + 5); // Move to a time before the sale starts
        vm.expectRevert("Token sale is not open");
        presale.buyTokens{value: 1 ether}();
    }

    function testBuyAfterSaleEnd() public {
        vm.startPrank(buyer);
        vm.deal(buyer, 1 ether);
        vm.warp(block.timestamp + 1005);
        vm.expectRevert("Token sale is not open");
        presale.buyTokens{value: 1 ether}();
    }

    function testNotEnoughFunds() public {
        vm.startPrank(buyer);
        vm.deal(buyer, 1 ether);
        vm.warp(block.timestamp + 15); // Move to a time after the sale starts
        vm.expectRevert("Amount must be greater than zero");
        presale.buyTokens{value: 0}();
    }

    function testNotWhitelistedPurchase() public {
        vm.startPrank(buyer);
        vm.deal(buyer, 1 ether);
        vm.warp(block.timestamp + 15);
        vm.expectRevert("Address not whitelisted");
        presale.buyTokens{value: 1 ether}();
    }

    function testWhitelistedPurchase() public {
        depositTokens(100 ether);
        addToWhitelist(buyer);
        vm.startPrank(buyer);
        vm.deal(buyer, 1 ether);
        vm.warp(block.timestamp + 15);
        presale.buyTokens{value: 1 ether}();
        assertEq(token.balanceOf(buyer), 100 * 1e18);
        assertEq(presale.amountCollected(), 1 ether);
    }

    function testLargeQtyPurchase() public {
        depositTokens(10000 * 10 ** 18);
        addToWhitelist(buyer);
        vm.startPrank(buyer);
        vm.deal(buyer, 100 ether);
        vm.warp(block.timestamp + 15);
        presale.buyTokens{value: 100 ether}();
        assertEq(token.balanceOf(buyer), 10000 * 1e18);
        assertEq(presale.amountCollected(), 100 ether);
    }

    function testInsufficientTokenBalance() public {
        addToWhitelist(buyer);
        vm.startPrank(buyer);
        vm.deal(buyer, 1 ether);
        vm.warp(block.timestamp + 15);
        vm.expectRevert("Insufficient token balance in contract");
        presale.buyTokens{value: 1 ether}();
    }

    // buyTokens tests end

    function testDepositTokens() public {
        depositTokens(100 ether);
        assertEq(token.balanceOf(address(presale)), 100 * 1e18);
    }

    function testWithdrawFunds() public {
        addToWhitelist(buyer);
        depositTokens(100 ether);
        vm.startPrank(buyer);
        vm.deal(buyer, 1 ether);
        vm.warp(block.timestamp + 15);
        presale.buyTokens{value: 1 ether}();
        assertEq(presale.amountCollected(), 1 ether);
        vm.stopPrank();
        vm.startPrank(owner);
        presale.withdrawFunds();
        vm.stopPrank();
        assertEq(address(owner).balance, 1 ether);
        assertEq(address(presale).balance, 0);
    }

    function testWithdrawFundsNoFunds() public {
        vm.startPrank(owner);
        vm.expectRevert("No funds to withdraw");
        presale.withdrawFunds();
    }

    function testNotOwnerWithdrawFunds() public {
        vm.startPrank(buyer);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer
            )
        );
        presale.addToWhitelist(buyer);
    }

    function testUpdatePriceZero() public {
        vm.startPrank(owner);
        vm.expectRevert("Price must be greater than 0");
        presale.updatePrice(0);
    }

    function testUpdatePrice() public {
        vm.startPrank(owner);
        presale.updatePrice(200);
        vm.stopPrank();
        assertEq(presale.price(), 200);
    }

    function  testUpdatePriceNotOwner() public {
        vm.startPrank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer
            )
        );
        presale.updatePrice(200);
    }

    function testAddToWhitelist() public {
        addToWhitelist(buyer);
        assert(presale.whitelist(buyer));
    }

    function addToWhitelistWithoutOwner() public {
        vm.startPrank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer
            )
        );
        presale.addToWhitelist(buyer);
    }

    function testAddToWhitelistTwice() public {
        addToWhitelist(buyer);
        addToWhitelist(buyer);
        assert(presale.whitelist(buyer));
    }

    function testAddToWhitelistMultiple() public {
        addToWhitelist(buyer);
        addToWhitelist(owner);
        assert(presale.whitelist(buyer));
        assert(presale.whitelist(owner));
    }

    function testAddToWhitelistMultipleTwice() public {
        addToWhitelist(buyer);
        addToWhitelist(owner);
        addToWhitelist(buyer);
        addToWhitelist(owner);
        assert(presale.whitelist(buyer));
        assert(presale.whitelist(owner));
    }

    function testRemoveFromWhitelist() public {
        addToWhitelist(buyer);
        vm.startPrank(owner);
        presale.removeFromWhitelist(buyer);
        vm.stopPrank();
        assert(!presale.whitelist(buyer));
    }

    function testRemoveFromWhitelistTwice() public {
        addToWhitelist(buyer);
        vm.startPrank(owner);
        presale.removeFromWhitelist(buyer);
        presale.removeFromWhitelist(buyer);
        vm.stopPrank();
        assert(!presale.whitelist(buyer));
    }

    function removeFromWhitelistWithoutAdding() public {
        vm.startPrank(owner);
        presale.removeFromWhitelist(buyer);
        vm.stopPrank();
        assert(!presale.whitelist(buyer));
    }

    function testRemoveFromWhitelistMultiple() public {
        addToWhitelist(buyer);
        addToWhitelist(owner);
        vm.startPrank(owner);
        presale.removeFromWhitelist(buyer);
        presale.removeFromWhitelist(owner);
        vm.stopPrank();
        assert(!presale.whitelist(buyer));
        assert(!presale.whitelist(owner));
    }

    function testAddManyToWhitelist() public {
        address[] memory accounts = new address[](2);
        accounts[0] = buyer;
        accounts[1] = owner;
        vm.startPrank(owner);
        presale.addManyToWhitelist(accounts);
        vm.stopPrank();
        assert(presale.whitelist(buyer));
        assert(presale.whitelist(owner));
    }

    function testAddManyToWhitelistTwice() public {
        address[] memory accounts = new address[](2);
        accounts[0] = buyer;
        accounts[1] = owner;
        vm.startPrank(owner);
        presale.addManyToWhitelist(accounts);
        presale.addManyToWhitelist(accounts);
        vm.stopPrank();
        assert(presale.whitelist(buyer));
        assert(presale.whitelist(owner));
    }

    function testUpdateSaleTime() public {
        vm.startPrank(owner);
        presale.updateSaleTime(block.timestamp + 100, block.timestamp + 1000);
        vm.stopPrank();
        assertEq(presale.startTime(), block.timestamp + 100);
        assertEq(presale.endTime(), block.timestamp + 1000);
    }

    function testUpdateSaleTimeInvalidEnd() public {
        vm.startPrank(owner);
        vm.expectRevert("Start time must be before end time");
        presale.updateSaleTime(block.timestamp + 1000, block.timestamp + 100);
    }

    function testUpdateTimeNotOwner() public {
        vm.startPrank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer
            )
        );
        presale.updateSaleTime(block.timestamp + 100, block.timestamp + 1000);
    }

    function testUpdateSaleTimeInvalid() public {
        vm.startPrank(owner);
        vm.warp(block.timestamp + 100);
        vm.expectRevert("Start time must be in future");
        presale.updateSaleTime(block.timestamp, block.timestamp + 1000);
    }

    function testWithdrawTokens() public {
        depositTokens(100 ether);
        // transfer all the owner tokens to new address

        vm.startPrank(owner);
        token.transfer(address(3), token.balanceOf(owner));
        assertEq(token.balanceOf(owner), 0);

        presale.withdrawTokens(10 * 1e18);
        vm.stopPrank();
        assertEq(token.balanceOf(owner), 10 * 1e18);
        assertEq(token.balanceOf(address(presale)), 90 * 1e18);
    }

    function testWithdrawTokensNotOwner() public {
        vm.startPrank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                buyer
            )
        );
        presale.withdrawTokens(10 * 1e18);
    }

    function testWithdrawTokensZeroAmount() public {
        vm.startPrank(owner);
        vm.expectRevert("Amount must be greater than zero");
        presale.withdrawTokens(0);
    }

    function testWithdrawTokensInsufficientBalance() public {
        vm.startPrank(owner);
        vm.expectRevert("Insufficient token balance in contract");
        presale.withdrawTokens(1000 * 1e18);
    }

    function testReceiveOwner() public {
        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        vm.expectRevert("ETH transfers not allowed");
        payable(presale).transfer(1 ether);
    }

    function testReceiveBuyer() public {
        vm.startPrank(buyer);
        vm.deal(buyer, 1 ether);
        vm.expectRevert("ETH transfers not allowed");
        payable(presale).transfer(1 ether);
    }
}

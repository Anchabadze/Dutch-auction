// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract AucEngine {
    address public owner; // contract owner
    uint256 constant DURATION = 2 days; // auction duration
    uint256 constant FEE = 10; // 10%

    struct Auction {
        address payable seller; // seller
        uint256 startingPrice; // starting price (maximum price)
        uint256 finalPrice; // final price (sold price)
        uint256 startAt; // auction start time
        uint256 endAt; // auction end time
        uint256 discountRate; // discount rate per second
        string item; // item description (could be NFT address)
        bool stopped; // whether the auction has ended
    }

    Auction[] public auctions; // array of auctions

    event AuctionCreated(uint256 index, string itemName, uint256 startingPrice, uint256 duration);
    event AuctionEnded(uint256 index, string itemName, uint256 finalPrice, address buyer);

    constructor() {
        owner = msg.sender;
    }

    // starting price, discount rate, item description, auction duration (if 0, default value of 2 days is used)
    function createAuction(uint256 _startingPrice, uint256 _discountRate, string calldata _item, uint256 _duration)
        external
    {
        uint256 duration = _duration == 0 ? DURATION : _duration; // if _duration == 0, duration = DURATION, otherwise duration = _duration
        require(_startingPrice >= _discountRate * duration, "incorrect starting price"); // ensure starting price is at least discount rate times duration to avoid negative price

        Auction memory newAuction = Auction({ // create a new auction
            seller: payable(msg.sender),
            startingPrice: _startingPrice,
            finalPrice: 0,
            startAt: block.timestamp,
            endAt: block.timestamp + duration,
            discountRate: _discountRate,
            item: _item,
            stopped: false
        });

        auctions.push(newAuction); // add the new auction to the array

        emit AuctionCreated(auctions.length - 1, _item, _startingPrice, duration); // log the creation of the auction
    }

    // get the current price of the auction
    function getPriceFor(uint256 index) public view returns (uint256) {
        Auction memory auction = auctions[index]; // get the auction by index
        require(auction.endAt > block.timestamp, "auction is over"); // ensure the auction is not over
        uint256 elapsed = block.timestamp - auction.startAt; // calculate elapsed time
        uint256 discount = auction.discountRate * elapsed; // calculate the discount
        return auction.startingPrice - discount; // return the current price
    }

    function buy(uint256 index) external payable {
        Auction storage auction = auctions[index];
        require(auction.endAt > block.timestamp, "auction is over"); // ensure the auction is not over
        uint256 cPrice = getPriceFor(index); // get the current price
        require(msg.value >= cPrice, "not enough funds!"); // ensure sufficient funds are sent
        auction.stopped = true; // end the auction
        auction.finalPrice = cPrice; // record the final price
        uint256 refund = msg.value - cPrice; // calculate the refund
        if (refund > 0) {
            payable(msg.sender).transfer(refund); // send the refund
        }
        auction.seller.transfer(
            cPrice - (cPrice * FEE) / 100 // send funds to the seller minus the platform fee
        );
        payable(owner).transfer((cPrice * FEE) / 100); // send the platform fee
        emit AuctionEnded(index, auction.item, cPrice, msg.sender); // log the end of the auction
    }
}

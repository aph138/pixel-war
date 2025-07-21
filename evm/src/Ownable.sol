// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Ownable {
    error Unauthorized();
    error InvalidOwnerAddress();

    address public _owner;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, Unauthorized());
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            _owner = newOwner;
        } else {
            revert InvalidOwnerAddress();
        }
    }
}

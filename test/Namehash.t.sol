// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Namehash} from "../contracts/Namehash.sol";
import "forge-std/Test.sol";

contract TestNamehash is Test {
    function test_parse() external pure {
        bytes memory sizes;
        (sizes, , ) = Namehash.parse("\x00");
        assertEq(sizes, hex"");
        (sizes, , ) = Namehash.parse("\x03eth\x00");
        assertEq(sizes, hex"03");
        (sizes, , ) = Namehash.parse("\x05raffy\x03eth\x00");
        assertEq(sizes, hex"0503");
        (sizes, , ) = Namehash.parse("\x05chonk\x05raffy\x03eth\x00");
        assertEq(sizes, hex"050503");
    }

    function test_hash() external pure {
        (bytes memory sizes, uint256 ptr, bool junk) = Namehash.parse(
            "\x05chonk\x05raffy\x03eth\x00"
        );
        assertEq(junk, false);
        assertEq(
            Namehash.hash(ptr, sizes, 0),
            0x0000000000000000000000000000000000000000000000000000000000000000
        );
        assertEq(
            Namehash.hash(ptr, sizes, 1),
            0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae
        );
        assertEq(
            Namehash.hash(ptr, sizes, 2),
            0x9c8b7ac505c9f0161bbbd04437fce8c630a0886e1ffea00078e298f063a8a5df
        );
        assertEq(
            Namehash.hash(ptr, sizes, 3),
            0x4b3a3e50333a34895a3274af766985084a9aa3909721f54e4439622800c91b97
        );
    }
}

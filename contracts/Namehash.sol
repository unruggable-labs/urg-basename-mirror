// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

error InvalidName();

library Namehash {
    /**
     * @dev parse dns-encoded name into efficient structure
     * @param dnsname dns-encoded name
     * @return sizes array of label lengths, eg. "raffy.eth" => [5, 3]
     * @return ptr memory-offset of dns-encoded name (at end)
     * @return junk true if
     */
    // "raffy.eth" => sizes = [5, 3]
    //           ^==> ptr
    function parse(
        bytes memory dnsname
    ) internal pure returns (bytes memory sizes, uint256 ptr, bool junk) {
        sizes = new bytes(dnsname.length >> 1);
        uint256 offset;
        uint256 count;
        while (true) {
            uint256 size = uint8(dnsname[offset]); // revert if oob
            if (size == 0) break;
            sizes[count++] = bytes1(uint8(size));
            offset += 1 + size;
        }
        junk = dnsname.length > offset + 1; // has extra junk
        assembly {
            mstore(sizes, count)
            ptr := add(dnsname, add(33, offset)) // +1 so we can subtract 1+size
        }
    }

    /**
     * @dev compute next namehash
     * @param _node parent namehash
     * @param _ptr memory-offset of dns-encoded parent name
     * @param size length of label
     * @return node_ namehash of label + parent
     * @return ptr_ memory-offset of child-name
     */
    function next(
        bytes32 _node,
        uint256 _ptr,
        uint8 size
    ) internal pure returns (bytes32 node_, uint256 ptr_) {
        assembly {
            ptr_ := sub(_ptr, add(1, size))
            mstore(0, _node)
            mstore(32, keccak256(ptr_, size))
            node_ := keccak256(0, 64)
        }
    }

    /**
     * @dev compute namehash
     * @notice (ptr, sizes) are from parse()
     * @param ptr memory-offset of dns-encoded name
     * @param sizes array of label lengths
     * @param count number of labels
     * @return node namehash of <count> labels
     */
    function hash(
        uint256 ptr,
        bytes memory sizes,
        uint256 count
    ) internal pure returns (bytes32 node) {
        uint256 n = sizes.length;
        uint256 stop = n - count; // reverts if too many labels
        while (n > stop) {
            (node, ptr) = next(node, ptr, uint8(sizes[--n]));
        }
    }
}

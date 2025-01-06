// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { GatewayFetcher, GatewayRequest } from '@unruggable/gateways/contracts/GatewayFetcher.sol';
import { GatewayFetchTarget, IGatewayVerifier } from '@unruggable/gateways/contracts/GatewayFetchTarget.sol';
import { IExtendedResolver } from '@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol';
import { NameEncoder } from '@ensdomains/ens-contracts/contracts/utils/NameEncoder.sol';
import { LibBytes } from 'solady/src/utils/LibBytes.sol';

bytes4 constant SEL_addr60 = 0x3b3b57de; // addr(byte32)
bytes4 constant SEL_addr = 0xf1cb7e06; // addr(bytes32,uint256)
bytes4 constant SEL_text = 0x59d1d43c; // text(bytes32,string)
bytes4 constant SEL_contenthash = 0xbc1c58d1; // contenthash(bytes32)

uint256 constant SLOT_VERSIONS = 0;
uint256 constant SLOT_ADDR = 2;
uint256 constant SLOT_TEXT = 10;
uint256 constant SLOT_CONTENTHASH = 3;

contract BasenameResolver is GatewayFetchTarget, IExtendedResolver {
    using GatewayFetcher for GatewayRequest;
    using NameEncoder for string;

    IGatewayVerifier immutable _verifier;
    address immutable _target;

    constructor(IGatewayVerifier verifier, address target) {
        _verifier = verifier;
        _target = target;
    }

    function supportsInterface(bytes4 x) external pure returns (bool) {
        return x == type(IExtendedResolver).interfaceId;
    }

    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory) {
        (, , bytes32 node) = getBasename(name);
        GatewayRequest memory req = GatewayFetcher.newRequest(1);
        req.setTarget(_target); // target the base resolver
        req.push(node); // push the namehash of "raffy.base.eth" at offset 0
        req.setSlot(SLOT_VERSIONS); // recordVersions[]
        req.pushStack(0);
        req.follow(); // recordVersions[node]
        req.read(); // leave version on stack at offset 1
        if (bytes4(data) == SEL_addr60) {
            req.setSlot(SLOT_ADDR); // addresses[]
            req.pushStack(1).follow(); // addresses[version]
            req.pushStack(0).follow(); // addresses[version][node]
            req.push(60).follow(); // addresses[version][node][60]
            req.readBytes().setOutput(0); // save address to output 0
        } else if (bytes4(data) == SEL_addr) {
            (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
            req.setSlot(SLOT_ADDR);
            req.pushStack(1).follow();
            req.pushStack(0).follow();
            req.push(coinType).follow();
            req.readBytes().setOutput(0);
        } else if (bytes4(data) == SEL_text) {
            (, string memory key) = abi.decode(data[4:], (bytes32, string));
            req.setSlot(SLOT_TEXT);
            req.pushStack(1).follow();
            req.pushStack(0).follow();
            req.push(key).follow();
            req.readBytes().setOutput(0);
        } else if (bytes4(data) == SEL_contenthash) {
            req.setSlot(SLOT_CONTENTHASH);
            req.pushStack(1).follow();
            req.pushStack(0).follow();
            req.readBytes().setOutput(0);
        } else {
            return new bytes(64);
        }
        fetch(_verifier, req, this.resolveCallback.selector, data, new string[](0));
    }

    function resolveCallback(
        bytes[] memory values,
        uint8 /*exitCode*/,
        bytes memory data
    ) external pure returns (bytes memory) {
        bytes memory value = values[0];
        if (bytes4(data) == SEL_addr60) {
            return abi.encode(address(bytes20(value)));
        } else {
            return abi.encode(value);
        }
    }

    /**
     * @dev Port of findResolver func from UniversalResolver to parse DNS encoded names to string
     */
    function parseDnsName(bytes calldata name, uint256 offset) internal pure returns (bytes memory) {
        uint256 labelLength = uint256(uint8(name[offset]));
        if (labelLength == 0) {
            return new bytes(0);
        }
        uint256 nextLabel = offset + labelLength + 1;
        bytes memory namebytes = name[offset + 1:nextLabel];
        bytes memory parentname = parseDnsName(name, nextLabel);
        return parentname.length != 0 ? bytes.concat(namebytes, '.', parentname) : namebytes;
    }

    /**
     * @dev Converts DNS encoded yoursubname.yourname.eth to yoursubname.yourname.base.eth
     * Basename => base.eth
     */
    function getBasename(bytes calldata dnsEncoded) public pure returns (string memory, string memory, bytes32) {
        bytes memory fullname = parseDnsName(dnsEncoded, 0);
        bytes[] memory labelArray = LibBytes.split(fullname, bytes('.'));
        bytes memory basename = labelArray[0];

        // Remove .eth and append with .base.eth
        for (uint i = 1; i < labelArray.length - 1; ++i) {
            basename = bytes.concat(basename, '.', labelArray[i]);
        }
        basename = bytes.concat(basename, '.base.eth');

        (, bytes32 node) = string(basename).dnsEncodeName();

        return (string(fullname), string(basename), node);
    }
}

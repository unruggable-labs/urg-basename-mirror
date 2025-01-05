// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {GatewayFetcher, GatewayRequest} from "@unruggable/gateways/contracts/GatewayFetcher.sol";
import {GatewayFetchTarget, IGatewayVerifier} from "@unruggable/gateways/contracts/GatewayFetchTarget.sol";

interface IExtendedResolver {
    function resolve(
        bytes memory,
        bytes memory
    ) external view returns (bytes memory);
}

bytes4 constant SEL_addr60 = 0x3b3b57de; // addr(byte32)
bytes4 constant SEL_addr = 0xf1cb7e06; // addr(bytes32,uint256)
bytes4 constant SEL_text = 0x59d1d43c; // text(bytes32,string)
bytes4 constant SEL_contenthash = 0xbc1c58d1; // contenthash(bytes32)

uint256 constant SLOT_VERSIONS = 0;
uint256 constant SLOT_ADDR = 2;
uint256 constant SLOT_TEXT = 10;
uint256 constant SLOT_CONTENTHASH = 3;

// https://adraffy.github.io/keccak.js/test/demo.html#algo=namehash&s=base.eth&escape=1&encoding=utf8
bytes32 constant NODE_BASE_ETH = 0xff1e3c0eb00ec714e34b6114125fbde1dea2f24a72fbf672e7b7fd5690328e10;

contract BasenameResolver is GatewayFetchTarget, IExtendedResolver {
    using GatewayFetcher for GatewayRequest;

    IGatewayVerifier immutable _verifier;
    address immutable _target;

    constructor(IGatewayVerifier verifier, address target) {
        _verifier = verifier;
        _target = target;
    }

    function supportsInterface(bytes4 x) external pure returns (bool) {
        return x == type(IExtendedResolver).interfaceId;
    }

    function resolve(
        bytes calldata name,
        bytes calldata data
    ) external view returns (bytes memory) {
        bytes32 label = _leadingLabelhash(name);
        bytes32 node = keccak256(abi.encode(NODE_BASE_ETH, label));
        GatewayRequest memory req = GatewayFetcher.newRequest(1);
        req.setTarget(_target);
        req.push(node); // ==> node
        req.setSlot(SLOT_VERSIONS);
        req.pushStack(0);
        req.follow();
        req.read(); // ==> version
        if (bytes4(data) == SEL_addr60) {
            req.setSlot(SLOT_ADDR);
            req.pushStack(1).follow();
            req.pushStack(0).follow();
            req.push(60).follow();
            req.readBytes().setOutput(0);
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
        fetch(
            _verifier,
            req,
            this.resolveCallback.selector,
            data,
            new string[](0)
        );
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

    function _leadingLabelhash(
        bytes calldata name
    ) internal pure returns (bytes32) {
        uint256 n = uint8(name[0]);
        return keccak256(name[1:1 + n]);
    }
}

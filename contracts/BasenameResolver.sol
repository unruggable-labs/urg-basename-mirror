// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {GatewayFetcher, GatewayRequest} from "@unruggable/gateways/contracts/GatewayFetcher.sol";
import {GatewayFetchTarget, IGatewayVerifier} from "@unruggable/gateways/contracts/GatewayFetchTarget.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {IExtendedResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol";
import {IAddrResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddrResolver.sol";
import {IAddressResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddressResolver.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {IContentHashResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IContenthashResolver.sol";
import {INameWrapper} from "@ensdomains/ens-contracts/contracts/wrapper/INameWrapper.sol";
import {Namehash} from "./Namehash.sol";

// storage slots for Base L2Resolver
// https://basescan.org/address/0xC6d566A56A1aFf6508b41f6c90ff131615583BCD#code
uint256 constant SLOT_VERSIONS = 0;
uint256 constant SLOT_ADDR = 2;
uint256 constant SLOT_TEXT = 10;
uint256 constant SLOT_CONTENTHASH = 3;

// https://adraffy.github.io/keccak.js/test/demo.html#algo=namehash&s=eth&escape=1&encoding=utf8
bytes32 constant NODE_ETH = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
// https://adraffy.github.io/keccak.js/test/demo.html#algo=namehash&s=base.eth&escape=1&encoding=utf8
bytes32 constant NODE_BASE_ETH = 0xff1e3c0eb00ec714e34b6114125fbde1dea2f24a72fbf672e7b7fd5690328e10;

error Unauthorized();
error Unreachable(bytes dnsname);

event NodeChanged(bytes32 indexed node, bytes32 indexed basenode);

contract BasenameResolver is
    GatewayFetchTarget,
    IExtendedResolver,
    IERC165,
    Ownable
{
    using GatewayFetcher for GatewayRequest;

    ENS immutable _ens;
    INameWrapper immutable _wrapper;
    IGatewayVerifier immutable _verifier;
    address immutable _target;

    mapping(bytes32 => bytes32) _aliases;

    constructor(
        ENS ens,
        INameWrapper wrapper,
        IGatewayVerifier verifier,
        address target
    ) Ownable(msg.sender) {
        _ens = ens;
        _wrapper = wrapper;
        _verifier = verifier;
        _target = target;
        _aliases[NODE_ETH] = NODE_BASE_ETH;
    }

    function supportsInterface(bytes4 x) external pure returns (bool) {
        return
            x == type(IERC165).interfaceId ||
            x == type(IExtendedResolver).interfaceId;
    }

    function resolve(
        bytes calldata dnsname,
        bytes calldata data
    ) external view returns (bytes memory) {
        bytes32 node = getNode(dnsname);
        GatewayRequest memory req = GatewayFetcher.newRequest(1);
        req.setTarget(_target); // target the base resolver
        req.push(node); // namehash, leave on stack at offset 0
        req.setSlot(SLOT_VERSIONS); // recordVersions
        req.pushStack(0).follow(); // recordVersions[node]
        req.read(); // version, leave on stack at offset 1
        if (bytes4(data) == IAddrResolver.addr.selector) {
            req.setSlot(SLOT_ADDR); // addr
            req.pushStack(1).follow(); // addr[version]
            req.pushStack(0).follow(); // addr[version][node]
            req.push(60).follow(); // addr[version][node][60]
            req.readBytes().setOutput(0);
        } else if (bytes4(data) == IAddressResolver.addr.selector) {
            (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
            req.setSlot(SLOT_ADDR); // addr
            req.pushStack(1).follow(); // addr[version]
            req.pushStack(0).follow(); // addr[version][node]
            req.push(coinType).follow(); // addr[version][node][coinType]
            req.readBytes().setOutput(0);
        } else if (bytes4(data) == ITextResolver.text.selector) {
            (, string memory key) = abi.decode(data[4:], (bytes32, string));
            req.setSlot(SLOT_TEXT); // text
            req.pushStack(1).follow(); // text[version]
            req.pushStack(0).follow(); // text[version][node]
            req.push(key).follow(); // text[version][node][key]
            req.readBytes().setOutput(0);
        } else if (bytes4(data) == IContentHashResolver.contenthash.selector) {
            req.setSlot(SLOT_CONTENTHASH); // contenthash
            req.pushStack(1).follow(); // contenthash[version]
            req.pushStack(0).follow(); // contenthash[version][node]
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
        if (bytes4(data) == IAddrResolver.addr.selector) {
            return abi.encode(address(bytes20(value)));
        } else {
            return abi.encode(value);
        }
    }

    function setNode(bytes32 node, bytes32 basenode) external {
        address owner = _ens.owner(node);
        if (
            owner == address(_wrapper)
                ? !_wrapper.canModifyName(node, msg.sender)
                : (owner != msg.sender &&
                    !_ens.isApprovedForAll(owner, msg.sender))
        ) {
            revert Unauthorized();
        }
        _aliases[node] = basenode;
		emit NodeChanged(node, basenode);
    }

    // eg. "raffy.eth" => "raffy.base.eth"
    // (.*)[src] => (*.)[dst]
    function getNode(bytes calldata dnsname) public view returns (bytes32) {
        (bytes memory sizes, uint256 ptr, ) = Namehash.parse(dnsname);
        bytes32 node = bytes32(0);
        for (uint256 i = sizes.length; i > 0; ) {
            (node, ptr) = Namehash.next(node, ptr, uint8(sizes[--i]));
            bytes32 basenode = _aliases[node];
            if (basenode != bytes32(0)) {
                while (i > 0) {
                    (basenode, ptr) = Namehash.next(
                        basenode,
                        ptr,
                        uint8(sizes[--i])
                    );
                }
                return basenode;
            }
        }
        revert Unreachable(dnsname);
    }
}

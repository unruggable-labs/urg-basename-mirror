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
import {IContentHashResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IContentHashResolver.sol";
import {INameWrapper} from "@ensdomains/ens-contracts/contracts/wrapper/INameWrapper.sol";
import {Namehash} from "./Namehash.sol";

contract BasenameResolver is
    GatewayFetchTarget,
    IExtendedResolver,
    IERC165,
    Ownable
{
    using GatewayFetcher for GatewayRequest;

    error UnsupportedResolverProfile(bytes4 selector);
    error UnreachableName(bytes name);
    error Unauthorized();

    event NodeChanged(bytes32 indexed node, bytes32 indexed basenode);
    event GatewayURLsChanged();

    // storage slots for Base L2Resolver
    // https://basescan.org/address/0xC6d566A56A1aFf6508b41f6c90ff131615583BCD#code
    uint256 constant SLOT_VERSIONS = 0;
    uint256 constant SLOT_ADDR = 2;
    uint256 constant SLOT_TEXT = 10;
    uint256 constant SLOT_CONTENTHASH = 3;

    bytes32 constant NODE_ETH = keccak256(abi.encode(0, keccak256("eth")));
    bytes32 constant NODE_BASE_ETH =
        keccak256(abi.encode(NODE_ETH, keccak256("base")));

    ENS immutable _ens;
    INameWrapper immutable _wrapper;
    IGatewayVerifier public immutable baseVerifier;
    string[] public gatewayURLs;
    address public immutable baseResolver;

    mapping(bytes32 => bytes32) _aliases;

    constructor(
        ENS ens,
        INameWrapper wrapper,
        IGatewayVerifier _baseVerifier,
        string[] memory gateways,
        address _baseResolver
    ) Ownable(msg.sender) {
        _ens = ens;
        _wrapper = wrapper;
        baseVerifier = _baseVerifier;
        gatewayURLs = gateways;
        baseResolver = _baseResolver;
        _aliases[NODE_ETH] = NODE_BASE_ETH;
    }

    function supportsInterface(bytes4 x) external pure returns (bool) {
        return
            x == type(IERC165).interfaceId ||
            x == type(IExtendedResolver).interfaceId;
    }

    function setGatewayURLs(string[] memory gateways) external onlyOwner {
        gatewayURLs = gateways;
        emit GatewayURLsChanged();
    }

    function resolve(
        bytes calldata name,
        bytes calldata data
    ) external view returns (bytes memory) {
        bytes32 node = getNode(name);
        GatewayRequest memory req = GatewayFetcher.newRequest(1);
        req.setTarget(baseResolver); // target the base resolver
        req.push(node); // namehash, leave on stack at offset 0
        req.setSlot(SLOT_VERSIONS); // recordVersions
        req.pushStack(0).follow(); // recordVersions[node]
        req.read(); // version, leave on stack at offset 1
        bytes4 selector = bytes4(data);
        if (selector == IAddrResolver.addr.selector) {
            req.setSlot(SLOT_ADDR); // addr
            req.follow().follow().push(60).follow(); // addr[version][node][60]
            req.readBytes().setOutput(0);
        } else if (selector == IAddressResolver.addr.selector) {
            (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
            req.setSlot(SLOT_ADDR); // addr
            req.follow().follow().push(coinType).follow(); // addr[version][node][coinType]
            req.readBytes().setOutput(0);
        } else if (selector == ITextResolver.text.selector) {
            (, string memory key) = abi.decode(data[4:], (bytes32, string));
            req.setSlot(SLOT_TEXT); // text
            req.follow().follow().push(key).follow(); // text[version][node][key]
            req.readBytes().setOutput(0);
        } else if (selector == IContentHashResolver.contenthash.selector) {
            req.setSlot(SLOT_CONTENTHASH); // contenthash
            req.follow().follow(); // contenthash[version][node]
            req.readBytes().setOutput(0);
        } else {
            revert UnsupportedResolverProfile(selector);
        }
        fetch(
            baseVerifier,
            req,
            this.resolveCallback.selector,
            data,
            gatewayURLs
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
    function getNode(bytes calldata name) public view returns (bytes32) {
        (bytes memory sizes, uint256 ptr, ) = Namehash.parse(name);
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
        revert UnreachableName(name);
    }
}

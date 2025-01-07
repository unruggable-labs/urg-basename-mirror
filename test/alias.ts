import { Foundry } from "@adraffy/blocksmith";
import { dnsEncode, namehash } from "ethers/hash";
import { hijackRegistryOwner } from "./ens-utils.js";
import {
	ENS_REGISTRY,
	NAME_WRAPPER,
	BASE_VERIFIER,
	BASE_L2_RESOLVER,
} from "./constants.js";

const foundry = await Foundry.launch({
	fork: "https://rpc.ankr.com/eth",
	infoLog: false,
});

const BasenameResolver = await foundry.deploy({
	file: "BasenameResolver",
	args: [ENS_REGISTRY, NAME_WRAPPER, BASE_VERIFIER, BASE_L2_RESOLVER],
});

//
console.log();
console.log(namehash("raffy.base.eth"));
console.log(await BasenameResolver.getNode(dnsEncode("raffy.eth")));

//
console.log();
console.log(namehash("abc.raffy.base.eth"));
console.log(await BasenameResolver.getNode(dnsEncode("abc.raffy.eth")));

//
await hijackRegistryOwner(foundry, "chonk.xyz");
await foundry.confirm(
	BasenameResolver.setNode(
		namehash("chonk.xyz"),
		namehash("chonker.base.eth")
	)
);
console.log();
console.log(namehash("abc.chonker.base.eth"));
console.log(await BasenameResolver.getNode(dnsEncode("abc.chonk.xyz")));

//
await hijackRegistryOwner(foundry, "a.b.c");
await foundry.confirm(
	BasenameResolver.setNode(namehash("a.b.c"), namehash("chonker.base.eth"))
);
console.log();
console.log(namehash("abc.sub.chonker.base.eth"));
console.log(await BasenameResolver.getNode(dnsEncode("abc.sub.a.b.c")));

await foundry.shutdown();

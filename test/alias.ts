import { Foundry } from "@adraffy/blocksmith";
import { dnsEncode, namehash } from "ethers/hash";
import {
	ENS_REGISTRY,
	NAME_WRAPPER,
	BASE_VERIFIER,
	BASE_L2_RESOLVER,
	MAINNET_PROVIDER_URL,
} from "./constants.js";

const foundry = await Foundry.launch({
	fork: MAINNET_PROVIDER_URL,
	infoLog: false,
});

const BasenameResolver = await foundry.deploy({
	file: "BasenameResolver",
	args: [ENS_REGISTRY, NAME_WRAPPER, BASE_VERIFIER, [], BASE_L2_RESOLVER],
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
await foundry.overrideENS({
	name: "chonk.xyz",
	owner: foundry.wallets.admin.address,
	resolver: null,
});
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
await foundry.overrideENS({
	name: "a.b.c",
	owner: foundry.wallets.admin.address,
	resolver: null,
});
await foundry.confirm(
	BasenameResolver.setNode(namehash("a.b.c"), namehash("chonker.base.eth"))
);
console.log();
console.log(namehash("abc.sub.chonker.base.eth"));
console.log(await BasenameResolver.getNode(dnsEncode("abc.sub.a.b.c")));

await foundry.shutdown();

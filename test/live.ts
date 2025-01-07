import { Foundry } from "@adraffy/blocksmith";
import { EnsResolver } from "ethers/providers";
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

const name = "adraffy.eth";
const resolver = new EnsResolver(
	foundry.provider,
	BasenameResolver.target,
	name
);

console.log(await resolver.getAddress());
console.log(await resolver.getText("avatar"));
console.log(await resolver.getContentHash());

await foundry.shutdown();

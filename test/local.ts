import { Foundry } from "@adraffy/blocksmith";
import { serve } from "@resolverworks/ezccip/serve";
import { EthSelfRollup, Gateway } from "@unruggable/gateways";
import { EnsResolver } from "ethers/providers";

const foundry = await Foundry.launch({
	fork: "https://mainnet.base.org",
	infoLog: true,
});

// setup gateway
const gateway = new Gateway(new EthSelfRollup(foundry.provider));
const ccip = await serve(gateway, { protocol: "raw", log: true });

// deploy local verifier
function getArtifactPath(name: string) {
	return `node_modules/@unruggable/gateways/artifacts/${name}.sol/${name}.json`;
}
const GatewayVM = await foundry.deploy({
	file: getArtifactPath("GatewayVM"),
});
const EthVerifierHooks = await foundry.deploy({
	file: getArtifactPath("EthVerifierHooks"),
});
const SelfVerifier = await foundry.deploy({
	file: getArtifactPath("SelfVerifier"),
	args: [[ccip.endpoint], 1000, EthVerifierHooks],
	libs: { GatewayVM },
});

const BasenameResolver = await foundry.deploy({
	file: "BasenameResolver",
	args: [
		SelfVerifier,
		// https://basescan.org/address/0xc6d566a56a1aff6508b41f6c90ff131615583bcd#code
		"0xc6d566a56a1aff6508b41f6c90ff131615583bcd",
	],
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
await ccip.shutdown();

import { Foundry } from "@adraffy/blocksmith";
import { serve } from "@resolverworks/ezccip/serve";
import { EthSelfRollup, Gateway } from "@unruggable/gateways";
import { EnsResolver } from "ethers/providers";
import { BASE_L2_RESOLVER, MAINNET_PROVIDER_URL } from "./constants.js";
import { ZeroAddress } from "ethers";

const foundry = await Foundry.launch({
	fork: MAINNET_PROVIDER_URL,
	infoLog: false,
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
	args: [ZeroAddress, ZeroAddress, SelfVerifier, [], BASE_L2_RESOLVER],
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

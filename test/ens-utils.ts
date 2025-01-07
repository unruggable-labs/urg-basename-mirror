import { Foundry } from "@adraffy/blocksmith";
import { ENS_REGISTRY } from "./constants.js";
import { namehash, solidityPackedKeccak256 } from "ethers/hash";

// override registry.records[node].owner
export async function hijackRegistryOwner(
	foundry: Foundry,
	name: string,
	owner: string = foundry.wallets.admin.address
) {
	await foundry.setStorageValue(
		ENS_REGISTRY,
		BigInt(
			solidityPackedKeccak256(
				["bytes32", "uint256"],
				[namehash(name), 0n]
			)
		),
		owner
	);
}

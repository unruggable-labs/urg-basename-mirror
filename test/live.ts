import { Foundry } from '@adraffy/blocksmith';
import { EnsResolver } from 'ethers/providers';

const foundry = await Foundry.launch({
  fork: 'https://rpc.ankr.com/eth',
  infoLog: false,
});

const BasenameResolver = await foundry.deploy({
  file: 'BasenameResolver',
  args: [
	// https://gateway-docs.unruggable.com/verifiers/deployments
    '0x82304C5f4A08cfA38542664C5B78e1969cA49Cec',
	// https://basescan.org/address/0xc6d566a56a1aff6508b41f6c90ff131615583bcd#code
    '0xc6d566a56a1aff6508b41f6c90ff131615583bcd',
  ],
});

const name = 'adraffy.eth';
const resolver = new EnsResolver(
  foundry.provider,
  BasenameResolver.target,
  name
);

console.log(await resolver.getAddress());
console.log(await resolver.getText('avatar'));
console.log(await resolver.getContentHash());

await foundry.shutdown();

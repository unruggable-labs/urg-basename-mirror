# urg-basename-mirror

Creates redirection from ENS name `name.eth` &rarr;  `name.base.eth`
* Supports subdomains
	* eg. `abc.name.eth` &rarr; `abc.name.base.eth`
* Supports arbitrary basenames with `setNode()`
	* eg. `abc.chonk.xyz` &rarr; `abc.chonker.base.eth`

#### Deployments
1. [`mainnet:0xd2399688478bf8b0587e4b3166E4C0Fd29A1c171`](https://etherscan.io/address/0xd2399688478bf8b0587e4b3166e4c0fd29a1c171#code)
2. [`mainnet:0x3722662D8AaB07B216B14C02eF0ee940d14A4200`](https://etherscan.io/address/0x3722662D8AaB07B216B14C02eF0ee940d14A4200#code)
3. [`mainnet:0x07b725d315a0d19c97A25127Bd4c103D1f7BbF56` (based on 17599cb)](https://etherscan.io/address/0x07b725d315a0d19c97A25127Bd4c103D1f7BbF56#code) ( slightly modified for self-hosted unchecked verifier used by tornadowithdraw.eth )

#### Examples

* [tornadowithdraw.**eth**](https://app.ens.domains/tornadowithdraw.eth) &rarr; [tornadowithdraw.**base.eth**](https://app.ens.domains/tornadowithdraw.base.eth)

### Setup

1. `bun i`
1. `forge i`

### Test

* `bun test/live.ts` — [Unruggable verifier](https://gateway-docs.unruggable.com/verifiers/deployments)
* `bun test/local.ts` — locally-deployed verifier
* `bun test/alias.ts` — verify node-translation logic
* `bun test-forge` — run foundry tests

### Todo

* Actual tests
* Considering moving `_aliases` to L2?

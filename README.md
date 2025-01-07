# urg-basename-mirror

Creates redirection from ENS name `yourname.eth` to `yourname.base.eth`

#### Live resolver: [0x3722662D8AaB07B216B14C02eF0ee940d14A4200](https://etherscan.io/address/0x3722662D8AaB07B216B14C02eF0ee940d14A4200#code)

#### How to apply:

Make sure you have registered `yourname.eth` on Ethereum L1 and `yourname.base.eth` on Base L2.

Click `More` tab on https://app.ens.domains/ and click `Edit` button on `Resolver` card.

Update Resolver to the live mirror resolver deployed on Ethereum L1 and start updating info on Base L2.

Updated info on Base would be reflected for your L1 name after some period ( would take about 1 ~ 2 hours ).

#### Example: 

https://app.ens.domains/tornadowithdraw.eth -> https://app.ens.domains/tornadowithdraw.base.eth

1. `bun i`
1. `bun test/live.ts` — uses deployed Unruggable verifier
1. `bun test/local.ts` — uses locally-deployed verifier

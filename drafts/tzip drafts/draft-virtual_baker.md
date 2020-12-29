---
title: Virtual Baker
status: draft
author: Sophia Gold <sophia.gold@tqtezos.com>
type: protocol
date: 2020-12-28
version: 0
---

## Summary

The virtual baker is a contract that holds deposits from other contracts and whose balance is automatically inflated by the protocol at a level roughly comparable with baking rewards.

## Abstract

Many popular uses of Tezos require locking tez inside of a contact, e.g. DeFi applications (e.g. Dexter or Quipuswap) or shielded pools using Sapling. To avoid dilution by inflation, such contracts can choose to delegate this locked tez to a single baker, allow users of the contract to vote on its baker, or forego baking rewards entirely (creating a large opportunity cost). The first two cases may eventually pose centralization or security risks to the network, as some such contracts may grow to represent a large percentage of the stake.

Users of Tezos currently face competing incentives between baking or delegating and any application that requires locking tez in a contract, e.g. DeFi applications like Dexter and QuipiSwap or shielded transactions using Sapling. Users of such contracts are paying an inflationary penalty by not being able to bake or delegate and in the case of DeFi liquidity providers this partially offsets the fees they earn. 

We propose one canonical solution for this issue: a single "virtual baker" contract whose balance is automatically inflated by the protocol. Contracts can choose to deposit funds into the virtual baker and receive a ticket for the corresponding amount of tez, minus a fee equivalent to one cycle's rewards in order to prevent manipulation. They can then redeem these tickets for the same amount of tez plus an amount designed to be equivalent to the rewards they would have been paid by a delegate. The virtual baker's inflation is calculated using a bonding curve that decreases as it represents a greater amount of outstanding tez in order to avoid undercutting delegates.

Virtual baking tickets can also be used as the basis for staking derivatives similar to those seen in other proof-of-stake networks such as Cosmos and Polkadot.

The primary goal of adding a virtual baker is to incentivize DeFi applications on Tezos by providing a financially tangible advantage over both proof-of-work and other proof-of-stake networks. It also would demonstrate how the formal amendment process can be used to set inflationary policy, something only Tezos can credibly do.

## Specification

The operation hash of the virtual baker contract is stored in constants. Every snapshot block, this contract is credited `(1-x)^4 * y` tez, where x is the percentage of outstanding tez in the virtual baker and y is the amount of rewards paid out in the given cycle.

The virtual baker contract stores a `nat` equal to the total amount deposited. One can think about this as the outstanding amount of "ctez", a currency backed by tez deposited in the virtual baker. To calculate the tez/ctez and ctez/tez exchange rates, the virtual baker either divides its storage by its balance or vice-versa.

The virtual baker contract has two entrypoints:
- `%deposit` takes type `contract` and returns type `ticket unit`. It generates a ticket with the amount it's called with, subtracting 0.04%, and applying the tez/ctez exchange rate (e.g. `9087` if called with `10000 mutez`, storage of `100000` a current balance of `110000 mutez`), and transfers it to the contract in the parameter.
- `%redeem` takes type `(pair (ticket unit) (contract unit))`. It checks the ticket and, if valid, applies the ctez/tez exchange rate and transfers the given amount of tez to the contract in the parameter (e.g. redeeming a ticket with a value of `1000 mutez` results in a transfer of `1100 mutez` if storage is `100000` and current balance is `110000 mutez`).

## Rationale

Numerous alternate designs were considered before deciding on this one. Some of these include:

- __Voting/auction for delegates__: We first considered contract-level solutions. A contract could have its users vote on a delegate, run an auction based on rewards payouts, or participate in a centralized auction contract. Voting requires a governance token not all contracts may have (and is infeasible for shielded transaction contracts) and would require fees or time locks to prevent manipulation by large bakers using sudden deposits and withdrawal. Auctions could also be manipulated by charging zero or even negative fees for the purpose of capturing voting rights. Additionally, contract balances may be too large to find a delegate (or at least a competitive one) since they cannot currently split their stake between multiple bakers. Finally, we may take it as a general principle that the burden of implementation should be placed on protocol rather than contract developers. This, in addition to the ability to sidestep the aforementioned security problems, leads us to a protocol-level solution.

- __Delegate vs. deposit-based__: User contracts could set their delegate to a special address and have their own balances inflated directly. This has the advantage of backwards compatibility, e.g. it could be used by the current version of Dexter. However, some contracts may not want to have their balances increase without being called and it's easy to imagine accounting functionality breaking due to this. This sways us towards the current deposit-based approach. A deposit-based approach also has the advantage of providing the basis for staking derivatives.

- __Tickets vs. tokens__: The virtual baker contract could issue FA2 tokens instead of tickets. This has the disadvantage of increased network congestion. It also could be argued that in principle we should not make protocol-level features rely on off-chaininformal standards. Advantages of a virtual baker token, e.g. divisibility and compatibility with DEXes and wallets, can be obtained by simply building it on top of the ticket-based approach using an additional contract.

- __Lock vs. delay vs. fee__: Users must not be able to game the virtual baker by depositing immediately before the snapshot block and withdrawing immediately after, thus capturing a full cycle's worth of inflation without locking their tez (and possibly still capturing rewards from delegating). Snapshots are nonuniform, but not strongly random, so this could be done with relative ease. In this proposal, the virtual baker charges a fee of 0.04% on deposit. Alternatively, it could lock tez in the contract for one cycle after deposit or delay redemption of the inflated value for one cycle. Both of these approaches are financially equivalent to charging a fee of one cycle's rewards yet are considerably more complicated to implement.

- __Fixed vs. floating rate__: This proposal increases the overall inflation of the currency by adding the virtual baker inflation on top of existing baking rewards. We call this a _floating rate_ since it varies with the amount deposited in the virtual baker contract. The other option would be to lower baking rewards in accordance with the amount credited to the virtual baker. We call this a _fixed rate_ since the amount of inflation of the currency would remain constant. There’s currently a meme that tez holders are being paid a "dividend" for baking or delegating. This is not actually accurate -- bakers or delegators are really just spared inflation by helping secure the network, an option not available on proof-of-work networks. Some would argue Tezos would benefit from switching to a "store of value" meme, like Bitcoin, that emphasizes maintaining the lowest possible level of total inflation regardless of lower baking rewards. [Here](http://ex.rs/on-supply-caps/) is a deeper overview of this distinction from a proponent of the "store of value" meme. The current floating rate proposal preserves the "dividend" meme at the expense of the "store of value" meme. We could easily switch to a fixed rate, which would simply require inflating the virtual baker on every block in order to calculate total baking rewards (see the next point).

- __Payout time__: The virtual baker balance could be inflated on every block, but this is unnecessary when using a floating rate and would very slightly increase the computational overhead for nodes. Alternatively, it could be inflated every cycle, but this would add a slight degree of code complexity in order to store the balance from the last snapshot block. We propose to inflate the virtual baker on snapshot blocks because this is when rolls are counted to calculate baking rewards.

- __Alternate bonding curves__: With the proposed curve the virtual baker would receive 81% of baking rewards if it holds 5% of the outstanding tez, 66% with 10%, 41% with 20%, and 24% with 30%. One could argue it should be steeper. Additionally, the proposed curve would not be so attractive if Tezos were to have as much of the currency locked in DeFi as Ethereum currently does (~16.5% at time of writing, recently as high as 25%). Luckily this is something that can be easily changed in future amendments.

- __Inflating specific DeFi contracts__: The virtual baker removes most of the inflationary penalty for locking tez in DeFi or shielded transactions, but it does not provide a positive incentive to do so. Another option is to inflate specific contracts, e.g. an XTZ/BTC pair on a DEX as proposed [here](https://forum.tezosagora.org/t/liquidity-mining-on-tezos/2529) in order to incentivize new tez holders. This would not conflict with the virtual baker, but seems worth mentioning as a related concept. Much of the same code can be reused.

## Backwards Compatibility

Existing contracts must be updated to make use of the virtual baker. However, the economics of virtual baker inflation can easily be refined in future amendments without breaking contracts that use it.

## Test Cases

It can currently be tested manually in a sandbox by building from the branch below. The virtual baker contract is included in the genesis block and the operation hash is forced to match that included in constants. A [testing contract](https://gitlab.com/sophiagold/tezos/-/blob/sophia/vbaker/src/proto_alpha/lib_protocol/test/contracts/vbakee.tz) is included with entrypoints to trigger deposits and withdrawal (with the virtual baker address hardcoded) and storage for one ticket.

Automated tests demonstrating inflation meets the specification are to come.

## Implementations

[Protocol upgrade](https://gitlab.com/sophiagold/tezos/-/tree/sophia/vbaker)

[Virtual baker contract](https://gitlab.com/sophiagold/tezos/-/blob/sophia/vbaker/src/proto_alpha/lib_protocol/test/contracts/vbaker.tz)

## Appendix

[Delegation Markets](https://forum.tezosagora.org/t/delegation-markets/1304)

[On the Tezos delegation model](https://forum.tezosagora.org/t/on-the-tezos-delegation-model/1562)

[Virtual Baker](https://forum.tezosagora.org/t/virtual-baker/1793)

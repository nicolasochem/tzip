---
title: Liquidity baking
status: Draft
author: Gabriel Alfour, Sophia Gold, Arthur Breitman, et al.
type: Protocol
created: 2021-01-05
date: 2021-01-05
version: 1
---

## Summary

We propose incentivizing large amounts of decentralized liquidity provision between tez and tzBTC by minting a small amount of tez every block and depositing it inside of a constant product market making smart-contract. We also provide an escape hatch mechanism as a contingency.

## Motivation

Liquidity is a key component of a good store of value, and money is even sometimes defined as the most liquid means of exchange. Despite its widespread availability tez remains, to this day, one of the least liquid of the major cryptocurrencies.

The Tezos position paper mentions in section 4.3 that the governance model of Tezos can be used to solve collective action problems:

> The collective action problem arises when multiple parties would benefit from taking an action but none benefit from individually undertaking the action.

Liquidity provision is among the most important public goods of a currency and a perfect example of a collective action problem that can be solved by governance.

This represents a minimal amount of development effort, provides an important public good to the Tezos ecosystem, and directly demonstrates the power of decentralized on-chain governance.


## Specification

### Contract

A constant product market making (CPMM) Michelson contract is first deployed on the chain. This contract maintains a balance of `a` tez and `b` tzBTC, where tzBTC is the FA1.2 token found at address KT1PWx2mnDueood7fEmfbBDKx1D9BAnnXitn. The smart contract accepts deposits of `da` tez and returns `db` tzBTC (or vice versa) where the invariant `(a + da * (1 - f)) * (b - db) = a b` is preserved, and `f` is a fee, set at 0.1%.

To implement this contract, we use a fork of the open source code base used by the "Dexter" project. The implementation of this contract has been [formally verified](https://blog.nomadic-labs.com/dexter-decentralized-exchange-for-tezos-formal-verification-work-by-nomadic-labs.html) against its functional specification. The contract code is modified in the following way:

1. The fee is set to 0.1% only. Rationale: given the subsidy it is not necessary to charge a large fee and better to improve liquidity.
2. The ability to set a manager has been removed.
3. The ability to set a delegate and receive rewards has been removed. Rationale: the subsidy means there is no need for a baker for that contract and having one would create an imbalance.

### Subsidy

At every block in the chain, 5 tez are minted and credited to the CPMM contract, and the CPMM's `%default` entrypoint is called to update the `xtz_pool` balance in its storage. This corresponds to 1/16th of 80 tez which is the typical block reward and endorsement reward for a block of priority 0 with all endorsements. If for any reason this constant changes, the amount of 5 tez should also be changed adequately.

So the credits to the CPMM contract can be accounted for by indexers, they are included in block metadata as a balance update of a new type, `Misc`, that can also be used for things such as invoices for protocol upgrades.

As a safety precaution, the subsidy expires automatically after 6 months but it can be renewed periodically by protocol amendment.

### Escape hatch

In addition to the 6 months sunset, an escape hatch is included. At every block, a baker can choose to include a flag that requests ending the subsidy. The context maintains an exponential moving average of that flag calculated as such with integer arithmetic:

`e[0] = 0`
`e[n+1] = (999 * e[n] // 1000) + (1000 if flag[n] else 0)`

If at any block `e[n] >= 500000` then it means that an exponential moving average with a window size on the order of one thousand blocks has had roughly a majority of blocks demanding the end of the subsidy. If that is the case, the subsidy is permanently halted (though it can be reactivated by a protocol upgrade).

For indicative purposes, if a fraction `f` of blocks start signalling the flag, the threshold is reached after roughly `log(1-1/(2f)) / log(0.999)` blocks, about 693 blocks if everyone signals, 980 blocks if 80% do, 1790 blocks if 60% do, etc.

## Rationale


### Michelson based CPMM

The CPMM could be implemented at the protocol level with new operations being made available to interact with it. However, it is much simpler to deploy existing audited and formally verified Michelson code to do the task. If performance is an issue, the CPMM can be moved to the protocol level in a later upgrade.

### tzBTC

Bitcoin is itself extremely liquid and thus liquidity of tez in bitcoin can translate into liquidity into any other instruments for which bitcoins can be exchanged. The value of tez expressed in bitcoin has also been historically less volatile than when expressed in other currencies, making liquidity provision cheaper.

### Sunset and escape hatch

The sunset mechanism and escape hatch are simply to implement security measures which can help deactivate the feature should anything go wrong.

### Subsidy vs baking

The idea is that instead of being able to delegate, the contract receives a fixed subsidy per block. Assuming as a first approximation that participants in the CPMM liquidity pool are neutral with respect to the cost of holding liquidity pool capital, the impermanent loss, and the swapping fees they collect, then the subsidy should attract tez away from delegation and towards the CPMM contract. This happens until the balance of tez held in the CPMM contract and the balance of all delegated or baking tez are in the same proportion as the subsidy and the total reward in the block for bakers and endorsers. This means that the liquidity in the pool should far exceed the amount of the subsidy that goes in.

Since this reduces the amount of delegated tez without decreasing block rewards paid to bakers and endorsers, the economic effect is a 1/16th increase in the baking reward collected by bakers, since they end up producing slightly more blocks, but they may need to also slightly increase their security deposit (by 1/16th).

Given that the security deposit requirements have not been adjusted upwards since the launch of the chain, this is a useful adjustment.

Instead of adding a subsidy, the subsidy could be taken from the existing reward by rescaling the block reward and endorsement reward. However, adding a reward is easier to explain, means less integration work for block explorers, and does not create pressure for bakers to adjust how they split the block rewards between themselves and delegates. It also makes the safety hatch and sunset provision easier to implement because there is no need to readjust block rewards 

## Backwards Compatibility

Block explorers will need to support the new `Misc` balance update type in order to reconcile the balance of the CPMM contract.

## Security consideration

The risk to the chain itself is bounded by the cost of the subsidy itself, which can be cut off quickly if there is any reason to do so. However, it's also worthwhile to examine security considerations around the use of the mechanism itself.

The three main security risks we identify are as follows. They only affect those who chose to provide liquidity in the CPMM..

1. While the codebase the CPMM is forked from has been [audited](https://github.com/trailofbits/publications/blob/master/reviews/dexter.pdf) and its [functional specification](https://gitlab.com/nomadic-labs/mi-cho-coq/-/merge_requests/71) formally verified, a new round of review and testing would be worthwhile.
2. Although the tzBTC contract has already been [audited once](https://leastauthority.com/static/publications/LeastAuthority-Tezos-TzBTC-Final-Audit-Report.pdf) by Least Authority, another review of the contract is worthwhile.
3. tzBTC, while controlled by multiple reputable institutions via a multisignature is not trustless, therefore the mechanism depends on the continuing availability of tzBTC portals. We note that large amounts of liquidity exist for the similar WBTC contract on Uniswap (an Ethereum-based CPMM).

## Implementations

[Protocol upgrade](https://gitlab.com/sophiagold/tezos/-/tree/liquidity_baking)

[CPMM contract](https://gitlab.com/sophiagold/tezos/-/blob/a169b7cd32167327405926cb8b167513cfe9db36/src/proto_alpha/lib_protocol/test/contracts/cpmm.tz)

## Copyright 

Copyright and related rights waived via CC0.

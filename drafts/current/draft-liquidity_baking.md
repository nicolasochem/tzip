---
title: Liquidity baking
status: Draft
author: Gabriel Alfour, Sophia Gold, Arthur Breitman, et al.
type: Protocol
created: 2021-01-05
date: 2021-03-30
version: 2
---

## Summary

We propose incentivizing large amounts of decentralized liquidity provision between tez and tzBTC by minting a small amount of tez every block and depositing it inside of a constant product market making smart-contract. We also provide an escape hatch mechanism as a contingency.

## Motivation

Liquidity is a key component of a good store of value, and money is even sometimes defined as the most liquid means of exchange. Despite its widespread availability tez remains, to this day, one of the least liquid of the major cryptocurrencies.

The Tezos position paper mentions in section 4.3 that the governance model of Tezos can be used to solve collective action problems:

> The collective action problem arises when multiple parties would benefit from taking an action but none benefit from individually undertaking the action.

Liquidity provision is among the most important public goods of a currency and a perfect example of a collective action problem that can be solved by governance.

This provides an important public good to the Tezos ecosystem and directly demonstrates the power of decentralized on-chain governance.


## Specification

### Contract

A constant product market making (CPMM) Michelson contract is first deployed on the chain. This contract maintains a balance of `a` tez and `b` tzBTC, where tzBTC is the FA1.2 token found at address KT1PWx2mnDueood7fEmfbBDKx1D9BAnnXitn. The smart contract accepts deposits of `da` tez and returns `db` tzBTC (or vice versa) where the invariant `(a + da * (1 - f - n)) * (b - db) = a b` is preserved, and `f` and `n` are a fee and burn, set at 0.1% each.

To implement this contract, we use a fork of the open source code base used by [version two](https://gitlab.com/dexter2tz/dexter2tz) of the "Dexter" project. The implementation of this contract has been [formally verified](https://gitlab.com/dexter2tz/dexter2tz/-/blob/master/dexter_spec.v) against its functional specification. The contract code is modified in the following way:

1. The fee is set to 0.1% only. Rationale: given the subsidy it is not necessary to charge a large fee and better to improve liquidity.
2. An additional 0.1% of every trade is burned by being transferred to the null implicit account. __With 7.2mm daily tez volume this will offset all inflation from the subsidy.__
3. The ability to set a manager has been removed.
4. The ability to set a delegate and receive rewards has been removed. Rationale: the subsidy means there is no need for a baker for that contract and having one would create an imbalance.

### Subsidy

At every block in the chain, 5 tez are minted and credited to the CPMM contract, and the CPMM's `%default` entrypoint is called to update the `xtz_pool` balance in its storage. This corresponds to 1/16th of 80 tez which is the typical block reward and endorsement reward for a block of priority 0 with all endorsements. If for any reason this constant changes, the amount of 5 tez should also be changed adequately.

So the credits to the CPMM contract can be accounted for by indexers, they are included in block metadata as a balance update with a new update origin constructor, `Subsidy`.

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

Instead of adding a subsidy, the subsidy could be taken from the existing reward by rescaling the block reward and endorsement reward. However, adding a reward is easier to explain, means less integration work for block explorers, and does not create pressure for bakers to adjust how they split the block rewards between themselves and delegates. It also makes the safety hatch and sunset provision easier to implement because there is no need to readjust block rewards 

## Backwards Compatibility

Block explorers will need to support the new `Subsidy` update origin type constructor in order to reconcile the balance of the CPMM contract.

## Security consideration

The risk to the chain itself is bounded by the cost of the subsidy itself, which can be cut off quickly if there is any reason to do so. However, it's also worthwhile to examine security considerations around the use of the mechanism itself.

The three main security risks we identify are as follows. They only affect those who chose to provide liquidity in the CPMM..

1. While the codebase the CPMM is forked from has been formally verified against its [functional specification](https://gitlab.com/dexter2tz/dexter2tz/-/blob/master/dexter_spec.v) and is currently being audited by Least Authority, a [vulnerability](https://blog.nomadic-labs.com/a-technical-description-of-the-dexter-flaw.html) was discovered in the previous version. The new version is a complete rewrite and we are confident that the increased attention from its use in liquidity baking will harden its security, noting that this is partly what led to the discovery of the vulnerability in the previous version.
2. Although the tzBTC contract has already been [audited once](https://leastauthority.com/static/publications/LeastAuthority-Tezos-TzBTC-Final-Audit-Report.pdf) by Least Authority, another review of the contract is worthwhile.
3. tzBTC, while controlled by multiple reputable institutions via a multisignature is not trustless, therefore the mechanism depends on the continuing availability of tzBTC portals. We note that large amounts of liquidity exist for the similar WBTC contract on Uniswap (an Ethereum-based CPMM).

## Implementations

[Merge request](https://gitlab.com/tezos/tezos/-/merge_requests/2765)

[CPMM contract](https://gitlab.com/dexter2tz/dexter2tz/-/tree/liquidity_baking)

## Copyright 

Copyright and related rights waived via CC0.

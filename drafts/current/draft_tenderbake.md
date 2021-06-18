---
title: Deterministic Finality with Tenderbake
status: Draft
author: Nomadic Labs
type:
created: 2021-03-09
date: 2021-06-15
version: 2
---

# Deterministic Finality with Tenderbake

## Summary

This TZIP proposes [Tenderbake](https://arxiv.org/abs/2001.11965) as a replacement of Emmy<sup>+</sup> (or Emmy<sup>&#9733;</sup>) in order to provide deterministic finality.

## Abstract

The current consensus algorithm in Tezos, Emmy<sup>+</sup> offers *probabilistic* finality: like in any Nakamoto-style consensus algorithm, in Emmy<sup>+</sup>, forks of arbitrary length are possible but they collapse with a probability that increases rapidly with fork length.

[Tenderbake](https://arxiv.org/abs/2001.11965) instead, like any classic BFT-style consensus algorithm (such as PBFT or Tendermint), offers *deterministic* finality: a block that has just been appended to the chain of some node is known to be final once it has two additional blocks on top of it, regardless of network latency.

## Specification

The starting point for Tenderbake is [Tendermint](https://arxiv.org/abs/1807.04938), the first BFT-style  algorithm for blockchains.

Tenderbake adapts Tendermint to the Tezos blockchain, but the adjustments required are [substantive](https://blog.nomadic-labs.com/a-look-ahead-to-tenderbake.html#the-tezos-architecture):

- Tenderbake is tailored to match the Tezos architecture by using only communication primitives and network assumptions which Tezos supports.
- Tenderbake makes weaker network assumptions than Tendermint, at the price of adding the extra assumption that participants have loosely synchronized clocks — which is fine, because Tezos already uses them.

The design and the rationale behind the design of Tenderbake are described at length in the [technical report](https://arxiv.org/abs/2001.11965) and in a [Nomadic Labs's blog post](https://blog.nomadic-labs.com/a-look-ahead-to-tenderbake.html). Here we only give a description of changes relevant from a user/developer perspective.

Tenderbake is executed for each new block level by a "committee" whose members are called *validators*, which are delegates selected at random based on their stake, in the same way as endorsers are selected in Emmy<sup>+</sup>. We let `consensus_committee_size` be the number of validator slots per level. This constant has the role of `endorsers_per_block` in Emmy<sup>+</sup>; its concrete value will be decided later, however it will be significantly higher than the current value 32, ideally 8000.

For each level, Tenderbake proceeds in rounds. Each *round* represents an attempt by the validators to agree on the content of the block for the current level, that is, on the sequence of non-consensus operations the block contains.

Each round has an associated duration. Round durations are set to increase so that for any possible message delay, there is a round that is sufficiently long for all required messages to be exchanged.

During a round, the validators’ task is to agree on which block to add next. Schematically, this process is:

- a validator injects a *candidate block* (representing a proposal) and consensus operations (representing votes) into the node to which it is attached, which then
- diffuses those blocks and consensus operations to other nodes of the network, and thus
- communicates them to the validators attached to those nodes, to carry out voting on which block to accept.

Unlike Emmy<sup>+</sup>, Tenderbake has [two types of votes](https://blog.nomadic-labs.com/a-look-ahead-to-tenderbake.html#why-do-we-need-preendorsements): before endorsing a block `b`, a validator preendorses `b`. Furthermore, endorsing is conditioned by having observed a preendorsement *quorum*, that is a set of preendorsements from validators having at least `ceil(2 * consensus_committee_size / 3)` validator slots. Similarly, deciding on the content of `b` is conditioned by having observed an endorsement quorum. The endorsement quorum for a block `b` is included in a block on top of `b` in order to serve as a certification for `b`.

The validator's whose turn is to inject a candidate block at a given round is called the *proposer* at that round. Proposers in Tenderbake are selected similarly as bakers in Emmy<sup>+</sup>: the proposer at round `r` is the validator who has the validator slot `r`.
A proposer who has observed a preendorsement quorum for a candidate block, is required to propose a block with the same *payload* (that is, the same sequence of non-consensus operations) as the initial block. We talk about a *re-proposal* in this case.
 
### Transaction and block finality

A transaction is final as soon as the block including it has a confirmation. Indeed, as hinted above, a block contains the endorsement quorum on the previous block contents. Thanks to the endorsement quorum, we have **transaction finality after 1 confirmation**.

It may be possible that different validators decide at different rounds with block proposals having the same content. And because a block headers contains the round at which the block was proposed, Tenderbake needs one more confirmation so that agreement on the whole block is reached. Thus we have **block finality after 2 confirmations**.

### Block times

Block times will depend on the round at which the first decision is taken. For example, if durations of the first 3 rounds are 30s, 60s, and 120s respectively, and the decision is taken at round 3, then the block time, relative to the previous block, is 3m30s. However, under normal network conditions, and with active and compliant validators, decisions should be taken at round 0, meaning that blocks time would be 30 seconds in this example.

Round durations will be set based on outcome from performance evaluations and from testnets.

### Validator selection and activity monitoring

In contrast to Emmy<sup>+</sup>, where baking and endorsing rights are computed in one go, 5 cycles in advance, in Tenderbake validators are selected in two steps. 

1. The first step is the same as the endorsers' selection in Emmy<sup>+</sup>, and it is a pre-selection step: in this step we only select potential validators. 
2. In a second step, performed 5 levels in advance, given by a `validators_selection_offset` parameter, we select among the potential validators those that have enough tokens to place the security deposit. 

This mechanism is necessary in order to prevent the situation where too few validators have enough stake to participate in consensus when their turn comes. Note in particular that the security deposit is placed even if the delegate does not actually participate in consensus. (See below for the value of the security deposit.)

As in Emmy<sup>+</sup>, validators are pre-selected among the *active* delegates, those who have baked or endorsed at least once in the past 5 cycles.

### Incentives mechanism

As in Emmy<sup>+</sup>, we reward participation in consensus and punish bad behavior. Notable changes however are as follows:

- Fees and baking rewards go to the payload proposer, the one who selects the transactions to be included in the block. In some cases, this validator might be different from block proposer, the baker who injects the block.
- Including extra endorsements, that is, more than the minimal required to obtain a quorum, is rewarded with a bonus.
- Endorsing rewards are shared equally among all validators. Participation above a minimal threshold per cycle is however required.
- As the selection of validators in Tenderbake is done on a level basis, modifications were made to the balance unfreeze mechanism. In particular, validators are rewarded instantaneously for baking blocks and including extra endorsements, and not at the end of the cycle like in Emmy<sup>+</sup>. Similarly, the deposits are unfrozen after a delay expressed in levels, and not necessarily at the end of a cycle. Only the rewards for endorsing are unfrozen at the end of a cycle. 


#### Fees

The fees associated to the transactions included in a block go to the
payload proposer. This is only natural given that this is the
validator that selects the transactions to be included; see [an
in-depth blog post](https://ex.rs/protocol-level-fees/) for further
motivation. 

The payload proposer is usually the same delegate as the block
proposer (that is, the one that signs and injects the block): that's
always true for blocks at round 0; however, in case of re-proposals
this is not the case (see the algorithm description above).

Fees are given to the payload proposer immediately, that is, they are
already reflected in the blockchain state obtained after applying the injected
block.


#### Deposits

At each level `l`, for each active delegate a security deposit is placed for being a validator at level `l + validators_selection_offset`. More precisely, validators for level `l + validators_selection_offset` are chosen among the delegates that own enough tokens to place a deposit for at least one validator slot at level `l`. The number of slots of a delegate is therefore the minimum between their number of endorsing slots (obtained in the pre-selection step) and the number of slots for which the delegate can place a deposit.

The value of the security deposit per slot is such that the total deposits per level equal the ones in Emmy<sup>+</sup>, per period of time (as is the case for the total rewards per level), namely `security_deposit_per_slot` is set to `2560 / (blocks_per_minute * consensus_committee_size)` tez. Indeed:

- In Emmy<sup>+</sup>, we have that the total deposits are `32 * 80 = 2560` tez per minute.
- In Tenderbake, we have that the total deposits per minute are `blocks_per_minute * security_deposit_per_slot * consensus_committee_size`.

Deposits for a level are unfrozen after `unfreeze_delay` levels, whose value is set to two cycles.

#### Rewards

There are three kinds of rewards: baking rewards, a bonus for including extra endorsements, and endorsing rewards.

The baking rewards are treated in the same way as fees: they go to the *payload* proposer and are distributed immediately.

To encourage fairness and participation, the *block* proposer receives
a bonus proportional to the number of extra endorsements it
includes. More precisely, the bonus is proportional to the number of
slots above the threshold of `ceil(2*consensus_committee_size/3)` that
the included endorsements represent. The bonus is also distributed
immediately.

The endorsing rewards are shared among all validators, proportionally
to their number of validator slots. The endorsing reward may be
received even if the validator's endorsement is not included in a
block. However, it is required a minimal presence per cycle.  More
precisely, we say that a delegate is *present* during a cycle if its
endorsements are included in at least `presence_levels_per_cycle`
blocks in a cycle. We set `presence_levels_per_cycle` to `1/4` of
`blocks_per_cycle`. The endorsing rewards are distributed at the end
of the cycle if the delegate was present. If the delegate was not
present, its rewards are burned.

Regarding the concrete values for rewards, we first fix the total reward per
level, call it `total_rewards_per_level`, to `80 / blocks_per_minute` tez. We
let:

- `baking_rewards := baking_reward_ratio * total_rewards`
- `bonus := (1-baking_reward_ratio) * bonus_ratio * total_rewards` is the max bonus; the bonus per additional endorsement slot is thus `bonus / (consensus_committee_size / 3)`
- `endorsing_rewards := (1-baking_reward_ratio) * (1-bonus_ratio) * total_rewards`; the rewards per endorsement slot are therefore `endorsing_rewards / consensus_committee_size`.

We set:

- `baking_reward_ratio` to `1 / 4`,
- `bonus_ratio` to `1 / 3`.

#### Slashing bad behavior

Like in Emmy<sup>+</sup>, double signing, that is, double baking or double (pre)endorsing (which means voting on two different proposals at the same round), is punished by slashing the security deposits. The slashed amount equals the security deposit at the level at which the double signing occurred.

We note that selfish baking is not an issue in Tenderbake: say we are at round `r` and the validator which is proposer at round `r+1` does not (pre)endorse at round `r` in the hope that the block at round `r` is not agreed upon and its turn comes to propose at round `r+1`. Under the assumption that the correct validators have more than two thirds of the total stake, these correct validators have sufficient power for agreement to be reached, thus the lack of participation of a selfish baker does not have an impact.



## Backwards Compatibility

As mentioned in the abstract, the main change in going from Emmy<sup>+</sup> to [Tenderbake](https://arxiv.org/abs/2001.11965) is going from probabilistic to deterministic finality, more precisely, to [finality in 2 blocks](#finality-in-two-blocks).
The remaining changes are as follows:
- the format of endorsements changes, in particular, an endorsement for block `b` includes the round at which `b` was proposed; a validator emits at most an endorsement per round, but can emit more endorsements per level; therefore, the current high-water mark mechanism used by the signer needs to be adapted;
- besides endorsing, there is a second type of consensus operation called preendorsement; similarly, besides `double_endorsement_evidence` there is the operation `double_preendorsement_evidence`;
- the block header changes to include a set of endorsements for the predecessor block to serve as a justification that the previous block has been agreed upon; the block header may also include in rare cases a set of preendorsements; the block header no longer contains the priority entry;
- the block fitness changes, mainly to allow block candidates to be accepted by nodes;
- the length of cycles and voting periods will be adjusted according to the block times so that the same time duration is kept;
- there is no longer a distinction between baking and endorsing rights: delegates are validators in Tenderbake; validator rights in Tenderbake are similar to endorsing rights in Emmy<sup>+</sup>;
- the implementation of a validator is the baker daemon and because a validator bakes, preendorses and endorses, the endorser daemon is removed.

## Security Considerations

[Tenderbake](https://arxiv.org/abs/2001.11965) is proved to satisfy the so-called agreement and progress properties under the standard assumptions for BFT-style algorithms, namely that the network is [partially synchronous](https://decentralizedthoughts.github.io/2019-06-01-2019-5-31-models/) and a Byzantine attacker has at most one third of the total active stake.

## Implementation

https://gitlab.com/tezos/tezos/-/merge_requests/2664

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).

---
title: Deterministic Finality with Tenderbake
status: Draft
author: Nomadic Labs
type:
created: 2021-03-09
date: 2021-08-27
version: 4
---

# Deterministic Finality with Tenderbake

## Summary

This TZIP proposes [Tenderbake](https://arxiv.org/abs/2001.11965) as a replacement of Emmy* in order to provide deterministic finality.

## Abstract

The current consensus algorithm in Tezos, Emmy* offers *probabilistic* finality: like in any Nakamoto-style consensus algorithm, in Emmy* forks of arbitrary length are possible but they collapse with a probability that increases rapidly with fork length.

[Tenderbake](https://arxiv.org/abs/2001.11965) instead, like any classic BFT-style consensus algorithm (such as PBFT or Tendermint), offers *deterministic* finality: a block that has just been appended to the chain of some node is known to be final once it has two additional blocks on top of it, regardless of network latency.

## Specification

The starting point for Tenderbake is [Tendermint](https://arxiv.org/abs/1807.04938), the first BFT-style  algorithm for blockchains.

Tenderbake adapts Tendermint to the Tezos blockchain, but the adjustments required are [substantive](https://blog.nomadic-labs.com/a-look-ahead-to-tenderbake.html#the-tezos-architecture):

- Tenderbake is tailored to match the Tezos architecture by using only communication primitives and network assumptions which Tezos supports.
- Tenderbake makes weaker network assumptions than Tendermint, at the price of adding the extra assumption that participants have loosely synchronized clocks — which is fine, because Tezos already uses them.

The design and the rationale behind the design of Tenderbake are described at length in the [technical report](https://arxiv.org/abs/2001.11965) and in a [Nomadic Labs's blog post](https://blog.nomadic-labs.com/a-look-ahead-to-tenderbake.html). Here we only give a description of changes relevant from a user/developer perspective.

Tenderbake is executed for each new block level by a "committee" whose members are called *validators*, which are delegates selected at random based on their stake, in the same way as endorsers are selected in Emmy*.
We let `consensus_committee_size` be the number of validator slots per level.
This constant has the role of `endorsers_per_block` in Emmy*; its concrete value will be decided later, however it will be significantly higher than the current value 256, ideally at least 7354.
(This value is obtained by computing the minimum number of slots such
that, under the assumption that 30% of all rolls are detained by a
Byzantine entity and there is a block every second, then the random
selection of `consensus_committee_size` rolls does not contain more
than one third Byzantine rolls more than once in 100 years on
average.)

For each level, Tenderbake proceeds in rounds. Each *round* represents an attempt by the validators to agree on the content of the block for the current level, that is, on the sequence of non-consensus operations the block contains.

Each round has an associated duration. Round durations are set to increase so that for any possible message delay, there is a round that is sufficiently long for all required messages to be exchanged.

During a round, the validators’ task is to agree on which block to add next. Schematically, this process is:

- a validator injects a *candidate block* (representing a proposal) and consensus operations (representing votes) into the node to which it is attached, which then
- diffuses those blocks and consensus operations to other nodes of the network, and thus
- communicates them to the validators attached to those nodes, to carry out voting on which block to accept.

Unlike Emmy*, Tenderbake has [two types of votes](https://blog.nomadic-labs.com/a-look-ahead-to-tenderbake.html#why-do-we-need-preendorsements): before endorsing a block `b`, a validator preendorses `b`. Furthermore, endorsing is conditioned by having observed a preendorsement *quorum*, that is a set of preendorsements from validators having at least `ceil(2 * consensus_committee_size / 3)` validator slots. Similarly, deciding on the content of `b` is conditioned by having observed an endorsement quorum. The endorsement quorum for a block `b` is included in a block on top of `b` in order to serve as a certification for `b`.

The validator whose turn is to inject a candidate block at a given round is called the *proposer* at that round. Proposers in Tenderbake are selected similarly as bakers in Emmy*: the proposer at round `r` is the validator who has the validator slot `r`.
A proposer who has observed a preendorsement quorum for a candidate block, is required to propose a block with the same *payload* (that is, the same sequence of non-consensus operations) as the initial block. We talk about a *re-proposal* in this case.

### Transaction and block finality

A transaction is final as soon as the block including it has a confirmation. Indeed, as hinted above, a block contains the endorsement quorum on the previous block contents. Thanks to the endorsement quorum, we have **transaction finality after 1 confirmation**.

It may be possible that different validators decide at different rounds with block proposals having the same content. And because a block headers contains the round at which the block was proposed, Tenderbake needs one more confirmation so that agreement on the whole block is reached. Thus we have **block finality after 2 confirmations**.

### Block times

Block times will depend on the round at which the first decision is taken. For example, if durations of the first 3 rounds are 30s, 60s, and 120s respectively, and the decision is taken at round 3, then the block time, relative to the previous block, is 3m30s. However, under normal network conditions, and with active and compliant validators, decisions should be taken at round 0, meaning that blocks time would be 30 seconds in this example.

Round durations will be set based on outcome from performance evaluations and from testnets.

### Validator selection: staking balance, active stake, and frozen deposits

Validator selection is as in Emmy* with the exception that
it is based on the delegate's *active stake* instead of its *staking
balance* (or rather the corresponding rolls; NB: rolls do not play a
role anymore, except for establishing a minimum required staking
balance). Let us first (re)define these and related concepts.

- The *(maximal) staking balance* of a delegate is its own balance plus the
  balances of all accounts that have delegated to it.
- The *active stake* of a delegate is the amount of tez with which
  it participates in consensus. It is at most its
  staking balance. It must be at least `token_per_roll = 8000
  tez`. We explain below how it is computed.
- The *frozen deposit* represents a percentage `deposit_percentage`,
  set to 10 (representing 10%), of the maximum active stake during the last 7 cycles
  (more precisely `preserved_cycles + max_slashing_period` cycles,
  where `max_slashing_period` is set to 2 cycles). This amount
  represents the delegate's skin in the game: in the case that the
  delegate behaves badly, its frozen deposit is partly slashed (see
  [Slashing](#slashing-bad-behavior)).  Taking the maximum over an
  interval of cycles (instead of just considering the active stake at
  the cycle where the bad action can occur) allows to avoid situations
  where a malicious delegate empties its accounts between the time
  rights are attributed and the time when the deposit is frozen. The frozen deposits are updated at the end of each cycle.
- The *spendable balance* of a delegate is its (own, total) balance
  minus the security deposit.

To clarify these types of balances, we state next some invariants
about them, and also the RPCs which allow to retrieve them:

- `delegated balance` represents the amount of tokens delegated to a
   given delegate; it excludes the delegate's own balance; obtained
   with `../context/delegates/<pkh>/delegated_balance`
- `staking balance = full balance + delegated balance`; obtained with
   `../context/delegates/<pkh>/staking_balance`
- `full balance = spendable balance + frozen deposit`; obtained with
  `../context/delegates/<pkh>/full_balance`
 - `frozen deposit` is obtained with `../context/delegates/<pkh>/frozen_deposits`
- `spendable balance` is obtained with `../context/contracts/<pkh>/balance`

(Note that these are not definitions, but just invariants; for
instance, the frozen deposits are computed in terms of the full balance,
not the other way around.)

Delegates can set an upper limit to their frozen deposits with the
commands `tezos-client set deposit limit for <delegate> to
<deposit_limit>`, and unset this limit with the command `tezos-client
unset deposit limit for <delegate>`. These commands are implemented by
using a new manager operation `Set_deposit_limit`. When emitting such a
command in cycle `c`, it affects the active stake for cycles starting
with `c+6` (ie `c + preserved_cycles + 1`); the new active stake is
taken into account when computing the frozen deposit for cycle `c+1`
already, however the user may see an update to its frozen deposit at
cycle `c+7` (ie `c + preserved_cycles + max_slashing_period`) at the
latest (because up to that cycle the frozen deposit also depends on the
active stake at cycles before cycle `c+1`).

The active stake is computed 5 (`preserved_cycles`) in advance: at
the end of cycle `c` for cycle `c+6` (as in Emmy*). Intuitively,
the active stake is set to 10 times the delegate's chosen frozen
deposit limit, without going beyond its available staking balance,
nor its maximum staking capacity (determined by its full balance).
More precisely, it is the minimum between:

- the delegate's staking balance, and
- 10 times the delegate's deposit cap, i.e. `deposit_cap * 100 / deposit_percentage`. If the delegate has not set a frozen deposit limit, `deposit_cap` is its full balance. Otherwise `deposit_cap` is the minimum between its full balance and the frozen deposit limit set by the delegate.

Let's take some examples. Say a delegate has `1000` tez (that's its
full balance). Then its theoretical maximum staking balance is
`10000` tez. The following table lists some scenarios (assuming for
simplicity no changes in the delegate's own and its staking balance
for last 8 cycles).

| Staking balance | Frozen deposit limit | Active stake | Frozen deposit | Spendable balance |
|----------------:|---------------------:|-------------:|---------------:|------------------:|
|  9000           |  -                   |  9000        |  900           | 100               |
| 12000           |  -                   | 10000        | 1000           |   0               |
|  9000           | 400                  |  4000        |  400           | 600               |
| 12000           | 400                  |  4000        |  400           | 600               |


We note in passing that this new schema basically solves the main
problem of over-delegation: a delegate will not fail anymore to bake
and endorse because of an insufficient balance to pay the
deposit. However, a delegate can still be over-delegated, and it will be
rewarded based on its active stake not on its staking balance.

<!--
For instance, if the delegate has a staking balance of `9000` tez and
it did not set a frozen deposit limit, then its active stake is `9000`
tez, and it has `900` tez in frozen deposit, its spendable balance being
`100` tez.-->


### Incentives mechanism

As in Emmy*, we reward participation in consensus and punish bad behavior. Notable changes however are as follows:

- Fees and baking rewards go to the payload proposer, the one who selects the transactions to be included in the block. In some cases, this validator might be different from block proposer, the baker who injects the block.
- Including extra endorsements, that is, more than the minimal required to obtain a quorum, is rewarded with a bonus.
- Endorsing rewards are shared equally among all validators. Participation above a minimal threshold per cycle is however required.
- Deposits are no longer frozen and unfrozen, instead a percentage of the active stake is always locked.
- Modifications were made to the balance unfreeze mechanism. In particular, validators are rewarded instantaneously for baking blocks and including extra endorsements, and not at the end of the cycle like in Emmy*. At the end of a cycle the following actions happen:
  - the selection of the consensus committee for the 5th next cycle, based on the current active stake distribution,
  - the distribution of endorsing rewards,
  - the adjustment of frozen deposits.


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
to their *expected* number of validator slots. The endorsing reward
may be received even if the validator's endorsement is not included in
a block. However, two conditions must be met:

 - the validator has revealed its nonce, and
 - the validator has been present during the cycle.

Not giving rewards in case of missing revelations is not new as it is [adapted
from
Emmy*](https://tezos.gitlab.io/alpha/proof_of_stake.html?highlight=nonce#random-seed).
The second condition is new. We say that a delegate is *present* during a cycle
if the endorsing power (that is, the number of validator slots at the
corresponding level) of all the delegate's endorsements included during the
cycle represent at least `presence_ratio` of the delegate's expected number of
validator slots for the current cycle (which is `blocks_per_cycle *
consensus_committee_size * active_stake / total_active_stake`). We set
`presence_ratio` to `2/3`. The endorsing rewards are distributed at the end of
the cycle if and only if (besides having revealed its nonces) the delegate was present.

Regarding the concrete values for rewards, we first fix the total reward per
level, call it `total_rewards`, to `80 / blocks_per_minute` tez. We
let:

- `baking_rewards := baking_reward_ratio * total_rewards`
- `bonus := (1-baking_reward_ratio) * bonus_ratio * total_rewards` is the max bonus; the bonus per additional endorsement slot is thus `bonus / (consensus_committee_size / 3)`
- `endorsing_rewards := (1-baking_reward_ratio) * (1-bonus_ratio) * total_rewards`; the rewards per endorsement slot are therefore `endorsing_rewards / consensus_committee_size`.

We set:

- `baking_reward_ratio` to `1 / 4`,
- `bonus_ratio` to `1 / 3`.

Assuming `blocks_per_minute = 2` we obtain `baking_rewards = 10` tez,
(maximum) `bonus = 10` tez, and `endorsing_rewards = 20` tez.  Further
assuming the `consensus_committee_size = 8000`, we obtain an endorsing
rewards per slot of `20 / 8000 = 0.0025` tez and a bonus per slot of
`10 / (8000 / 3) = .00375` tez.

Let's take an example. Say a block has round 1, is produced by
delegate B, and contains the payload from round 0 produced by delegate
A. Also, B included endorsements with endorsing power `6000`. Then A
receives the fees and 10 tez (the `baking_reward`) as a reward for
producing the block's payload. Concerning the bonus, there are `2666 =
8000 / 3` endorsement slots in additional to the minimum required:
`5334`. Therefore B receives the bonus `(6000 - 5334) * 0.00375
= 2.4975` tez. (Note that B only included 666 additional endorsing
slots, about a quarter of the maximum 2666 it could have theoretically
included.) Finally, consider some delegate C, whose active stake at
some cycle is 5% of the total stake. Note that his expected number of
validator slots for that cycle is `5/100 * 8192 * 8000 = 3,276,800`
slots. And assume that the endorsing power of C's endorsements
included during that cycle has been `3,123,456` slots. Given that this
number is bigger than the minimum required (`3,276,800 * 2 / 3`), it
receives an endorsing reward of `3,276,800 * 0.0025 = 8192` tez for
that cycle.


#### Slashing bad behavior

Like in Emmy*, not revealing nonces and double singing are punishable. If a
validator does not reveal its nonce by the end of the cycle, it does not receive
its endorsing rewards (as mentioned in the section [Rewards](#rewards)). If a
validator double signs, that is, it double bakes or it double (pre)endorses
(which means voting on two different proposals at the same round), the frozen
deposit is slashed. The slashed amount for double baking is fixed to `640` tez.
The slashed amount for double (pre)endorsing is fixed percentage, currently set
to 50% of the frozen deposit. The payload producer that includes the misbehavior
evidence is rewarded half of the slashed amount.

We note that selfish baking is not an issue in Tenderbake: say we are at round `r` and the validator which is proposer at round `r+1` does not (pre)endorse at round `r` in the hope that the block at round `r` is not agreed upon and its turn comes to propose at round `r+1`. Under the assumption that the correct validators have more than two thirds of the total stake, these correct validators have sufficient power for agreement to be reached, thus the lack of participation of a selfish baker does not have an impact.



## Backwards Compatibility

As mentioned in the abstract, the main change in going from Emmy* to [Tenderbake](https://arxiv.org/abs/2001.11965) is going from probabilistic to deterministic finality, more precisely, to finality in 2 blocks.
The other main changes are as follows:
- the format of endorsements changes, in particular, an endorsement for block `b` includes the round at which `b` was proposed; a validator emits at most an endorsement per round, but can emit more endorsements per level; therefore, the current high-water mark mechanism used by the signer needs to be adapted;
- besides endorsing, there is a second type of consensus operation called preendorsement; similarly, besides `double_endorsement_evidence` there is the operation `double_preendorsement_evidence`;
- the block header changes to include a set of endorsements for the predecessor block to serve as a justification that the previous block has been agreed upon; the block header may also include in rare cases a set of preendorsements; the block header no longer contains the priority entry;
- the block fitness changes, mainly to allow block candidates to be accepted by nodes;
- the length of cycles and voting periods will be adjusted according to the block times so that the same time duration is kept;
- there is no longer a distinction between baking and endorsing rights: delegates are validators in Tenderbake; validator rights in Tenderbake are similar to endorsing rights in Emmy*;
- the implementation of a validator is the baker daemon and because a validator bakes, preendorses and endorses, the endorser daemon is removed.

## Security Considerations

[Tenderbake](https://arxiv.org/abs/2001.11965) is proved to satisfy the so-called agreement and progress properties under the standard assumptions for BFT-style algorithms, namely that the network is [partially synchronous](https://decentralizedthoughts.github.io/2019-06-01-2019-5-31-models/) and a Byzantine attacker has at most one third of the total active stake.

## Implementation

https://gitlab.com/tezos/tezos/-/merge_requests/2664

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).

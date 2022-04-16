---
title: Consensus key
status: Draft
author: G.B. Fefe <gb.fefe@protonmail.com>, Nicolas Ochem <nicolas.ochem@gmail.com>
type: Interface
created: 2022-04-06
date: 2022-04-06
version: 0
---

## Summary

This TZIP describes a proposed protocol-amendment that would allow bakers to designate a consensus key responsible for signing baking and endorsing operations. This improves the operational security of Tezos bakers.

## Abstract

In the current version of the Tezos protocol (Ithaca), a baker is identified by a public key hash, e.g. a `tz1...` address. Like any public key hash in Tezos, this hash, or address, identifies an implicit account, i.e. a balance and the corresponding keypair allowed to withdraw funds. If for any reason a baker want to change the keypair used for signing consensus operations, they have to have all their delegator accounts redelegate to the hash of their new public key. This TZIP aims to ease this process and to avoid any redelegations.

For this purpose, we propose to reuse the oldest trick in programming history: to add an intermediate pointer. With this proposal, the address of a baker does not designate an implicit account anymore but a reference to an implicit account. The baker may change the referenced implicit account by calling the newly introduced `update_consensus_key` operation, thus transfering to it all the block-signing rights and (pre)endorsements-signing rights after a delay of `PRESERVED_CYCLES + 1`.

Separating keys allows separation of human responsibilities, which may alter the decentralization dynamics of the network. To neutralize this concern, a newly introduced `drain` operation allows the consensus key to transfer all the free balance of the baker to its own implicit account. This roughly confers the same powers to both keys. However, a newly introduced governance toggle `consensus_key_drain_toggle` will allow a majority of bakers to disable this `drain` operation later on, if they so choose.

## Design

We add a second key to delegates, called the consensus key. This consensus key is used instead of the regular key of the delegate (a.k.a. the manager key or the parent key) for signing blocks and (pre)endorsements. By default, the manager key and the consensus key are equal.

Internally, a table associates the manager keys to their respective consensus keys. This table is stored in the context. (right?)

The consensus key of a given delegate is set per cycle to whatever the consensus key is set in the table at the time the snapshot is taken.

We propose to add two new operations:

- `Update_consensus_key <public_key>`

  This operation must be signed by the manager key of a delegate. It
  will change the consensus key associated to the delegate: the new
  key will be used instead of the old key when computing the future
  baking rights distributions, meaning that the key will be required
  for signing blocks and endorsement in `preserved_cycles` (currently
  5 cycles in Ithaca).

  
  It is required that the account used as consensus key be allocated. The operation fails otherwise.

  Several bakers can have their consensus key set to the same key.

- `drain`

  This operation must be signed by the consensus key of a delegate currently allowed to sign consensus operations.

  This operation immediately transfers all the free balance of the manager account into the consensus account. It has no effect on the frozen balance.

  This operation fails if the governance toggle `consensus_key_drain_toggle` is set to False.

### `consensus_key_drain_toggle` toggle vote

The Toggle Vote for the drain operation relies on the computation of an
exponential moving average (EMA) of the signals sent by bakers in
their blocks. These signals can have three possible values: **On**,
**Off**, and **Pass**. The EMA is updated once per block as follows:
- if the baker of the block chose the **Pass** option then the EMA is
  not modified,
- if the baker of the block chose the **Off** option then the EMA is
  increased,
- if the baker of the block chose the **On** option then the EMA is
  decreased.

At each block, the EMA is compared to a constant known as the the
_threshold_ of the Toggle Vote. When the EMA is above the threshold,
it means that **Off** votes have the majority. On the opposite, a
value below the threshold means that **On** votes have the majority.

The `drain` operation works if and only if the EMA is below the threshold.

More precisely, the EMA is a natual number whose value can vary
between 0 and 2 billion and the threshold is 1 billion.
In each block, the EMA is updated as follows:
- if the baker votes **Pass** then the value is unchanged: EMA[n+1] =
  EMA[n]
- if the baker votes **On** then EMA[n+1] = (EMA[n] * 1999) / 2000
- if the baker votes **Off** then EMA[n+1] = ((EMA[n] * 1999) /
  2000) + 1,000,000


### Protocol migration

The migration establishes the correspondance table between the manager accounts and their consensus keys. Initially, all manager accounts and consensus keys are equal.

The migration also sets the initial EMA of the toggle vote to 1 billion.

### Commands


A consensus key can be changed at any point. This may be done with the command:

```shell
tezos-client set baker <bkr> consensus key to <key>
```

The current registration command still works:

```shell
tezos-client register key <mgr> as delegate
```

It is also possible to register as a delegate and immediately set the consensus key:

```shell
tezos-client register key <mgr> as delegate with consensus key <key>
```

TODO discuss this and figure out if it's true
## Motivation

### `update_consensus_key`

Key rotation is a common feature of any cryptosystem. Having a parent key delegate responsibilities to a child key allows for optimal protection of the parent key, for example in a cold wallet.

It also allows establishment of baking operations in an environment where access is not ultimately guaranteed: for example, a cloud platform providing hosted Key Management Systems where the private key is generated within the system and can never be downloaded by the baker. The baker can designate such KMS key as consensus key. Shall they lose access to the cloud platform for any reason, they can simply rotate to a new key.

Moreover, this proposal allows the baker to sign their consensus operations using new signature schemes as they get introduced in Tezos. They may elect to do so for performance or security reasons. The ultimate authority still rests on the parent key which can not be rotated. The security of the signature scheme of the parent key may decrease over time, however the fact that this key is used less often than the consensus key helps to mitigate this.

As a private baker, it is possible to put 90% of the funds in cold storage, in an account that delegates to the baker. This is however an imperfect substitute to this proposal, given that it still leaves 10% of the funds in the baker's account. It is also not doable for a public baker who may have 100% of their balance frozen.

### `drain`

The motivation of the `drain` operation is twofold.

#### As a deterrent against handing over the key to a third party

When there is one key, whoever has access to it has full control over the baker. When there are two keys, the possibility emerges of each of these keys being controlled by different people or entities. For example, the delegate key could be in physical custody of the baker, while the consensus key could be:

* hosted in a cloud platform where the cloud provider merely grants access to the baker, to be revoked at their discretion,
* handed to a service provider taking care of the baking operations on behalf of the baker (baking-as-a-service operator)

This constitues a centralization risk: some cloud operators have a large market share, which may give them the power to disrupt or stop the network. Some baking providers may also become dominant.

There are risks to this regardless of the existence of the `drain` operation: indeed, anyone with access to the consensus key has the ability to double sign, which can result in the delegate being slashed. Shall the attacker have baking rights, they may inject the denunciation operation in their own block, stealing half of the frozen balance, while the other half is burned.

Therefore, a rigorous baker will not hand off their consensus key to an untrusted party.

When the drain operation is enabled, a compromise of the consensus key allows a motivated attacker to spend all of the baker's balance. Indeed, the drain operation always takes precedence over any transaction in any block (TODO confirm this). Therefore, a motivated attacker is able to steal all of the baker's money by timing their drain operations appropriately, even if all of the balance is initially frozen.

The drain operation acts as an additional deterrent and ensures that the consensus keys ultimately has the same control over the balance than the delegate's key.

#### As a recovery mechanism from baker's key loss

A baker may lose their baking key. In this case, they may stop baking, wait `PRESERVED_CYCLES`, and then recover their funds with the `drain` operation. They may then start baking from another account.

### `consensus_key_drain_toggle` governance toggle
The introduction of the consensus key is an uncontroversial and long-standing request from the community. Many competing blockchains already have this feature implemented. But the permissions granted to the key have been subject to vigourous debate in the past.

A good case can be made for disabling the `drain` operation: it increases the security posture of the baker even further. Indeed, in the absence of the drain operation, a compromise of the consensus key does not put the unfrozen balance at risk. It still exposes the baker to a double signing attack, but this attack is complex to pull off and results in half of the frozen balance being burned.

On the other hand, disabling the `drain` operation also disables the recovery mechanism from loss of the baker key, and re-introduces concerns expressed above about changing the decentralization dynamics of the network.

The [liquidity baking toggle vote](https://gitlab.com/tezos/tzip/-/blob/master/drafts/current/draft-symmetric-liquidity-baking-toggle-vote.md) TZIP introduced a mechanism for fast and concurrent governance signaling mechanisms. This mechanism is suitable for a binary decision such as enabling or disabling an operation.

The `consensus_key_drain_toggle` governance toggle leaves the matter for the community to decide, separately from the feature itself.

### Q&A

#### Why not introduce a mechanism to rotate the baking key altogether?

We rejected the baking key rotation idea due to its intrusiveness. In particular, it would require all delegations to be changed to the new key.

#### Why not change the encoding of the baking key to something different than a `tz` address such as `BAKxxx` or `SG1xxx`?

This change would be disruptive in the community and mandate a lot of changes in tooling, for questionable benefit.

#### Can the baking key be a multisig? Can we have smart contracts manage baking? Can the rewards be sent to a third address?

All of these topics were discussed in the past. A previous TZIP called "Baking accounts" was implementing some of these ideas, but was ultimately rejected by the community because of technical shortcomings. We are actively limiting the scope and the amount of code changes in this TZIP to solve the narrower goal of having a separate consensus key.

#### Have you addressed all the unexpected breaking changes of the previous baking accounts proposal?

Refer to: [Baking Accounts proposal contains unexpected breaking changes](https://forum.tezosagora.org/t/baking-accounts-proposal-contains-unexpected-breaking-changes/2844)

Specifically this quote:

> A future version of Baking Accounts which does not break current contracts and preserves important invariants is possible, and should be developed to take its place.

We believe that the current proposal fits this description. Unlike the previous proposal, we are not allowing bakers to be controlled by multisignature smart contracts. As a result, we did not change any Michelson instruction and no smart contracts will break. Moreover, the consensus key is a regular implicit account with its own balance. In addition to signing consensus messages, it can do anything on chain that any other account can do, including calling smart contrats.

## Testing / edge cases

* set the consensus key to a third key, then back to the baker key
* set two delegates to the same consensus key (should work)
* set a delegate to a consensus key that is also a delegate (should work)
* empty the account of the consensus key when it's active (what happens then?)
* delegate the consensus key to any baker (should always work)

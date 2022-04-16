---
title: Rotating baking keys
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

In the current version of the Tezos protocol (Ithaca), a baker is identified by a public key hash, e.g. a `tz1...` address. Like any public key hash in Tezos, this hash, or address, identifies an implicit account, i.e. a balance and the corresponding keypair allowed to withdraw funds. If for any reason a baker want to change its keypair, it has to ask all their delegator to redelegate to the hash of their new public key. This TZIP aims to ease this process and to avoid any redelegations.

For this purpose, we propose to reuse the oldest trick in programming history: to add an intermediate pointer. With this proposal, the address of a baker does not designate an implicit account anymore but a reference to an implicit account. The baker may change the referenced implicit account by calling the newly introduced `update_consensus_key` operation, thus transfering to it all the block-signing rights and (pre)endorsements-signing rights after a delay of `PRESERVED_CYCLES + 1`.

Separating keys allows separation of human responsibilities, which may alter the decentralization dynamics of the network. To neutralize this concern, a newly introduced `drain` operation allows the consensus key to transfer all the free balance of the baker to its own implicit account. This roughly confers the same powers to both keys. However, a newly introduced governance toggle `disable_consensus_key_drain` will allow a supermajority of bakers to disable this operation later on, if they so choose.

## Design

We propose to add a second key to delegates, called the consensus key. This consensus key is used instead of the regular key of the delegate (a.k.a. the manager key or the parent key) for signing blocks and (pre)endorsement. By default, the manager key and the consensus key are equal.

We propose to add two new operations:

- `Update_consensus_key <public_key>`

  This operation must be signed by the manager key of a delegate. It
  will change the consensus key associated to the delegate: the new
  key will be used instead of the old key when computing the future
  baking rights distributions, meaning that the key will be required
  for signing blocks and endorsement in `preserved_cycles` (currently
  5 cycles in Ithaca).

  
  It is required that the account is allocated. The operation fails otherwise.

- `drain`

  This operation must be signed by the consensus key of a delegate currently allowed to sign consensus operations.

  This operation immediately transfers all the free balance of the manager account into the consensus account. It has no effect on the frozen balance.

  This operation fails if the governance toggle `disable_consensus_key_drain` is set to True.

### Protocol migration

The migration establishes the correspondance table between the manager accounts and their consensus keys. Initially, all manager accounts and consensus keys are equal.

## Motivation

### `update_consensus_key`

Key rotation is a common feature of any cryptosystem. Having a parent key delegate responsibilities to a child key allows for optimal protection of the parent key, for example in a cold wallet.

It also allows establishment of baking operations in an environment where access is not ultimately guaranteed: for example, a cloud platform providing hosted Key Management Systems where the private key is generated within the system and can never be downloaded by the baker. The baker can designate such KMS key as consensus key. Shall they lose access to the cloud platform for any reason, they can simply rotate to a new key.

Moreover, this proposal allows the baker to sign their consensus operations using new signature schemes as they get introduced in Tezos. They may elect to do so for performance or security reasons. The ultimate authority still rests on the parent key which can not be rotated. The security of the signature scheme of the parent key may decrease over time, however the fact that this key is used less often than the consensus key helps to mitigate this.

As a private baker, it is possible to put 90% of the funds in cold storage, in an account that delegates to the baker. This is however an imperfect substitute to this proposal, given that it still leaves 10% of the funds in the baker's account. It is also not doable for a public baker who may have 100% of their balance frozen.

### `drain`

### As a deterrent against handing over the key to a third party

When there is one key, whoever has access to it has full control over the baker. When there are two keys, the possibility emerges of each of these keys being controlled by different people or entities. For example, the delegate key could be in physical custody of the baker, while the consensus key could be:

* hosted in a cloud platform where the cloud provider merely grants access to the baker, to be revoked at their discretion,
* handed to a service provider taking care of the baking operations on behalf of the baker (baking-as-a-service operator)

This constitues a centralization risk: some cloud operators have a large market share, which may give them the power to disrupt or stop the network. Some baking providers may also become dominant.

There are risks to this regardless of the existence of the `drain` operation: indeed, anyone with access to the consensus key has the ability to double sign, which can result in the delegate being slashed. Shall the attacker have baking rights, they may inject the denunciation operation in their own block, stealing half of the frozen balance, while the other half is burned.

Therefore, a rigorous baker will not hand off their consensus key to an untrusted party.

The drain operation acts as an additional deterrent and ensures that the consensus keys ultimately has the same rights than the delegate's key: indeed, the baking entity is able to stop baking, and empty the account after `PRESERVED_CYCLES` when all balance is unfrozen.

### As a recovery mechanism from baker's key loss

A baker may lose their baking key. In this case, they may stop baking, wait `PRESERVED_CYCLES`, and then recover their funds and start baking from another account.

### `disable_consensus_key_drain` governance toggle
The drain operation is added in order to separate introduction of the consensus key mechanism, with the resolution of the question of the permissions of such a consensus key.

[todo expand on this]

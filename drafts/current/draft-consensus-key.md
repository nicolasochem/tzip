---
title: Consensus key
status: Draft
author: G.B. Fefe <gb.fefe@protonmail.com>, Nicolas Ochem <nicolas.ochem@gmail.com>
type: Interface
created: 2022-04-06
date: 2022-05-08
version: 1
---

## Summary

This TZIP describes a proposed protocol-amendment that would allow bakers to designate a consensus key responsible for signing baking and endorsing operations. This allows bakers to improve their operational security without the need for redelegation.

## Abstract

In the current version of the Tezos protocol (Ithaca), a baker is identified by a public key hash, e.g. a `tz1...` address. Like any public key hash in Tezos, this hash, or address, identifies an implicit account, i.e. a balance and the corresponding keypair allowed to withdraw funds. If for any reason a baker want to change the keypair used for signing consensus operations, they have to have all their delegator accounts manually redelegate to the hash of their new public key. This TZIP aims to ease this process and to avoid any explicit redelegations.

For this purpose, we propose to associate a second keypair to registered bakers, called the consensus key or the child key. By default this key is equal to the regular key of the baker (a.k.a. the manager key or the parent key). A baker may change the consensus key by calling the newly introduced `Update_consensus_key` operation, thus transfering to it all the block-signing rights and (pre)endorsements-signing rights after a delay of `PRESERVED_CYCLES + 1`.

Separating keys allows separation of human responsibilities, which may alter the decentralization dynamics of the network. To neutralize this concern, a newly introduced `Drain_delegate` operation allows the consensus key to transfer all the free balance of the baker to its own implicit account. This roughly confers the same powers to both keys. However, a newly introduced governance toggle `--drain-toggle-vote` will allow a majority of voting bakers to disable this `Drain_delegate` operation later on, if they so choose.

## Design

### A new consensus key table in the context

We propose to extend the context with two new tables:
- one main table storing the active consensus key of a baker,
- and a second table indexed by baker and cycle and storing pending consensus-key updates.

At the end of each cycle, the table of pending updates is traversed: consensus keys that must be activated in the next cycle are removed from the pending consensus-key table and inserted into the active consensus-key table.

### Two new operations in the protocol

We propose to add two new operations:

- `Update_consensus_key (<public_key>, <cycle>)`

  This operation must be signed by the manager key of a baker.

  It will record the update in the pending consensus-key table. The current implementation requires that `<cycle>` is equal to the current cycle plus `PRESERVED_CYCLES + 1`.

  At any time, a consensus key can only be used by a single baker, the operation fails otherwise.

- `Drain_delegate (<baker_pkh, consensus_pkh, destination_pkh>)`

  This operation must be signed by the active consensus key `consensus_pkh` of the baker `baker_pkh`.

  This operation immediately transfers all the free balance of the `baker_pkh` implicit account into the `destination_pkh` implicit account. It has no effect on the frozen balance.

  This operation fails if the governance toggle `--drain-toggle-vote` is set to **Off**, see next section.

  This operation is included in pass 2, together with `Seed_nonce_revelation`,`Double_*_evidence` and `Activate_account`. So they don't compete with regular manager operation in gas and block size quota, and they will always be applied before regular manager operation, e.g. a transfer operation from the baker.

  As an incentive for bakers to include `Drain_delegate` operation, a small fixed fraction of the baker free balance is transfered as fees to baker that includes the operation, i.e. the smallest amount between 1tz or 1% of the free balance.

### A new toggle vote `--drain-toggle-vote`

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

The `Drain_delegate` operation works if and only if the EMA is below the
threshold.

More precisely, the EMA is a natual number whose value can vary
between 0 and 2 billion and the threshold is 1 billion.
In each block, the EMA is updated as follows:
- if the baker votes **Pass** then the value is unchanged: EMA[n+1] =
  EMA[n]
- if the baker votes **On** then EMA[n+1] = (EMA[n] * 1999) / 2000
- if the baker votes **Off** then EMA[n+1] = ((EMA[n] * 1999) /
  2000) + 1,000,000


### Protocol migration

The proposed amendment needs to initialize the new consensus key table.
It will iterate on all registered bakers (around ~2500) and set
the consensus key to be equal to the manager key.

The migration also sets the initial EMA of the toggle vote to zero.

The stake snapshots for the next `PRESERVED_CYCLES` are also reallocated. They now snapshot both the consensus public key and the manager public key hash. Yet, the baking and endorsing rights are unchanged.

### New commands in `tezos-client`

A consensus key can be changed at any point. This may be done with the command:

```shell
tezos-client set consensus key for <mgr> to <key>
```

The current registration command still works:

```shell
tezos-client register key <mgr> as delegate
```

It is also possible to register as a delegate and immediately set the consensus key:

```shell
tezos-client register key <mgr> as delegate with consensus key <key>
```

The drain operation might be sent with:

```shell
tezos-client drain delegate <mgr> to <key>
```

### A new flag to the baker

Like the mandatory flag `--liquidity-baking-togle-vote [on|off|pass]`, the
baker now requires the flag `--drain-toggle-vote [on|off|pass]`.


## Change in RPCs

- `GET /chains/main/blocks/head/header`

  The protocol specific part of a block header is extended with a new toggle vote:

```
   "drain_toggle_vote": "off|on|pass",
```

- `GET /chains/main/blocks/head/context/constants`

  A new constant is exported:

``
   "drain_toggle_ema_threshold": 1000000000
``

- GET `/chains/main/blocks/head/metadata`

  The block metadata are extended with the active consensus key of the baker and proposer. The field `proposer` and `baker` still hold the respective public key hash of the manager keys of the proposer and baker. The block metadata also export the current value of the drain toggle ema.

```
  "proposer_consensus_key": "[PUBLIC_KEY_HASH]",
  "baker_consensus_key": "[PUBLIC_KEY_HASH]",
  "drain_toggle_ema": 1234567890,
```

- `GET /chains/main/blocks/head/context/delegates/[PUBLIC_KEY_HASH]`

  The delegate data are extended with active and pending consensus keys.

```
{ "full_balance": "4000000000000",
  "current_frozen_deposits": "200000000000",
  "frozen_deposits": "200000000000",
  "staking_balance": "4000000000000",
  "delegated_contracts": [ "[PUBLIC_KEY_HASH]" ],
  "delegated_balance": "0",
  "deactivated": false,
  "grace_period": 5,
  "voting_power": "4000000000000",
  "active_consensus_key": "[PUBLIC_KEY_HASH]",
  "pending_consensus_keys": [
      { "cycle": 7, "pkh": "[PUBLIC_KEY_HASH]},
      { "cycle": 9, "pkh": "[PUBLIC_KEY_HASH]}
    ]
  }
```

- `GET /chains/main/blocks/head/helpers/baking_rights`

  The baking rights RPC now returns both the manager key, required to identify the rewarded delegate, and the active consensus key required to sign block. The RPC also accepts a new parameter `consensus_key=<pkh>` to filter the result by active consensus key.

```
[ { "level": 2, "delegate": "[PUBLIC_KEY_HASH]",
    "round": 0, "estimated_time": "[TIMESTAMP]",
    "consensus_key": "[PUBLIC_KEY_HASH]" },
  { "level": 2, "delegate": "[PUBLIC_KEY_HASH]",
    "round": 1, "estimated_time": "[TIMESTAMP]",
    "consensus_key": "[PUBLIC_KEY_HASH]" },
  { "level": 2, "delegate": "[PUBLIC_KEY_HASH]",
    "round": 2, "estimated_time": "[TIMESTAMP]",
    "consensus_key": "[PUBLIC_KEY_HASH]" },
  { "level": 2, "delegate": "[PUBLIC_KEY_HASH]",
    "round": 3, "estimated_time": "[TIMESTAMP]",
    "consensus_key": "[PUBLIC_KEY_HASH]" },
  { "level": 2, "delegate": "[PUBLIC_KEY_HASH]",
    "round": 10, "estimated_time": "[TIMESTAMP]",
    "consensus_key": "[PUBLIC_KEY_HASH]" } ]
```

- `GET /chains/main/blocks/head/helpers/endorsing_rights`

  The endorsing rights RPC now returns both the manager key, required to identify the rewarded delegate, and the active consensus key required to sign a block. The RPC also accepts a new parameter `consensus_key=<pkh>` to filter the result by active consensus key.

```
[ { "level": 1,
    "delegates":
      [ { "delegate": "[PUBLIC_KEY_HASH]",
          "first_slot": 11, "endorsing_power": 50,
          "consensus_key": "[PUBLIC_KEY_HASH]" },
        { "delegate": "[PUBLIC_KEY_HASH]",
          "first_slot": 4, "endorsing_power": 47,
          "consensus_key": "[PUBLIC_KEY_HASH]" },
        { "delegate": "[PUBLIC_KEY_HASH]",
          "first_slot": 2, "endorsing_power": 46,
          "consensus_key": "[PUBLIC_KEY_HASH]" },
        { "delegate": "[PUBLIC_KEY_HASH]",
          "first_slot": 1, "endorsing_power": 55,
          "consensus_key": "[PUBLIC_KEY_HASH]" },
        { "delegate": "[PUBLIC_KEY_HASH]",
          "first_slot": 0, "endorsing_power": 58,
          "consensus_key": "[PUBLIC_KEY_HASH]" } ] } ]
```

## Breaking changes

This TZIP introduces no breaking changes. In particular, the RPC changes only consist of new fields added to maps.

## Motivation

### `Update_consensus_key`

Key rotation is a common feature of any cryptosystem. Having a parent key delegate responsibilities to a child key allows for optimal protection of the parent key, for example in a cold wallet.

It also allows establishment of baking operations in an environment where access is not ultimately guaranteed: for example, a cloud platform providing hosted Key Management Systems where the private key is generated within the system and can never be downloaded by the operator. The baker can designate such KMS key as consensus key. Shall they lose access to the cloud platform for any reason, they can simply rotate to a new key.

Moreover, this proposal allows the baker to sign their consensus operations using new signature schemes as they get introduced in Tezos. They may elect to do so for performance or security reasons.


### `Drain_delegate`

The motivation of the `Drain_delegate` operation is twofold.

#### As a deterrent against handing over the key to a third party

When there is one key, whoever has access to it has full control over the baker. When there are two keys, the possibility emerges of each of these keys being controlled by different people or entities. For example, the manager key would likely be in physical custody of the baker, while the consensus key could be handed to, or created by:

* a cloud platform, or
* a contractor or baking-as-a-service provider taking care of the baking operations on behalf of the baker.

This constitues a centralization risk:

* the cloud platform may revoke access unilaterally. Some cloud operators have a large market share, which may give them the power to disrupt or stop the network,
* dominant baking service providers may emerge.

At any time, if over one third of the stake goes offline, the chain can not move forward. Decentralization is key to avoiding this.

The drain operation acts as an deterrent against centralization and ensures that the consensus keys ultimately has the same control over the balance than the manaker key.

#### As a recovery mechanism from baker's key loss

A baker may lose their baking key. In this case, they may stop baking, wait `PRESERVED_CYCLES`, and then recover their funds with the `Drain_delegate` operation. They may then start baking from another account.

### `drain_toggle` governance toggle

The permissions granted to a potential consensus key have been subject of vigourous debates in the past.

The core argument against the `Drain_delegate` operation is as follows: removing the `Drain_delegate` operation increases the security posture of the baker even further. Indeed, in its absence, a compromise of the consensus key does not put the unfrozen balance at risk.

It is useful to ask two questions:
* should the consensus key exist at all? The answer is an uncontroversial yes. A consensus key is long-standing request from the community. Many competing blockchains already have this feature implemented.
* what permissions should be granted to it? Opinions on the matter differ, but we believe they can coalesce into a binary question on whether the `Drain_delegate` operation as proposed should exist or not.

The [liquidity baking toggle vote](https://gitlab.com/tezos/tzip/-/blob/master/drafts/current/draft-symmetric-liquidity-baking-toggle-vote.md) TZIP introduced a mechanism for fast and concurrent governance signaling mechanisms.

This mechanism is suitable for a binary decision such as enabling or disabling the `Drain_delegate` operation. Therefore, the proposed `--drain-toggle` governance toggle leaves the matter for the community to decide, separately from the feature itself.

The operation will initially be enabled. When setting up their baker for the new protocol, bakers will have to choose whether to vote `pass`, `on` and `off`.

The threshold for disabling the operation is at 50% (simple majority). The exponential moving average is initially set to zero, as if 100% of the stake was in favor of enabling it: this matches the current reality on the network where the owner of the consensus key can spend the free balance. In order to disable it, it is necessary to have more `Off` than `On` votes for a sufficiently long period before it goes over the threshold.

### Q&A

#### Why not introduce a mechanism to rotate the baking key altogether?

The implementation of such a rotation mechanism would be very intrusive. In particular, it would require all delegations to be changed to the new key. We believe that a parent/key design is a better path to solving the issue.

#### What if the signature scheme of the parent key turns out to be insecure?
In this proposal, the ultimate authority indeed rests on the parent key which can not be rotated. The security of the signature scheme of the parent key may decrease over time. However, the less often a key is used, the more secure it is.

#### A baker can already self-delegate to put most funds in a cold wallet. Why do we need a consensus key?

As a private baker, it is possible to put 90% of the funds in cold storage, in an account that delegates to the baker. This is however an imperfect substitute to this proposal, given that it still leaves 10% of the funds in the baker's account. It is also not doable for a public baker who may have 100% of their balance frozen.
#### Why is the drain operation necessary? Isn't giving away your consensus key risky, even in the absence of a drain operation?

Indeed, anyone with access to the consensus key has the ability to double sign, which can result in the baker being slashed. Shall the attacker have baking rights, they may inject the denunciation operation in their own block, stealing half of the frozen balance, while the other half is burned.

Therefore, a rigorous baker will keep their consensus key secure and will not hand it off to an untrusted party.

But the drain operation makes the risk of doing so more evident: when the drain operation is enabled, a compromise of the consensus key allows a motivated attacker to spend all of the baker's balance.

#### How to bake using the consensus key?

In your baker's command, replace the delegate's manager key alias with the consenus key alias:

```
tezos-baker-0XX-Psxxxxxx run with local node ~/.tezos-node <consensus_key_alias>
```

While transitioning from the delegate's manager key, it is possible to pass the alias for both delegate's manager key and consensus key. The baker will seamlessly keep baking when the transition happens:
```
tezos-baker-0XX-Psxxxxxx run with local node ~/.tezos-node <consensus_key_alias> <delegate_key_alias>
```

#### Why not change the encoding of the baking key to something different than a `tz` address such as `BAKxxx` or `SG1xxx`?

This change would be disruptive in the community and mandate a lot of changes in tooling, for questionable benefit.

#### Can the baking key be a multisig? Can we have smart contracts manage baking? Can the rewards be sent to a third address? Can a third address be used for voting? Can we have a toggle to disallow new delegations?

All of these topics were discussed in the past. A previous TZIP draft called "Baking accounts" was implementing some of these ideas, but was ultimately rejected by the community because of technical shortcomings. We are actively limiting the scope and the amount of code changes in this TZIP to solve the narrower goal of having a separate consensus key. Some of this ideas may be proposed in future TZIPs.

#### Have you addressed all the unexpected breaking changes of the previous baking accounts proposal?

Refer to: [Baking Accounts proposal contains unexpected breaking changes](https://forum.tezosagora.org/t/baking-accounts-proposal-contains-unexpected-breaking-changes/2844)

Specifically this quote:

> A future version of Baking Accounts which does not break current contracts and preserves important invariants is possible, and should be developed to take its place.

We believe that the current proposal fits this description. Unlike the
previous proposal, we are not allowing bakers to be controlled by
multisignature smart contracts. As a result, we did not change any
Michelson instruction and no smart contracts will break. Moreover, the
consensus key is a regular implicit account with its own balance. In
addition to signing consensus messages, it can at any time do anything on
chain that any other account can do, including calling smart contrats.

## Security considerations

`Update_consensus_key` is not taking effect immediately, but `PRESERVED_CYCLES + 1` later, which mitigates risks of accidental usage or being tricked into running the operation. This delay applies to both baking rights as well as the usage of `Drain_delegate`.

The Ledger app should be modified to recognize the `Update_consensus_key` and print the action on-screen in plain English, rather than blind signing.

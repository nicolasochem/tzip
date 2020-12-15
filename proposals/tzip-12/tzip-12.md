---
tzip: 12
title: FA2 - Multi-Asset Interface
status: Draft
type: Financial Application (FA)
author: Eugene Mishura (@e-mishura)
created: 2020-01-24
---

## Table Of Contents

- [Summary](#summary)
- [Motivation](#motivation)
- [Abstract](#abstract)
- [General](#general)
- [TZIP-16 Contract Metadata](#tzip-16-contract-metadata)
- [Interface Specification](#interface-specification)
  - [Entrypoint Semantics](#entrypoint-semantics)
    - [`transfer`](#transfer)
      - [Core Transfer Behavior](#core-transfer-behavior)
      - [Default Transfer Permission Policy](#default-transfer-permission-policy)
    - [`balance_of`](#balance_of)
    - [Operators](#operators)
      - [`update_operators`](#update_operators)
    - [Token Metadata](#token-metadata)
  - [FA2 Transfer Permission Policies and Configuration](#fa2-transfer-permission-policies-and-configuration)
    - [A Taxonomy of Transfer Permission Policies](#a-taxonomy-of-transfer-permission-policies)
      - [Exposing Permissions Descriptor](#exposing-permissions-descriptor)
  - [Error Handling](#error-handling)
- [Implementing Different Token Types with FA2](#implementing-different-token-types-with-fa2)
  - [Single Fungible Token](#single-fungible-token)
  - [Multiple Fungible Tokens](#multiple-fungible-tokens)
  - [Non-fungible Tokens](#non-fungible-tokens)
  - [Mixing Fungible and Non-fungible Tokens](#mixing-fungible-and-non-fungible-tokens)
  - [Non-transferable Tokens](#non-transferable-tokens)
- [Legacy Interface](#legacy-interface)
  - [Token Metadata Entrypoints](#token-metadata-entrypoints)
  - [Permissions Descriptor Entrypoint](#permissions-descriptor-entrypoint)
- [Future Directions](#future-directions)
- [Copyright](#copyright)

## Summary

TZIP-12 proposes a standard for a unified token contract interface,
supporting a wide range of token types and implementations. This document provides
an overview and rationale for the interface, token transfer semantics, and support
for various transfer permission policies.

**PLEASE NOTE:** This API specification remains a work-in-progress and may evolve
based on public comment see FA2 Request for Comment on [Tezos Agora](https://tezosagora.org).

## Motivation

There are multiple dimensions and considerations while implementing a particular
token smart contract. Tokens might be fungible or non-fungible. A variety of
transfer permission policies can be used to define how many tokens can be transferred,
who can perform a transfer, and who can receive tokens. A token contract can be
designed to support a single token type (e.g. ERC-20 or ERC-721) or multiple token
types (e.g. ERC-1155) to optimize batch transfers and atomic swaps of the tokens.

Such considerations can easily lead to the proliferation of many token standards,
each optimized for a particular token type or use case. This situation is apparent
in the Ethereum ecosystem, where many standards have been proposed, but ERC-20
(fungible tokens) and ERC-721 (non-fungible tokens) are dominant.

Token wallets, token exchanges, and other clients then need to support multiple
standards and multiple token APIs. The FA2 standard proposes a unified token
contract interface that accommodates all mentioned concerns. It aims to provide
significant expressivity to contract developers to create new types of tokens
while maintaining a common interface standard for wallet integrators and external
developers.

## Abstract

This standard defines the unified contract interface and its behavior to support
a wide range of token types and implementations. The particular FA2 implementation
may support either a single token type per contract or multiple tokens per contract,
including hybrid implementations where multiple token kinds (fungible, non-fungible,
non-transferable etc) are supported.

Most of the entrypoints are batch operations that allow querying or transfer of
multiple token types atomically.

Most token standards specify logic that validates a transfer transaction and can
either approve or reject a transfer. Such logic could validate who can perform a
transfer, the transfer amount and who can receive tokens. This standard calls
such logic a _transfer permission policy_. The FA2 standard defines the
[default `transfer` permission policy](#default-transfer-permission-policy) that
specify who can transfer tokens. The default policy allows transfers by
either token owner (an account that holds token balance) or by an operator
(an account that is permitted to manage tokens on behalf of the token owner).

Unlike many other standards, FA2 allows to customize the default transfer permission
policy (see
[FA2 Transfer Permission Policies and Configuration](#fa2-transfer-permission-policies-and-configuration))
using a set of predefined permission behaviors that are optional.

This specification defines the set of [standard errors](#error-handling) and error
mnemonics to be used when implementing FA2. However, some implementations MAY
introduce their custom errors that MUST follow the same pattern as standard ones.

## General

The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”,
“SHOULD NOT”, “RECOMMENDED”, “MAY”, and “OPTIONAL” in this document are to be
interpreted as described in [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt).

- Token type is uniquely identified on the chain by a pair composed of the token
  contract address and token ID, a natural number (`nat`). If the underlying contract
  implementation supports only a single token type (e.g. ERC-20-like contract),
  the token ID MUST be `0n`. In the case when multiple token types are supported
  within the same FA2 token contract (e. g. ERC-1155-like contract), the contract
  is fully responsible for assigning and managing token IDs.

- The FA2 batch entrypoints accept a list (batch) of parameters describing a
  single operation or a query. The batch MUST NOT be reordered or deduplicated and
  MUST be processed in the same order it is received.

- Empty batch is a valid input and MUST be processed as a non-empty one.
  For example, an empty transfer batch will not affect token balances, but applicable
  transfer core behavior and permission policy MUST be applied. Invocation of the
  `balance_of` entrypoint with an empty batch input MUST result in a call to a
  callback contract with an empty response batch.

- If the underlying contract implementation supports only a single token type,
  the batch may contain zero or multiple entries where token ID is a fixed `0n`
  value. Likewise, if multiple token types are supported, the batch may contain
  zero or more entries and there may be duplicate token IDs.


## TZIP-16 Contract Metadata

An FA2-compliant contract can implement TZIP-16:

- If a contract does not contain the TZIP-16 `%metadata` big-map, it must
  provide token-specific-metadata through the `%metadata_token` big-map method.
- Contracts implemented before the current revision of TZIP-12, should
  considered “legacy FA2,” for compatibility with these contracts, see the
  (deprecated) [Legacy Interface](#legacy-interface) section.

The metadata JSON structure is precised below:

The TZIP-16 `"interfaces"` field MUST be present:

- It should contain `"TZIP-12[-<version-info>]"`
    - `version-info` is an optional string extension, precising which version of
      this document is implemented by the contract (commit hash prefix,
      e.g. `6883675` or an [RFC-3339](https://tools.ietf.org/html/rfc3339) date,
      e.g. `2020-10-23`).

The TZIP-16 `"views"` field can be present, some optional off-chain-views are
specifed below, see section [Off-chain-views](#off-chain-views).

A TZIP-12-specific field `"permissions"` is defined in [Exposing Permissions
Descriptor](#exposing-permissions-descriptor), and it is optional, but
recommended if it differs from the default value.

### Examples

A single-NFT FA2 token can be augmented with the following JSON:

```json
{
  "description": "This is my NFT",
  "interfaces": ["TZIP-12-2020-11-17"],
  "views": [
    { "name": "get_balance",
      "description": "This is the `get_balance` view required by TZIP-12.",
      "implementations": [
          { "michelson-storage-view": {
              "parameter": {
                  "prim": "pair",
                  "args": [{"prim": "nat", "annots": ["%token_id"]},
                           {"prim": "address", "annots": ["%owner"]}]},
              "return-type": {"prim": "nat"},
              "code": [
                  {"prim": "TODO"}]}}]}],
  "permissions": { "operator": "owner-or-operator-transfer",
                   "receiver": "owner-no-hook",
                   "sender": "owner-no-hook" }
}
```

  
### Off-Chain-Views

Within its TZIP-16 metadata, an FA2 contract does not have to provide any
off-chain-view but can provide 4 optional views: `get_balance`, `total_supply`,
`all_tokens`, `is_operator`, and `token_metadata`. If present, all of these
SHOULD be implemented, at least, as *“Michelson Storage Views”* and have the
following types (Michelson annotations are optional) and semantics:

- `get_balance` has `(pair (nat %token_id) (address %owner))` as
  parameter-type, and `nat` as return-type; it must return the balance
  corresponding to the owner/token pair.
- `total_supply` has type `(nat %token_id) → (nat %supply)` and should return
  to total number of tokens for the given token-id if known or fail if not.
-  `all_tokens` has no parameter and returns the list of all the token IDs,
   `(list nat)`, known to the contract.
- `is_operator` has type
  `(pair (nat %token_id) (pair (address %owner) (address %operator))) → bool`
   and should return whether `%operator` is allowed to transfer `%token_id`
   tokens owned by `owner`.
- `token_metadata` is one of the 2 ways of providing token-specific metadata, it
  is defined in section [Token Metadata](#token-metadata) and is not optional if
  the contract does not have a `%token_metadata` big-map.

## Interface Specification

Token contract implementing the FA2 standard MUST have the following entrypoints.
Notation is given in [cameLIGO language](https://ligolang.org) for readability
and Michelson. The LIGO definition, when compiled, generates compatible Michelson
entrypoints.

`type fa2_entry_points =`

- [`| Transfer of transfer list`](#transfer)
- [`| Balance_of of balance_of_param`](#balance_of)
- [`| Update_operators of update_operator list`](#update_operators)
- [`| Assert_balances of assert_balance list`](#assert_balances) (optional)

The full definition of the FA2 entrypoints in LIGO and related types can be found
in [fa2_interface.mligo](./fa2_interface.mligo).

### Entrypoint Semantics

#### `transfer`

LIGO definition:

```ocaml
type token_id = nat

type transfer_destination =
[@layout:comb]
{
  to_ : address;
  token_id : token_id;
  amount : nat;
}

type transfer =
[@layout:comb]
{
  from_ : address;
  txs : transfer_destination list;
}

| Transfer of transfer list
```

Michelson definition:

```
(list %transfer
  (pair
    (address %from_)
    (list %txs
      (pair
        (address %to_)
        (pair
          (nat %token_id)
          (nat %amount)
        )
      )
    )
  )
)
```

Each transfer in the batch is specified between one source (`from_`) address and
a list of destinations. Each `transfer_destination` specifies token type and the
amount to be transferred from the source address to the destination (`to_`) address.

FA2 does NOT specify an interface for mint and burn operations; however, if an
FA2 token contract implements mint and burn operations, it SHOULD, when possible,
enforce the same logic (core transfer behavior and transfer permission logic)
applied to the token transfer operation. Mint and burn can be considered special
cases of the transfer. Although, it is possible that mint and burn have more or
less restrictive rules than the regular transfer. For instance, mint and burn
operations may be invoked by a special privileged administrative address only.
In this case, regular operator restrictions may not be applicable.

##### Core Transfer Behavior

FA2 token contracts MUST always implement this behavior.

- Every transfer operation MUST happen atomically and in order. If at least one
  transfer in the batch cannot be completed, the whole transaction MUST fail, all
  token transfers MUST be reverted, and token balances MUST remain unchanged.

- Each transfer in the batch MUST decrement token balance of the source (`from_`)
  address by the amount of the transfer and increment token balance of the destination
  (`to_`) address by the amount of the transfer.

- If the transfer amount exceeds current token balance of the source address,
  the whole transfer operation MUST fail with the error mnemonic `"FA2_INSUFFICIENT_BALANCE"`.

- If the token owner does not hold any tokens of type `token_id`, the owner's balance
  is interpreted as zero. No token owner can have a negative balance.

- The transfer MUST update token balances exactly as the operation
  parameters specify it. Transfer operations MUST NOT try to adjust transfer
  amounts or try to add/remove additional transfers like transaction fees.

- Transfers of zero amount MUST be treated as normal transfers.

- Transfers with the same address (`from_` equals `to_`) MUST be treated as normal
  transfers.

- If one of the specified `token_id`s is not defined within the FA2 contract, the
  entrypoint MUST fail with the error mnemonic `"FA2_TOKEN_UNDEFINED"`.

- Transfer implementations MUST apply transfer permission policy logic (either
  [default transfer permission policy](#default-transfer-permission-policy) or
  [customized one](#customizing-transfer-permission-policy)).
  If permission logic rejects a transfer, the whole operation MUST fail.

- Core transfer behavior MAY be extended. If additional constraints on tokens
  transfer are required, FA2 token contract implementation MAY invoke additional
  permission policies. If the additional permission fails, the whole transfer
  operation MUST fail with a custom error mnemonic.

##### Default Transfer Permission Policy

- Token owner address MUST be able to perform a transfer of its own tokens (e. g.
  `SENDER` equals to `from_` parameter in the `transfer`).

- An operator (a Tezos address that performs token transfer operation on behalf
  of the owner) MUST be permitted to manage the specified owner's tokens before
  it invokes a transfer transaction (see [`update_operators`](#update_operators)).

- If the address that invokes a transfer operation is neither a token owner nor
  one of the permitted operators, the transaction MUST fail with the error mnemonic
  `"FA2_NOT_OPERATOR"`. If at least one of the `transfer`s in the batch is not permitted,
  the whole transaction MUST fail.

#### `balance_of`

LIGO definition:

```ocaml
type token_id = nat

type balance_of_request = {
  owner : address;
  token_id : token_id;
}

type balance_of_response = {
  request : balance_of_request;
  balance : nat;
}

type balance_of_param =
[@layout:comb]
{
  requests : balance_of_request list;
  callback : (balance_of_response list) contract;
}

| Balance_of of balance_of_param
```

Michelson definition:

```
(pair %balance_of
  (list %requests
    (pair
      (address %owner)
      (nat %token_id)
    )
  )
  (contract %callback
    (list
      (pair
        (pair %request
          (address %owner)
          (nat %token_id)
        )
        (nat %balance)
      )
    )
  )
)
```

Gets the balance of multiple account/token pairs. Accepts a list of
`balance_of_request`s and a callback contract `callback` which accepts a list of
`balance_of_response` records.

- There may be duplicate `balance_of_request`'s, in which case they should not be
  deduplicated nor reordered.

- If the account does not hold any tokens, the account
  balance is interpreted as zero.

- If one of the specified `token_id`s is not defined within the FA2 contract, the
  entrypoint MUST fail with the error mnemonic `"FA2_TOKEN_UNDEFINED"`.

_Notice:_ The `balance_of` entrypoint implements a _continuation-passing style (CPS)
view entrypoint_ pattern that invokes the other callback contract with the requested
data. This pattern, when not used carefully, could expose the callback contract
to an inconsistent state and/or manipulatable outcome (see
[view patterns](https://www.notion.so/Review-of-TZIP-12-95e4b631555d49429e2efdfe0f9ffdc0#6d68e18802734f059adf3f5ba8f32a74)).
The `balance_of` entrypoint should be used on the chain with extreme caution.


#### `assert_balances`

This entrypoint is optional.

LIGO definition:

```ocaml
type token_id = nat

type assert_balance = [@layout:comb] {
  owner : address;
  token_id : token_id;
  balance: nat;
}

| Assert_balances of assert_balance list
```

Michelson definition:

```
(pair %assert_balances
  (list
    (pair
      (address %owner)
      (pair
        (nat %token_id)
        (nat %balance)))))
```

Checks the balances of a list of account/token pairs. If all the balances are
correct, the entrypoint MUST do nothing (output same storage and no operations).
If any of the balances is wrong it MUST interrupt the operation using
`FAILWITH`.

#### Operators

**Operator** is a Tezos address that originates token transfer operation on behalf
of the owner.

**Owner** is a Tezos address which can hold tokens.

An operator, other than the owner, MUST be approved to manage specific tokens
held by the owner to transfer them from the owner account.

FA2 interface specifies an entrypoint to update operators. Operators are permitted
per specific token owner and token ID (token type). Once permitted, an operator
can transfer tokens of that type belonging to the owner.

##### `update_operators`

LIGO definition:

```ocaml
type token_id = nat

type operator_param =
[@layout:comb]
{
  owner : address;
  operator : address;
  token_id : token_id;
}

type update_operator =
  [@layout:comb]
  | Add_operator of operator_param
  | Remove_operator of operator_param

| Update_operators of update_operator list
```

Michelson definition:

```
(list %update_operators
  (or
    (pair %add_operator
      (address %owner)
      (pair
        (address %operator)
        (nat %token_id)
      )
    )
    (pair %remove_operator
      (address %owner)
      (pair
        (address %operator)
        (nat %token_id)
      )
    )
  )
)
```

Add or Remove token operators for the specified token owners and token IDs.

- The entrypoint accepts a list of `update_operator` commands. If two different
  commands in the list add and remove an operator for the same token owner and
  token ID, the last command in the list MUST take effect.

- It is possible to update operators for a token owner that does not hold any token
  balances yet.

- Operator relation is not transitive. If C is an operator of B and if B is an
  operator of A, C cannot transfer tokens that are owned by A, on behalf of B.

The standard does not specify who is permitted to update operators on behalf of
the token owner. Depending on the business use case, the particular implementation
of the FA2 contract MAY limit operator updates to a token owner (`owner == SENDER`)
or be limited to an administrator.

### Token Metadata

Token metadata is meant for off-chain, user-facing, contexts (e.g.  wallets,
explorers, marketplaces). 

#### Token-Metadata Values

Token-specific metadata is stored/presented as a Michelson value of type
`(map string bytes)`.  A few of the keys are reserved and predefined by
TZIP-12:

- `""` (empty-string): should correspond to a TZIP-16 URI which points to a JSON
  representation of the token metadata.
- `"name"`: should be a UTf-8 string giving a “display name” to the token.
- `"symbol"`: should be a UTF-8 string for the short identifier of the token
  (e.g. XTZ, EUR, …).
- `"decimals"`: should be an integer (converted to a UTF-8 string in decimal)
  which defines the position of the decimal point in token balances for display
  purposes.

In the case, of a TZIP-16 URI pointing to a JSON blob, the JSON preserves the
same 3 reserved non-empty fields:

`{ "symbol": <string>, "name": <string>, "decimals": <number>, ... }`

It is highly recommended to provide the 3 values either in the map or in the
external JSON; the default value for decimals is zero.

Other standards deriving from TZIP-12 may reserve other keys (e.g. `"icon"`,
`"homepage"`, …).

#### Storage & Access

A given contract can use 2 methods to provide access to the token-metadata.  In
both cases the “key” is the token-id (of type `nat`) and one MUST store or
return a value of type `(pair nat (map string bytes))`: the token-id and the
metadata defined above. The following methods are allowed (future upgrades of
TZIP-12 may add new cases):

1. One can store the values in a big-map annotated `%token_metadata` of type
   `(big_map nat (pair nat (map string bytes)))`.
2. Or one can provide a `token_metadata` off-chain-view which takes as parameter
   the `nat` token-id and returns the `(pair nat (map string bytes))` value.

If both options are present, the off-chain-view is preferred since it allows
the implementor to customize and augment the response.

### FA2 Transfer Permission Policies and Configuration

Most token standards specify logic such as who can perform a transfer, the amount
of a transfer, and who can receive tokens. This standard calls such logic
_transfer permission policy_ and defines a framework to compose such permission
policies from the [standard permission behaviors](#permission-behaviors).

FA2 allows the contract developer to choose and customize from a variety of permissions
behaviors, easily enabling non-transferrable tokens or centrally-administrated
tokens without operators. The particular implementation may be static
(the permissions configuration cannot be changed after the contract is deployed)
or dynamic (the FA2 contract may be upgradable and allow to change the permissions
configuration). However, the FA2 token contract MUST expose consistent and
non-self-contradictory permissions configuration (unlike ERC-777 that exposes two
flavors of the transfer at the same time).

#### A Taxonomy of Transfer Permission Policies

##### Permission Behaviors

Transfer permission policy is composed from several orthogonal permission behaviors.
Each permission behavior defines a set of possible behavior configurations (one
of those configuration is default). The concrete policy is expressed as a combination
of concrete configuration values for each permission behavior. An FA2 contract
developer MAY chose to implement one or more permission behaviors configuration
that are different from the default ones depending on their business use case.

The FA2 defines the following standard permission behaviors, which configuration
can be chosen independently, when an FA2 contract is implemented:

###### `Operator` Permission Behavior

This permission behavior specifies who is permitted to transfer tokens.

Depending on the configuration, token transfers can be performed by the token owner
or by an operator permitted to transfer specific tokens on behalf of the token owner.
An operator can transfer permitted tokens in any amount on behalf of the owner.

Standard configurations of the operator permission behavior:

```ocaml
type operator_transfer_policy =
  | No_transfer
  | Owner_transfer
  | Owner_or_operator_transfer (* default *)
```

- `No_transfer` - neither owner nor operator can transfer tokens. This permission
  configuration can be used for non-transferable tokens or for the FA2 implementation
  when a transfer can be performed only by some privileged and/or administrative
  account. The transfer operation MUST fail with the error mnemonic `"FA2_TX_DENIED"`.

- `Owner_transfer` - If `SENDER` is not the token owner, the transfer operation
  MUST fail with the error mnemonic `"FA2_NOT_OWNER"`.

- `Owner_or_operator_transfer` - allows transfer for the token owner or an operator
  permitted to manage specific tokens on behalf of the owner. If `SENDER` is not
  the token owner and not an operator permitted to manage tokens to be transferred
  on behalf of the token owner, the transfer operation MUST fail with the error
  mnemonic `"FA2_NOT_OPERATOR"`.
  The FA2 standard defines the entrypoint to manage operators associated with
  the token owner address and specific token IDs (token types)
  ([`update_operators`](#update_operators)). Once an operator is added, it can
  manage permitted token types of the associated owner.

The operation permission behavior also affects [`update_operators`](#update_operators)
entrypoint:

- If an operator transfer is denied (`No_transfer` or `Owner_transfer`),
  [`update_operators`](#update_operators) entrypoint MUST fail if invoked with the
  error mnemonic `"FA2_OPERATORS_UNSUPPORTED"`.

###### `Token Owner Hook` Permission Behavior

Each transfer operation accepts a batch that defines token owners that send tokens
(senders) and token owners that receive tokens (receivers). Token owner contracts
MAY implement `fa2_token_sender` and/or `fa2_token_receiver` interfaces.
Those interfaces define a hook entrypoint that accepts transfer description and
invoked by the FA2 contract in the context of transfer, mint and burn operations.

Standard configurations of the token owner hook permission behavior:

```ocaml
type owner_hook_policy =
  | Owner_no_hook (* default *)
  | Optional_owner_hook
  | Required_owner_hook
```

- `Owner_no_hook` - ignore the owner hook interface.

- `Optional_owner_hook` - treat the owner hook interface as optional. If a token
  owner contract implements a corresponding hook interface, it MUST be invoked. If
  the hook interface is not implemented, it gets ignored.

- `Required_owner_hook` - treat the owner hook interface as required. If a token
  owner contract implements a corresponding hook interface, it MUST be invoked. If
  the hook interface is not implemented, the entire transfer transaction MUST fail.

Token owner hook implementation and semantics:

- Sender and/or receiver hooks can approve the transaction or reject it
  by failing. If such a hook is invoked and failed, the whole transfer operation
  MUST fail.

- This policy can be applied to both token senders and token receivers. There are
  two owner hook interfaces, `fa2_token_receiver` and `fa2_token_sender`, that need
  to be implemented by token owner contracts to expose the token owner's hooks
  to the FA2 token contract.

- If a transfer failed because of the token owner hook permission behavior, the
  operation MUST fail with the one of the following error mnemonics:

| Error Mnemonic                  | Description                                                                                         |
| :------------------------------ | :-------------------------------------------------------------------------------------------------- |
| `"FA2_RECEIVER_HOOK_FAILED"`    | Receiver hook is invoked and failed. This error MUST be raised by the hook implementation           |
| `"FA2_SENDER_HOOK_FAILED"`      | Sender hook is invoked and failed. This error MUST be raised by the hook implementation             |
| `"FA2_RECEIVER_HOOK_UNDEFINED"` | Receiver hook is required by the permission behavior, but is not implemented by a receiver contract |
| `"FA2_SENDER_HOOK_UNDEFINED"`   | Sender hook is required by the permission behavior, but is not implemented by a sender contract     |

- `transfer_descriptor` type defined below can represent regular transfer, mint and
  burn operations.

| operation | `from_`                       | `to_`                           |
| :-------- | :---------------------------- | :------------------------------ |
| transfer  | MUST be `Some sender_address` | MUST be `Some receiver_address` |
| mint      | MUST be `None`                | MUST be `Some receiver_address` |
| burn      | MUST be `Some burner_address` | MUST be `None`                  |

- If all of the following conditions are met, the FA2 contract MUST invoke both
  `fa2_token_sender` and `fa2_token_receiver` entrypoints:

  - the token owner implements both `fa2_token_sender` and `fa2_token_receiver`
    interfaces
  - the token owner receives and sends some tokens in the same transfer operation
  - both sender and receiver hooks are enabled by the FA2 permissions policy

- If the token owner participates in multiple transfers within the transfer operation
  batch and hook invocation is required by the permissions policy, the hook MUST
  be invoked only once.

- The hooks MUST NOT be invoked in the context of the operation other than transfer,
  mint and burn.

- `transfer_descriptor_param.operator` MUST be initialized with the address that
  invoked the FA2 contract (`SENDER`).

A special consideration is required if FA2 implementation supports sender and/or
receiver hooks. It is possible that one of the token owner hooks will fail because
of the hook implementation defects or other circumstances out of control of the
FA2 contract. This situation may cause tokens to be permanently locked on the token
owner's account. One of the possible solutions could be the implementation of a
special administrative version of the mint and burn operations that bypasses owner's
hooks otherwise required by the FA2 contract permissions policy.

```ocaml
type transfer_destination_descriptor =
[@layout:comb]
{
  to_ : address option;
  token_id : token_id;
  amount : nat;
}

type transfer_descriptor =
[@layout:comb]
{
  from_ : address option;
  txs : transfer_destination_descriptor list
}

type transfer_descriptor_param =
[@layout:comb]
{
  batch : transfer_descriptor list;
  operator : address;
}

type fa2_token_receiver =
  | Tokens_received of transfer_descriptor_param

type fa2_token_sender =
  | Tokens_sent of transfer_descriptor_param
```

Michelson definition:

```
(pair
  (list %batch
    (pair
      (option %from_ address)
      (list %txs
        (pair
          (option %to_ address)
          (pair
            (nat %token_id)
            (nat %amount)
          )
        )
      )
    )
  )
  (address %operator)
)
```

##### Transfer Permission Policy Formulae

Each concrete implementation of the transfer permission policy can be described
by a formula which combines permission behaviors in the following form:

```
Operator(operator_config) * Receiver(receiver_config) * Sender(sender_config)
```

For instance, `Operator(Owner_transfer) * Receiver(Owner_no_hook) * Sender(Owner_no_hook)`
formula describes the policy which allows only token owners to transfer their own
tokens.

`Operator(No_transfer) * Receiver(Owner_no_hook) * Sender(Owner_no_hook)` formula
represents non-transferable token (neither token owner, nor operators can transfer
tokens.

Transfer permission policy formula is expressed by the `permissions_descriptor` type.

```ocaml
type operator_transfer_policy =
  | No_transfer
  | Owner_transfer
  | Owner_or_operator_transfer

type owner_hook_policy =
  | Owner_no_hook
  | Optional_owner_hook
  | Required_owner_hook

type custom_permission_policy =
{
  tag : string;
  config_api: address option;
}

type permissions_descriptor =
{
  operator : operator_transfer_policy;
  receiver : owner_hook_policy;
  sender : owner_hook_policy;
  custom : custom_permission_policy option;
}
```

It is possible to extend transfer permission policy with a `custom` behavior,
which does not overlap with already existing standard policies. This standard
does not specify exact types for custom config entrypoints. FA2 token contract
clients that support custom config entrypoints must know their types a priori
and/or use a `tag` hint of `custom_permission_policy`.

##### Customizing Transfer Permission Policy

The FA2 contract MUST always implement the
[core transfer behavior](#core-transfer-behavior).
However, FA2 contract developer MAY chose to implement either the
[default transfer permission policy](#default-transfer-permission-policy) or a
custom policy.
The FA2 contract implementation MAY customize one or more of the standard permission
behaviors (`operator`, `receiver`, `sender` as specified in `permissions_descriptor`
type), by choosing one of the available options for those permission behaviors.

The composition of the described behaviors can be described as
`Core_Transfer_Behavior AND (Default_transfer_permission_policy OR Custom_Transfer_Permission_Policy)`

##### Exposing Permissions Descriptor

In order to advertise its permissions, an FA2 should fill the `"permissions"`
field in its contract metadata.

The field is an object with 4 fields corresponding to the Ligo types defined in
the previous sections:

- `"operator"` is `"no-transfer"`, `"owner-transfer"`, or
  `"owner-or-operator-transfer"`.
- `"receiver"` is`"owner-no-hook"`, `"optional-owner-hook"`, or
  `"required-owner-hook"`.
- `"sender"` is `"owner-no-hook"`, `"optional-owner-hook"`, or
  `"required-owner-hook"`.
- `"custom"` is an optional object `{ "tag": <string>, "config-api": <string> }`
  where `"config-api"` is an optional contract adddress.

The implicit value of the field corresponding to the
[default `transfer` permission policy](#default-transfer-permission-policy) is
the following:

```json
{
  "operator": "owner-or-operator-transfer",
  "receiver": "owner-no-hook",
  "sender": "owner-no-hook"
}
```

### Error Handling

This specification defines the set of standard errors to make it easier to integrate
FA2 contracts with wallets, DApps and other generic software, and enable
localization of user-visible error messages.

Each error code is a short abbreviated string mnemonic. An FA2 contract client
(like another contract or a wallet) could use on-the-chain or off-the-chain registry
to map the error code mnemonic to a user-readable, localized message. A particular
implementation of the FA2 contract MAY extend the standard set of errors with custom
mnemonics for additional constraints.

Standard error mnemonics:

| Error mnemonic                  | Description                                                                                                                                              |
| :------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `"FA2_TOKEN_UNDEFINED"`         | One of the specified `token_id`s is not defined within the FA2 contract                                                                                  |
| `"FA2_INSUFFICIENT_BALANCE"`    | A token owner does not have sufficient balance to transfer tokens from owner's account                                                                   |
| `"FA2_TX_DENIED"`               | A transfer failed because of `operator_transfer_policy == No_transfer`                                                                                   |
| `"FA2_NOT_OWNER"`               | A transfer failed because `operator_transfer_policy == Owner_transfer` and it is invoked not by the token owner                                          |
| `"FA2_NOT_OPERATOR"`            | A transfer failed because `operator_transfer_policy == Owner_or_operator_transfer` and it is invoked neither by the token owner nor a permitted operator |
| `"FA2_OPERATORS_UNSUPPORTED"`   | `update_operators` entrypoint is invoked and `operator_transfer_policy` is `No_transfer` or `Owner_transfer`                                             |
| `"FA2_RECEIVER_HOOK_FAILED"`    | The receiver hook failed. This error MUST be raised by the hook implementation                                                                           |
| `"FA2_SENDER_HOOK_FAILED"`      | The sender failed. This error MUST be raised by the hook implementation                                                                                  |
| `"FA2_RECEIVER_HOOK_UNDEFINED"` | Receiver hook is required by the permission behavior, but is not implemented by a receiver contract                                                      |
| `"FA2_SENDER_HOOK_UNDEFINED"`   | Sender hook is required by the permission behavior, but is not implemented by a sender contract                                                          |

If more than one error conditions are met, the entrypoint MAY fail with any applicable
error.

When an error occurs, any FA2 contract entrypoint MUST fail with one of the following
types:

1. `string` value which represents an error code mnemonic.
2. a Michelson `pair`, where the first element is a `string` representing error code
   mnemonic and the second element is a custom error data.

Some FA2 implementations MAY introduce their custom errors that MUST follow the
same pattern as standard ones: define custom error mnemonics and fail with one
of the error types defined above.

## Implementing Different Token Types With FA2

The FA2 interface is designed to support a wide range of token types and implementations.
This section gives examples of how different types of the FA2 contracts MAY be
implemented and what are the expected properties of such an implementation.

### Single Fungible Token

An FA2 contract represents a single token similar to ERC-20 or FA1.2 standards.

| Property        |   Constrains   |
| :-------------- | :------------: |
| `token_id`      |  Always `0n`   |
| transfer amount | natural number |
| account balance | natural number |
| total supply    | natural number |
| decimals        |     custom     |

### Multiple Fungible Tokens

An FA2 contract may represent multiple tokens similar to ERC-1155 standard.
The implementation can have a fixed predefined set of supported tokens or tokens
can be created dynamically.

| Property        |         Constrains          |
| :-------------- | :-------------------------: |
| `token_id`      |       natural number        |
| transfer amount |       natural number        |
| account balance |       natural number        |
| total supply    |       natural number        |
| decimals        | custom, per each `token_id` |

### Non-fungible Tokens

An FA2 contract may represent non-fungible tokens (NFT) similar to ERC-721 standard.
For each individual non-fungible token the implementation assigns a unique `token_id`.
The implementation MAY support either a single kind of NFTs or multiple kinds.
If multiple kinds of NFT is supported, each kind MAY be assigned a continuous range
of natural number (that does not overlap with other ranges) and have its own associated
metadata.

| Property        |                           Constrains                            |
| :-------------- | :-------------------------------------------------------------: |
| `token_id`      |                         natural number                          |
| transfer amount |                          `0n` or `1n`                           |
| account balance |                          `0n` or `1n`                           |
| total supply    |                          `0n` or `1n`                           |
| decimals        | `0n` or a natural number if a token represents a batch of items |

For any valid `token_id` only one account CAN hold the balance of one token (`1n`).
The rest of the accounts MUST hold zero balance (`0n`) for that `token_id`.

### Mixing Fungible and Non-fungible Tokens

An FA2 contract MAY mix multiple fungible and non-fungible tokens within the same
contract similar to ERC-1155. The implementation MAY chose to select individual
natural numbers to represent `token_id` for fungible tokens and continuous natural
number ranges to represent `token_id`s for NFTs.

| Property        |                         Constrains                          |
| :-------------- | :---------------------------------------------------------: |
| `token_id`      |                       natural number                        |
| transfer amount | `0n` or `1n` for NFT and natural number for fungible tokens |
| account balance | `0n` or `1n` for NFT and natural number for fungible tokens |
| total supply    | `0n` or `1n` for NFT and natural number for fungible tokens |
| decimals        |                           custom                            |

### Non-transferable Tokens

Either fungible and non-fungible tokens can be non-transferable. Non-transferable
tokens can be represented by the FA2 contract which [operator transfer behavior](#operator-transfer-behavior)
is defined as `No_transfer`. Tokens cannot be transferred either by the token owner
or by any operator. Only privileged operations like mint and burn can assign tokens
to owner accounts.

## Legacy Interface

Contracts which for historical reasons do not implement [TZIP-16 Contract
Metadata](#tzip-16-contract-metadata) are expected to have implemented the
interface in this section (now deprecated).

### Token Metadata

Each FA2 `token_id` has associated metadata of the following type:

```ocaml
type token_id = nat

type token_metadata =
{
  token_id : token_id;
  symbol : string;
  name : string;
  decimals : nat;
  extras : (string, bytes) map;
}
```

- FA2 token amounts are represented by natural numbers (`nat`), and their
  **granularity** (the smallest amount of tokens which may be minted, burned, or
  transferred) is always 1.
- `decimals` is the number of digits to use after the decimal point when displaying
  the token amounts. If 0, the asset is not divisible. Decimals are used for display
  purposes only and MUST NOT affect transfer operation.

Examples:

| Decimals | Amount | Display |
| -------- | ------ | ------- |
| 0        | 123    | 123     |
| 1        | 123    | 12.3    |
| 3        | 123000 | 123     |



- The Legacy-FA2 contract MUST implement `token_metadata_registry` view
  entrypoint that returns an address of the contract holding tokens
  metadata. Token metadata can be held either by the FA2 token contract itself
  (then `token_metadata_registry` returns `SELF` address) or by a separate token
  registry contract.
- Token registry contract MUST implement one of two ways to expose token
  metadata for off-chain clients:
   - Contract storage MUST have a `big_map` that maps `token_id ->
     token_metadata` and annotated `%token_metadata`
   - Contract MUST implement entrypoint `token_metadata`
   
All entry-points rely on the Michelson type of the token metadata:

```
(pair
  (nat %token_id)
  (pair
    (string %symbol)
    (pair
      (string %name)
      (pair
        (nat %decimals)
        (map %extras string bytes)
  ))))
```

A previous version of this specification used a `(map %extras string string)`,
the `string` was changed to `bytes` to allow arbitrary values, and not be
limited by Michelson's allowed characters.

###### `token_metadata_registry`

LIGO definition:

```ocaml
| Token_metadata_registry of address contract
```

Michelson definition:

```
(contract %token_metadata_registry address)
```

Returns address of the contract that holds tokens metadata. If the FA2 contract
holds its own tokens metadata, the entrypoint returns `SELF` address. The entry
point parameter is some contract entrypoint to be called with the address of the
token metadata registry.

###### `token_metadata` `big_map`

LIGO definition:

```ocaml
type <contract_storage> = {
  ...
  token_metadata : (token_id, token_metadata) big_map;
  ...
}
```

Michelson definition:

```
(big_map %token_metadata
  nat
  (pair
  (nat %token_id)
  (pair
    (string %symbol)
    (pair
      (string %name)
      (pair
        (nat %decimals)
        (map %extras string bytes)
  ))))
)
```

The FA2 contract storage MUST have a `big_map` with a key type `token_id` and
value type `token_metadata`. This `big_map` MUST be annotated as `%token_metadata`
and can be at any position within the storage.

###### `token_metadata` Entrypoint

LIGO definition:

```ocaml
type token_metadata_param =
[@layout:comb]
{
  token_ids : token_id list;
  handler : (token_metadata list) -> unit;
}

| Token_metadata of token_metadata_param
```

Michelson definition:

```
(pair %token_metadata
  (list %token_ids nat)
  (lambda %handler
      (list
        (pair
          (nat %token_id)
          (pair
            (string %symbol)
            (pair
              (string %name)
              (pair
                (nat %decimals)
                (map %extras string bytes)
        ))))
      )
      unit
  )
)
```

</details>

Get the metadata for multiple token types. Accepts a list of `token_id`s and a
a lambda `handler`, which accepts a list of `token_metadata` records. The `handler`
lambda may assert certain assumptions about the metadata and/or fail with the
obtained metadata implementing a view entrypoint pattern to extract tokens metadata
off-chain.

- As with `balance_of`, the input `token_id`'s should not be deduplicated nor
  reordered.

- If one of the specified `token_id`s is not defined within the FA2 contract, the
  entrypoint MUST fail with the error mnemonic `"FA2_TOKEN_UNDEFINED"`.

### Permissions Descriptor Entrypoint

To advertise the permissions policy, a contract SHOULD have a
`%permissions_descriptor` “callback-view” entrypoint with the following
interface.

Michelson definition:

```
(contract %permissions_descriptor
  (pair
    (or %operator
      (unit %no_transfer)
      (or
        (unit %owner_transfer)
        (unit %owner_or_operator_transfer)
      )
    )
    (pair
      (or %receiver
        (unit %owner_no_hook)
        (or
          (unit %optional_owner_hook)
          (unit %required_owner_hook)
        )
      )
      (pair
        (or %sender
          (unit %owner_no_hook)
          (or
            (unit %optional_owner_hook)
            (unit %required_owner_hook)
          )
        )
        (option %custom
          (pair
            (string %tag)
            (option %config_api address)
          )
        )
      )
    )
  )
)
```



## Future Directions

Future amendments to Tezos are likely to enable new functionality by which this
standard can be upgraded. Namely, [read-only
calls](https://forum.tezosagora.org/t/adding-read-only-calls/1227), event logging,
and [contract signatures](https://forum.tezosagora.org/t/contract-signatures/1458), now known as "tickets".

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

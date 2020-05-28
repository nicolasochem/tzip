---
tzip: 12
title: FA2 - Multi-Asset Interface
status: Draft
type: Financial Application (FA)
author: Eugene Mishura (@e-mishura)
created: 2020-01-24
---

## Table Of Contents

* [Summary](#summary)
* [Motivation](#motivation)
* [Abstract](#abstract)
* [Interface Specification](#interface-specification)
  * [Entry Point Semantics](#entry-point-semantics)
    * [`transfer`](#transfer)
    * [`balance_of`](#balance_of)
    * [`total_supply`](#total_supply)
    * [`token_metadata`](#token_metadata)
    * [`permissions_descriptor`](#permissions_descriptor)
    * [Operators](#operators)
      * [`update_operators`](#update_operators)
      * [`is_operator`](#is_operator)
  * [Error Handling](#error-handling)
  * [FA2 Permission Policies and Configuration](#fa2-permission-policies-and-configuration)
    * [A Taxonomy of Permission Policies](#a-taxonomy-of-permission-policies)
      * [Core Transfer Behavior](#core-transfer-behavior)
      * [Behavior Patterns](#behavior-patterns)
        * [`Operator` Transfer Behavior](#operator-transfer-behavior)
        * [`Token Owner Hook` Permission Behavior](#token-owner-hook-permission-behavior)
      * [Permission Policy Formulae](#permission-policy-formulae)
* [Future directions](#future-directions)
* [Copyright](#copyright)

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
permission policies can be used to define how many tokens can be transferred, who
can initiate a transfer, and who can receive tokens. A token contract can be
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

Token type is uniquely identified on the chain by a pair composed of the token
contract address and token ID, a natural number (`nat`). If the underlying contract
implementation supports only a single token type (e.g. ERC-20-like contract),
the token ID MUST be `0n`. In the case, when multiple token types are supported
within the same FA2 token contract (e. g. ERC-1155-like contract), the contract
is fully responsible for assigning and managing token IDs. FA2 clients MUST NOT
depend on particular ID values to infer information about a token.

Most of the entry points are batch operations that allow querying or transfer of
multiple token types atomically. If the underlying contract implementation supports
only a single token type, the batch may contain single or multiple entries where
token ID will be a fixed `0n` value. Likewise, if multiple token types are supported,
the batch may contain zero or more entries and there may be duplicate token IDs.

Most token standards specify logic that validates a transfer transaction and can
either approve or reject a transfer. Such logic could validate who initiates a
transfer, the transfer amount, and who can receive tokens. This standard calls such
logic a *permission policy* or *permission behavior*. Unlike many other standards,
FA2 defines the default core transfer behavior, that MUST always be implemented
(see [Core Transfer Behavior](#core-transfer-behavior)), and a set of predefined
permission policies that are optional (see
[FA2 Permission Policies and Configuration](#fa2-permission-policies-and-configuration)).
A particular FA2 contract implementation MAY choose which optional policies to
implement. Selected permission policies are applied to all tokens and token owners
managed by the FA2 contract.

The FA2 defines the following standard permission policies, that can be chosen
independently, when an FA2 contract is implemented:

* `operator_transfer_policy` - defines who can transfer tokens. Tokens can be
transferred by the token owner or an operator (some address that is authorized to
transfer tokens on behalf of the token owner). A special case is when neither owner
nor operator can transfer tokens (can be used for non-transferable tokens). The
FA2 standard defines two entry points to manage and inspect operators associated
with the token owner address ([`update_operators`](#update_operators),
[`is_operator`](#is_operator)). Once an operator is added, it can manage all of
its associated owner's tokens.
* `owner_hook_policy` - defines if sender/receiver hooks should be called or
not. Each token owner contract MAY implement either an `fa2_token_sender` or
`fa2_token_receiver` hook interface. Those hooks MAY be called when a transfer sends
tokens from the owner account or the owner receives tokens. The hook can either
accept a transfer transaction or reject it by failing.

The FA2 standard defines a special metadata entry point ([`permissions_descriptor`](#permissions_descriptor))
that returns a *permissions descriptor* record. The permission descriptor indicates
which standard permission policies are implemented by the FA2 contract and can be
used by off-chain and on-chain tools to discover the properties of the particular
FA2 contract implementation.

This specification defines the set of [standard errors](#error-handling) and error
mnemonics to be used when implementing FA2. However, some implementation MAY
introduce their custom error that MUST follow the same pattern as standard ones.

## Interface Specification

Token contract implementing the FA2 standard MUST have the following entry points.
Notation is given in [cameLIGO language](https://ligolang.org) for readability
and Michelson. The LIGO definition, when compiled, generates compatible Michelson
entry points.

`type fa2_entry_points =`

* [`| Transfer of transfer list`](#transfer)
* [`| Balance_of of balance_of_param`](#balance_of)
* [`| Total_supply of total_supply_param`](#total_supply)
* [`| Token_metadata of token_metadata_param`](#token_metadata)
* [`| Permissions_descriptor of permissions_descriptor contract`](#permissions_descriptor)
* [`| Update_operators of update_operator list`](#update_operators)
* [`| Is_operator of is_operator_param`](#is_operator)

The full definition of the FA2 entry points and related types can be found in
[fa2_interface.mligo](./fa2_interface.mligo).

### Entry Point Semantics

#### `transfer`

LIGO definition:

```ocaml
type token_id = nat

type transfer_destination = {
  to_ : address;
  token_id : token_id;
  amount : nat;
}

type transfer = {
  from_ : address;
  txs : transfer_destination list;
}

| Transfer of transfer_michelson list
```

where

```ocaml
type transfer_destination_michelson = transfer_destination michelson_pair_right_comb

type transfer_aux = {
  from_ : address;
  txs : transfer_destination_michelson list;
}

type transfer_michelson = transfer_aux michelson_pair_right_comb
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
a list of destination addresses (`to_`). Each `transfer_destination` specifies
token type and amount to be transferred from the source addresses.
Transfers MUST happen atomically and in order; if at least one specified transfer
cannot be completed, the whole transaction MUST fail.

The transaction MUST fail if the balance(s) of the holder for token(s) in the
batch is lower than the corresponding amount(s) sent. If the holder does not hold
any tokens of type `token_id`, the holder's balance is interpreted as zero.

Transfer implementations MUST apply permission policy logic. If permission logic
rejects a transfer, the whole operation MUST fail.

A transfer operation MUST update token owners' balances exactly as the parameters
of the operation specify it. Transfer operations MUST NOT try to adjust transfer
amounts or try to add/remove additional transfers like transaction fees.

FA2 does NOT specify an interface for mint and burn operations; however, if an
FA2 token contract implements mint and burn operations, it SHOULD, when possible,
enforce the same rules and logic applied to the token transfer operation. Mint
and burn can be considered special cases of the transfer. Although, it is possible
that mint and burn have more or less restrictive rules than regular transfer.

For instance, mint and burn operations may be initiated by a special privileged
administrative address only. In this case, regular operator restrictions may not
be applicable.

A special consideration is required if FA2 implementation supports sender and/or
receiver hooks (see [`Token Owner` Permission Behavior](#token-owner-permission-behavior)).
It is possible that one of the token owner hooks will fail because of the hook
implementation defects or other circumstances out of control of the FA2 contract.
This situation may cause tokens to be permanently locked on the token owner's account.
One of the possible solutions could be the implementation of a special administrative
version of the mint and burn operations that bypasses owner's hooks otherwise required
by the FA2 contract permissions policy.

If one of the specified `token_id`s is not defined within the FA2 contract, the
entry point MUST fail with the error mnemonic `"TOKEN_UNDEFINED"`.

If one of the token owners does not have sufficient balance to transfer tokens from
that account, the entry point MUST fail with the error mnemonic `"INSUFFICIENT_BALANCE"`.

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

type balance_of_param = {
  requests : balance_of_request list;
  callback : (balance_of_response_michelson list) contract;
}

| Balance_of of balance_of_param_michelson
```

where

```ocaml
type balance_of_request_michelson = balance_of_request michelson_pair_right_comb

type balance_of_response_aux = {
  request : balance_of_request_michelson;
  balance : nat;
}

type balance_of_response_michelson = balance_of_response_aux michelson_pair_right_comb

type balance_of_param_aux = {
  requests : balance_of_request_michelson list;
  callback : (balance_of_response_michelson list) contract;
}

type balance_of_param_michelson = balance_of_param_aux michelson_pair_right_comb
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

Get the balance of multiple account/token pairs. Accepts a list of
`balance_of_request`s and a callback contract `callback` which accepts a list of
`balance_of_response` records. There may be duplicate `balance_of_request`'s,
in which case they should not be deduplicated nor reordered. If the account does
not hold any tokens, the account balance is interpreted as zero.

If one of the specified `token_id`s is not defined within the FA2 contract, the
entry point MUST fail with the error mnemonic `"TOKEN_UNDEFINED"`.

#### `total_supply`

LIGO definition:

```ocaml
type token_id = nat

type total_supply_response = {
  token_id : token_id;
  total_supply : nat;
}

type total_supply_param = {
  token_ids : token_id list;
  callback : (total_supply_response_michelson list) contract;
}

| Total_supply of total_supply_param_michelson
```

where

```ocaml
type total_supply_response_michelson = total_supply_response michelson_pair_right_comb

type total_supply_param_michelson = total_supply_param michelson_pair_right_comb
```

Michelson definition:

```
(pair %total_supply
  (list %token_ids nat)
  (contract %callback
    (list
      (pair
        (nat %token_id)
        (nat %total_supply)
      )
    )
  )
)
```

Get the total supply for multiple token types. Accepts a list of
`token_id`s and a callback contract `callback`, which accepts a list
of `total_supply_response` records. There may be duplicate `token_id`'s in the
request, in which case they should not be deduplicated nor reordered.

If one of the specified `token_id`s is not defined within the FA2 contract, the
entry point MUST fail with the error mnemonic `"TOKEN_UNDEFINED"`.

#### `token_metadata`

LIGO definition:

```ocaml
type token_id = nat

type token_metadata = {
  token_id : token_id;
  symbol : string;
  name : string;
  decimals : nat;
  extras : (string, string) map;
}

type token_metadata_param = {
  token_ids : token_id list;
  callback : (token_metadata_michelson list) contract;
}

| Token_metadata of token_metadata_param_michelson
```

where

```ocaml
type token_metadata_michelson = token_metadata michelson_pair_right_comb

type token_metadata_param_michelson = token_metadata_param michelson_pair_right_comb
```

Michelson definition:

```
(pair %token_metadata
  (list %token_ids nat)
  (contract %callback
    (list
      (pair
        (nat %token_id)
        (pair
          (string %symbol)
          (pair
            (string %name)
            (pair
              (nat %decimals)
              (map %extras string string)
      ))))
    )
  )
)
```

Get the metadata for multiple token types. Accepts a list of `token_id`s and a
callback contract `callback`, which accepts a list of `token_metadata` records.
As with `balance_of`, the input `token_id`'s should not be deduplicated nor
reordered.

If one of the specified `token_id`s is not defined within the FA2 contract, the
entry point MUST fail with the error mnemonic `"TOKEN_UNDEFINED"`.

FA2 token amounts are represented by natural numbers (`nat`), and their
**granularity** (the smallest amount of tokens which may be minted, burned, or
transferred) is always 1.

`decimals` is the number of digits to use after the decimal point when displaying
the token amounts. If 0, the asset is not divisible. Decimals are used for display
purposes only and MUST NOT affect transfer operation.

Examples

| Decimals | Amount  | Display  |
| -------- | ------- | -------- |
| 0n       | 123     | 123      |
| 1n       | 123     | 12.3     |
| 3n       | 123000  | 123      |

#### `permissions_descriptor`

LIGO definition:

```ocaml
type operator_transfer_policy =
  | No_transfer
  | Owner_transfer
  | Owner_or_operator_transfer

type owner_hook_policy =
  | Owner_no_hook
  | Optional_owner_hook
  | Required_owner_hook

type custom_permission_policy = {
  tag : string;
  config_api: address option;
}

type permissions_descriptor = {
  operator : operator_transfer_policy;
  receiver : owner_hook_policy;
  sender : owner_hook_policy;
  custom : custom_permission_policy option;
}

| Permissions_descriptor of permissions_descriptor_michelson contract
```

where

```ocaml
type operator_transfer_policy_michelson = operator_transfer_policy michelson_or_right_comb

type owner_hook_policy_michelson = owner_hook_policy michelson_or_right_comb

type custom_permission_policy_michelson = custom_permission_policy michelson_pair_right_comb

type permissions_descriptor_aux = {
  operator : operator_transfer_policy_michelson;
  receiver : owner_hook_policy_michelson;
  sender : owner_hook_policy_michelson;
  custom : custom_permission_policy_michelson option;
}

type permissions_descriptor_michelson = permissions_descriptor_aux michelson_pair_right_comb
```

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

Get the descriptor of the transfer permission policy. FA2 specifies
`permissions_descriptor` allowing external contracts (e.g. an auction) to discover
an FA2 contract's implemented permission policies and to configure it. For more
details see
[FA2 Permission Policies and Configuration](#fa2-permission-policies-and-configuration).

The FA2 contract MAY also implement an optional custom permissions policy. If such
custom a policy is implemented, the FA2 contract SHOULD expose it using permissions
descriptor `custom` field by giving it a `tag` that would be available to other
parties which are aware of such custom extension. Some some custom permission MAY
require a config API (like [`update_operators`](#update_operators),
[`is_operator`](#is_operator) entry point of the FA2 to configure `operator_transfer_policy`).
Config entry points may be implemented either within the FA2 token contract itself
(then the returned address SHALL be `SELF`), or in a separate contract (see
recommended implementation pattern using [transfer hook](./implementing-fa2.md#transfer-hook)).

#### Operators

**Operator** is a Tezos address that initiates token transfer operation on behalf
of the owner.

**Owner** is a Tezos address which can hold tokens.

An operator, other than the owner, MUST be approved to manage particular token types
held by the owner to make a transfer from the owner account.

FA2 interface specifies two entry points to update and inspect operators. Once
permitted for the specific token owner, an operator can transfer any tokens belonging
to the owner.

##### `update_operators`

LIGO definition:

```ocaml
type operator_param = {
  owner : address;
  operator : address;
}

type update_operator =
  | Add_operator_p of operator_param
  | Remove_operator_p of operator_param

| Update_operators of update_operator_michelson list
```

where

```ocaml
type operator_param_michelson = operator_param michelson_pair_right_comb

type update_operator_aux =
  | Add_operator of operator_param_michelson
  | Remove_operator of operator_param_michelson

type update_operator_michelson = update_operator_aux michelson_or_right_comb
```

Michelson definition:

```
(list %update_operators
  (or
    (pair %add_operator
      (address %owner)
      (address %operator)
    )
    (pair %remove_operator
      (address %owner)
      (address %operator)
    )
  )
)
```

Add or Remove token operators for the specified owners.

The entry point accepts a list of `update_operator` commands. If two different
commands in the list add and remove an operator for the same owner,
the last command in the list MUST take effect.

It is possible to update operators for a token owner that does not hold any token
balances yet.

Operator relation is not transitive. If C is an operator of B , and if B is an
operator of A, C cannot transfer tokens that are owned by A, on behalf of B.

The standard does not specify who is permitted to update operators on behalf of
the token owner. Depending on the business use case, the particular implementation
of FA2 contract MAY limit operator updates to a token owner (`owner == SENDER`)
or be limited to an administrator.

##### `is_operator`

LIGO definition:

```ocaml
type operator_param = {
  owner : address;
  operator : address;
}

type is_operator_response = {
  operator : operator_param;
  is_operator : bool;
}

type is_operator_param = {
  operator : operator_param;
  callback : (is_operator_response_michelson) contract;
}

| Is_operator of is_operator_param_michelson
```

where

```ocaml
type operator_param_michelson = operator_param michelson_pair_right_comb

type is_operator_response_aux = {
  operator : operator_param_michelson;
  is_operator : bool;
}

type is_operator_response_michelson = is_operator_response_aux michelson_pair_right_comb

type is_operator_param_aux = {
  operator : operator_param_michelson;
  callback : (is_operator_response_michelson) contract;
}

type is_operator_param_michelson = is_operator_param_aux michelson_pair_right_comb
```

Michelson definition:

```
(pair %is_operator
  (pair %operator
    (address %owner)
    (address %operator)
  )
  (contract %callback
    (pair
      (pair %operator
        (address %owner)
        (address %operator)
      )
      (bool %is_operator)
    )
  )
)
```

Inspect if an address is an operator for the specified owner.

### Error Handling

This specification defines the set of standard errors to make it easier to integrate
FA2 contracts with wallets, DApps and other generic software, and enable
localization of user-visible error messages.

Each error code is a short abbreviated string mnemonic. An FA2 contract client
(like another contract or a wallet) could use on-the-chain or off-the-chain registry
to map the error code mnemonic to a user-readable, localized message. A particular
implementation of the FA2 contract MAY extend the standard set of errors with custom
mnemonics for additional constraints.

When error occurs, any FA2 contract entry point MUST fail with one of the following
types:

1. `string` value which represents an error code mnemonic.
2. a Michelson `pair`, where the first element is a `string` representing error code
mnemonic and the second element is a custom error data.

Standard error mnemonics:

| Error mnemonic | Description |
| :------------- | :---------- |
| `"TOKEN_UNDEFINED"` | One of the specified `token_id`s is not defined within the FA2 contract |
| `"INSUFFICIENT_BALANCE"` | A token owner does not have sufficient balance to transfer tokens from owner's account|
| `"TX_DENIED"` | A transfer failed because of `operator_transfer_policy == No_transfer` |
| `"NOT_OWNER"` | A transfer failed because `operator_transfer_policy == Owner_transfer` and it is initiated not by the token owner |
| `"NOT_OPERATOR"` | A transfer failed because `operator_transfer_policy == Owner_or_operator_transfer` and it is initiated neither by the token owner nor a permitted operator |
| `"RECEIVER_HOOK_FAILED"` | The receiver hook failed. This error MUST be raised by the hook implementation |
| `"SENDER_HOOK_FAILED"` | The sender failed. This error MUST be raised by the hook implementation |
| `"RECEIVER_HOOK_UNDEFINED"` | Receiver hook is required by the permission behavior, but is not implemented by a receiver contract |
| `"SENDER_HOOK_UNDEFINED"` | Sender hook is required by the permission behavior, but is not implemented by a sender contract |  

If more than one error conditions are met, the entry point MAY fail with any applicable
error.

### FA2 Permission Policies and Configuration

Most token standards specify logic such as who can initiate a transfer, the quantity
for transfer, who can receive tokens. This standard calls such logic *permission
policy* and defines a framework to compose and configure such permission policies
from the standard behaviors and configuration APIs.

A particular permission policy defines the semantics (logic that defines if a
transfer operation is permitted or not) and MAY require additional internal data
(for example, operators). If the permission policy requires additional internal
data, it also requires the standard configuration API to manage that data.

Often, proposed token standards specify either a single policy (e.g. allowances in
ERC-20) or multiple non-compatible policies. (e.g. ERC-777, which has both allowance
and operator APIs and two versions of the transfer entry point, one that invokes
sender/receiver hooks and one which does not).

FA2 specifies an interface `permissions_descriptor` allowing external contracts
(e.g. an auction) to discover an FA2 contract's permission policy and to configure
it. `permissions_descriptor` serves as a modular alternative to the existing
approaches in ERC-20 or FA1.2 and helps to define consistent and
non-self-contradictory policies.

#### A Taxonomy of Permission Policies

Permission policy semantics are composed from several orthogonal behavior patterns.
The concrete policy is expressed as a combination of those behaviors.

The proposed taxonomy framework and API allows other contracts to discover the
properties (behaviors) of the particular FA2 token contract permission policy and
to configure it on the chain.

##### Core Transfer Behavior

FA2 token contracts MUST implement this behavior. The rest of permission behaviors
are OPTIONAL.

* Every transfer operation MUST be atomic. If the operation fails, all token
  transfers MUST be reverted, and token balances MUST remain unchanged.

* The amount of a token transfer MUST NOT exceed the existing token owner's
  balance. If the transfer amount for the particular token type and token owner
  exceeds the existing balance, the whole transfer operation MUST fail with the
  error mnemonic `"INSUFFICIENT_BALANCE"`

* Core transfer behavior MAY be extended. If additional constraints on tokens
  transfer are required, FA2 token contract implementation MAY invoke additional
  permission policies. If the additional permission fails, the whole transfer
  operation MUST fail with a custom error mnemonic.

* Core transfer behavior MUST update token balances exactly as the operation
  parameters specify it. No changes to amount values or additional transfers are
  allowed.

##### Behavior Patterns

These behavior patterns (or permission policies) are OPTIONAL. An FA2 contract
developer MAY chose to implement some or all of those permission policies, depending
on their business use case. The FA2 contract MUST expose what policies are
implemented using [`permissions_descriptor`](#permissions_descriptor) entry point.

###### `Operator` Transfer Behavior

This behavior specifies who can initiate a token transfer. Potentially token transfers
can be initiated by the token owner or by an operator permitted to transfer tokens
on behalf of the token owner. An operator can transfer any tokens in any amount on
behalf of the owner.

```ocaml
type operator_transfer_policy =
  | No_transfer
  | Owner_transfer
  | Owner_or_operator_transfer
```

FA2 interface provides API to configure operators (see [operators config entry
points](#operators)). If an operator transfer is denied, those entry points MUST
fail if invoked.

If the operator policy is `No_transfer`, the transfer operation MUST fail with
the error mnemonic `"TX_DENIED"`. This permission mode can be used for non-transferable
tokens or for the FA2 implementation when a transfer can be initiated only by some
privileged and/or administrative account.

If the operator policy is `Owner_transfer` and `SENDER` is not the token owner,
the transfer operation MUST fail with the error mnemonic `"NOT_OWNER"`.

If the operator policy is `Owner_or_operator_transfer` and `SENDER` is not the
token owner and does not have permissions to transfer specified tokens, the transfer
operation MUST fail with the error mnemonic `"NOT_OPERATOR"`.

###### `Token Owner Hook` Permission Behavior

Each transfer operation defines both a set of token owners that send tokens
(senders) and a set of token owners that receive tokens (receivers). Token owner
contracts MAY implement either an `fa2_token_sender` or `fa2_token_receiver` hook
interface. Permission behavior MAY call sender and/or receiver hooks which can
approve the transaction or reject it by failing. If such a hook is invoked and
failed, the whole transfer operation MUST fail. Token owner permission may be
configured to behave in one of the following ways:

* Ignore the owner hook interface.

* Treat the owner hook interface as optional. If a token owner contract
  implements a corresponding hook interface, it gets invoked. If the hook interface
  is not implemented, it gets ignored.

* Treat the owner hook interface as required. If a token owner contract
  implements a corresponding hook interface, it gets invoked. If the hook interface
  is not implemented, the entire transfer transaction gets rejected.

Token owner behavior is defined as follows:

```ocaml
type owner_hook_policy =
  | Owner_no_hook
  | Optional_owner_hook
  | Required_owner_hook
```

This policy can be applied to both token senders and token receivers. There are
two owner hook interfaces, `fa2_token_receiver` and `fa2_token_sender`, that need
to be implemented by token owner contracts to expose the owner's hooks to FA2 token
contract.

```ocaml
type transfer_destination_descriptor = {
  to_ : address option;
  token_id : token_id;
  amount : nat;
}

type transfer_descriptor = {
  from_ : address option;
  txs : transfer_destination_descriptor list
}

type transfer_descriptor_param = {
  fa2 : address;
  batch : transfer_descriptor list;
  operator : address;
}

type fa2_token_receiver =
  | Tokens_received of transfer_descriptor_param_michelson

type fa2_token_sender =
  | Tokens_sent of transfer_descriptor_param_michelson
```

where

```ocaml
type transfer_destination_descriptor_michelson =
  transfer_destination_descriptor michelson_pair_right_comb

type transfer_descriptor_aux = {
  from_ : address option;
  txs : transfer_destination_descriptor_michelson list
}

type transfer_descriptor_michelson = transfer_descriptor_aux michelson_pair_right_comb

type transfer_descriptor_param_aux = {
  fa2 : address;
  batch : transfer_descriptor_michelson list;
  operator : address;
}

type transfer_descriptor_param_michelson = transfer_descriptor_param_aux michelson_pair_right_comb
```

If a transfer failed because of the token owner permission behavior, the operation
MUST fail with the one of the following error mnemonics:

| Error Mnemonic | Description |
| :------------- | :---------- |
| `"RECEIVER_HOOK_FAILED"` | Receiver hook is invoked and failed. This error MUST be raised by the hook implementation |
| `"SENDER_HOOK_FAILED"` | Sender hook is invoked and failed. This error MUST be raised by the hook implementation |
| `"RECEIVER_HOOK_UNDEFINED"` | Receiver hook is required by the permission behavior, but is not implemented by a receiver contract |
| `"SENDER_HOOK_UNDEFINED"` | Sender hook is required by the permission behavior, but is not implemented by a sender contract |

##### Permission Policy Formulae

Each concrete implementation of the permission policy can be described by a formula
which combines permission behaviors in the following form:

```
Operator(?) * Receiver(?) * Sender(?)
```

For instance, `Operator(Owner_transfer) * Receiver(Owner_no_hook) * Sender(Owner_no_hook)`
formula describes the policy which allows only token owners to transfer their own
tokens.

`Operator(No_transfer) * Receiver(Owner_no_hook) * Sender(Owner_no_hook)` formula
represents non-transferable token (neither token owner, nor operators can transfer
tokens.

Permission token policy formula is expressed by the `permissions_descriptor`
returned by the [`permissions_descriptor`](#permissions_descriptor) entry point.

```ocaml
type operator_transfer_policy =
  | No_transfer
  | Owner_transfer
  | Owner_or_operator_transfer

type owner_hook_policy =
  | Owner_no_hook
  | Optional_owner_hook
  | Required_owner_hook

type custom_permission_policy = {
  tag : string;
  config_api: address option;
}

type permissions_descriptor = {
  operator : operator_transfer_policy;
  receiver : owner_hook_policy;
  sender : owner_hook_policy;
  custom : custom_permission_policy option;
}
```

It is possible to extend permission policy with a `custom` behavior, which does
not overlap with already existing standard policies. This standard does not specify
exact types for custom config entry points. FA2 token contract clients that support
custom config entry points must know their types a priori and/or use a `tag` hint
of `custom_permission_policy`.

## Future directions

Future amendments to Tezos are likely to enable new functionality by which this
standard can be upgraded. Namely, [read-only
calls](https://forum.tezosagora.org/t/adding-read-only-calls/1227), event logging,
and [contract signatures](https://forum.tezosagora.org/t/contract-signatures/1458).

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

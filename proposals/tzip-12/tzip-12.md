---
tzip: 12
title: FA2 - Multi-Asset Interface
status: Draft
type: Financial Application (FA)
author: Eugene Mishura (@e-mishura)
created: 2020-01-24
---

## Table Of Content

* [Summary](#summary)
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
  * [FA2 Permission Policies and Configuration](#fa2-permission-policies-and-configuration)
    * [A Taxonomy of Permission Policies](#a-taxonomy-of-permission-policies)
      * [Core Transfer Behavior](#core-transfer-behavior)
      * [Behavior Patterns](#behavior-patterns)
        * [`Self` Transfer Behavior](#self-transfer-behavior)
        * [`Operator` Transfer Behavior](#operator-transfer-behavior)
        * [`Token Owner` Permission Behavior](#token-owner-permission-behavior)
      * [Permission Policy Formulae](#permission-policy-formulae)
* [Implementing FA2](#implementing-fa2)
  * [Transfer Hook](#transfer-hook)
  * [Transfer Hook Motivation](#transfer-hook-motivation)
  * [Transfer Hook Specification](#transfer-hook-specification)
  * [`set_transfer_hook`](#set_transfer_hook)
  * [Transfer Hook Examples](#transfer-hook-examples)
    * [Default Permission Policy](#default-permission-policy)
    * [Custom Receiver Hook/White List Permission Policy](#custom-receiver-hookwhite-list-permission-policy)
* [Future directions](#future-directions)
* [Copyright](#copyright)

## Summary

TZIP-12 proposes a standard for a unified token contract interface,
supporting a wide range of token types and implementations. This document provides
an overview and rationale for the interface, token transfer semantics, and support
for various transfer permission policies.

**PLEASE NOTE:** This API specification remains a work-in-progress and may evolve
based on public comment see FA2 Request for Comment on [Tezos Agora](https://tezosagora.org).

## Abstract

There are multiple dimensions and considerations while implementing a particular
token smart contract. Tokens might be fungible or non-fungible. A variety of
permission policies can be used to define how many tokens can be transferred, who
can initiate a transfer, and who can receive tokens. A token contract can be
designed to support a single token type (e.g. ERC-20 or ERC-721) or multiple token
types (e.g. ERC-1155) to optimize batch transfer and atomic swaps of the tokens.

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

## Interface Specification

Token type is uniquely identified by a pair composed of the token contract address
and token id, a natural number (`nat`). If the underlying contract implementation
supports only a single token type (e.g. ERC-20-like contract), the token id MUST
be `0n`. The FA2 token contract is fully responsible for assigning and managing
token IDs. FA2 clients MUST NOT depend on particular ID values to infer information
about a token.

All entry points are batch operations that allow querying or transfer of multiple
token types atomically. If the underlying contract implementation supports only
a single token type, the batch may contain single or multiple entries where token
id will be a fixed `0n` value. Likewise, if multiple token types are supported,
the batch may contain zero or more entries and there may be duplicates.

Token contract MUST implement the following entry points. Notation is given in
[cameLIGO language](https://ligolang.org) for readability and Michelson. Please
note that the current LIGO implementation does not allow control over generated
Michelson entry points layout and thus LIGO-generated entry points will not be
compatible with provided Michelson specification.

A contract implementing the FA2 standard must have the following entry points:

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

type transfer = {
  from_ : address;
  to_ : address;
  token_id : token_id;
  amount : nat;
}

| Transfer of transfer list
```

Michelson definition:
```
(list %transfer
  (pair
    (address %from_)
    (pair
      (address %to_)
      (pair
        (nat %token_id)
        (nat %amount)
  )))
)
```

Each transfer amount in the batch is specified between two given addresses.
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
FA2 token contract implements mint and burn operations, it MUST enforce the same
rules and logic applied to the token transfer operation. Mint and burn can be
considered special cases of the transfer.

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

Get the balance of multiple account/token pairs. Accepts a list of
`balance_of_request`s and a callback contract `callback` which accepts a list of
`balance_of_response` records. There may be duplicate `balance_of_request`'s,
in which case they should not be deduplicated nor reordered.

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
  callback : (total_supply_response list) contract;
}

| Total_supply of total_supply_param
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
`total_supply_request`s and a callback contract `callback`, which accepts a list
of `total_supply_response` records.

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
  callback : (token_metadata list) contract;
}

| Token_metadata of token_metadata_param
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
type self_transfer_policy =
  | Self_transfer_permitted
  | Self_transfer_denied

type operator_transfer_policy =
  | Operator_transfer_permitted
  | Operator_transfer_denied

type owner_transfer_policy =
  | Owner_no_op
  | Optional_owner_hook
  | Required_owner_hook

type custom_permission_policy = {
  tag : string;
  config_api: address option;
}

type permissions_descriptor = {
  self : self_transfer_policy;
  operator : operator_transfer_policy;
  receiver : owner_transfer_policy;
  sender : owner_transfer_policy;
  custom : custom_permission_policy option;
}

| Permissions_descriptor of permissions_descriptor contract
```

Michelson definition:

```
(contract %permissions_descriptor
  (pair
    (or %self
      (unit %self_transfer_permitted)
      (unit %self_transfer_denied)
    )
    (pair
      (or %operator
        (unit %operator_transfer_permitted)
        (unit %operator_transfer_denied)
      )
      (pair
        (or %receiver
          (unit %owner_no_op)
          (or
            (unit %optional_owner_hook)
            (unit %required_owner_hook)
        ))
        (pair
          (or %sender
            (unit %owner_no_op)
            (or
              (unit %optional_owner_hook)
              (unit %required_owner_hook)
          ))
        (option %custom
          (pair
            (string %tag)
            (option %config_api address)
          )
        )
  ))))
)
```

Get the descriptor of the transfer permission policy. FA2 specifies
`permissions_descriptor` allowing external contracts (e.g. an auction) to discover
an FA2 contract's permission policy and to configure it. For more details see
[FA2 Permission Policies and Configuration](#fa2-permission-policies-and-configuration).

Some of the permission options require config API. Config entry points may be
implemented either within the FA2 token contract itself (then the returned address
shall be `SELF`), or in a separate contract (see recommended implementation
pattern using [transfer hook](#transfer-hook)).

#### Operators

**Operator** is a Tezos address that initiates token transfer operation on behalf
of the owner. **Owner** is a Tezos address which can hold tokens.

Operator, other than the owner, MUST be approved to manage particular token types
held by the owner to make a transfer from the owner account.

FA2 interface specifies two entry points to update and inspect operators.

##### `update_operators`

LIGO definition:

```ocaml
type token_id = nat

type operator_tokens =
  | All_tokens
  | Some_tokens of token_id set

type operator_param = {
  owner : address;
  operator : address;
  tokens : operator_tokens;
}

type update_operator =
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
        (or %tokens
          (unit %all_tokens)
          (set %some_tokens nat)
        )
    ))
    (pair %remove_operator
      (address %owner)
      (pair
        (address %operator)
        (or %tokens
          (unit %all_tokens)
          (set %some_tokens nat)
        )
    ))
  )
)
```

Add or Remove token operators for the specified owners and token types.

The entry point accepts a list of `update_operator` commands. If two different
commands in the list add and remove an operator for the same owner/token type,
the last command in the list MUST take effect. It is possible to update an operator
for some specific token types (`tokens` field in `operator_param` is `Some_tokens`)
or for all token types (`tokens` field in `operator_param` is `tokens` parameter
is `All_tokens`).

##### `is_operator`

LIGO definition:

```ocaml
type token_id = nat

type operator_tokens =
  | All_tokens
  | Some_tokens of token_id set

type operator_param = {
  owner : address;
  operator : address;
  tokens : operator_tokens;
}

type is_operator_response = {
  operator : operator_param;
  is_operator : bool;
}

type is_operator_param = {
  operator : operator_param;
  callback : (is_operator_response) contract;
}

| Is_operator of is_operator_param
```

Michelson definition:

```
(pair %is_operator
  (pair %operator
    (address %owner)
    (pair
      (address %operator)
      (or %tokens
        (unit %all_tokens)
        (set %some_tokens nat)
      )
  ))
  (contract %callback
    (pair
      (pair %operator
        (address %owner)
        (pair
          (address %operator)
          (or %tokens
            (unit %all_tokens)
            (set %some_tokens nat)
          )
      ))
      (bool %is_operator)
    )
  )
)
```

Inspect if an address is an operator for the specified owner and token types. If
the address is not an operator for at least one requested token type, the result
is `false`. It is possible to make a query for some specific token types (`tokens`
parameter is `Some_tokens`) or for all token types (`tokens` parameter is
`All_tokens`).

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

FA2 token contracts MUST implement this behavior. If a token contract implementation
uses the [transfer hook](#transfer-hook) design pattern, core transfer behavior
is to be part of the core transfer logic of the FA2 contract.

* Every transfer operation MUST be atomic. If the operation fails, all token
  transfers MUST be reverted, and token balances MUST remain unchanged.

* The amount of a token transfer MUST NOT exceed the existing token owner's
  balance. If the transfer amount for the particular token type and token owner
  exceeds the existing balance, the whole transfer operation MUST fail.

* Core transfer behavior MAY be extended. If additional constraints on tokens
  transfer are required, FA2 token contract implementation MAY invoke additional
  permission policies ([transfer hook](#transfer-hook) is the recommended design
  pattern to implement core behavior extension). If the additional permission
  hook fails, the whole transfer operation MUST fail.

* Core transfer behavior MUST update token balances exactly as the operation
  parameters specify it. No changes to amount values or additional transfers are
  allowed.

##### Behavior Patterns

###### `Self` Transfer Behavior

This behavior specifies if the token owner can transfer its tokens.

```ocaml
type self_transfer_policy =
  | Self_transfer_permitted
  | Self_transfer_denied
```

###### `Operator` Transfer Behavior

This behavior specifies if a token transfer can be initiated by someone other than
token owner (an operator). An operator can transfer any tokens in any amount on
behalf of the owner.

```ocaml
type operator_transfer_policy =
  | Operator_transfer_permitted
  | Operator_transfer_denied
```

FA2 interface provides API to configure operators (see [operators config entry
points](#operators)). If an operator transfer is denied, those entry points MUST
fail if invoked.

###### `Token Owner` Permission Behavior

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
type owner_transfer_policy =
  | Owner_no_op
  | Optional_owner_hook
  | Required_owner_hook
```

This policy can be applied to both token senders and token receivers. There are
two owner hook interfaces, `fa2_token_receiver` and `fa2_token_sender`, that need
to be implemented by token owner contracts to expose the owner's hooks to FA2 token
contract.

```ocaml
type transfer_descriptor = {
  from_ : address option;
  to_ : address option;
  token_id : token_id;
  amount : nat;
}

type transfer_descriptor_param = {
  fa2 : address;
  batch : transfer_descriptor list;
  operator : address;
}

type fa2_token_receiver =
  | Tokens_received of transfer_descriptor_param

type fa2_token_sender =
  | Tokens_sent of transfer_descriptor_param
```

##### Permission Policy Formulae

Each concrete implementation of the permission policy can be described by a formula
which combines permission behaviors in the following form:

```
Self(?) * Operator(?) * Receiver(?) * Sender(?)
```

For instance, `Self(Self_transfer_permitted) * Operator(Operator_transfer_denied) *
Receiver(Owner_no_op) * Sender(Owner_no_op)` formula describes the policy which
allows only token owners to transfer their own tokens.

`Self(Self_transfer_denied) * Operator(Operator_transfer_denied) *
Receiver(Owner_no_op) * Sender(Owner_no_op)` formula represents non-transferable
token (neither token owner, nor operators can transfer tokens.

Permission token policy formula is expressed by the `permissions_descriptor`
returned by the [`permissions_descriptor`](#permissions_descriptor) entry point.

```ocaml
type self_transfer_policy =
  | Self_transfer_permitted
  | Self_transfer_denied

type operator_transfer_policy =
  | Operator_transfer_permitted
  | Operator_transfer_denied

type owner_transfer_policy =
  | Owner_no_op
  | Optional_owner_hook
  | Required_owner_hook

type custom_permission_policy = {
  tag : string;
  config_api: address option;
}

type permissions_descriptor = {
  self : self_transfer_policy;
  operator : operator_transfer_policy;
  receiver : owner_transfer_policy;
  sender : owner_transfer_policy;
  custom : custom_permission_policy option;
}
```

It is possible to extend permission policy with a `custom` behavior, which does
not overlap with already existing standard policies. This standard does not specify
exact types for custom config entry points. FA2 token contract clients that support
custom config entry points must know their types a priori and/or use a `tag` hint
of `custom_permission_policy`.

## Implementing FA2

### Transfer Hook

Transfer hook is one recommended design pattern to implement FA2 that enables
separation of the core token transfer logic and a permission policy. Instead of
implementing FA2 as a monolithic contract, a [permission policy]
(#fa2-permission-policies-and-configuration) can be implemented as a separate
contract. Permission policy contract provides an entry point invoked by the core
FA2 contract to accept or reject a particular transfer operation (such
an entry point is called **transfer hook**).

#### Transfer Hook Motivation

Usually, different tokens require different permission policies that define who
can transfer and receive tokens. There is no single permission policy that fits
all scenarios. For instance, some game tokens can be transferred by token owners,
but no one else. In some financial token exchange applications, tokens are to be
transferred by special exchange operator account, not directly by the token owners
themselves.

Support for different permission policies usually requires customizing existing
contract code. The FA2 standard proposes a different approach in which the on-chain
composition of the core FA2 contract implementation does not change, and a pluggable
permission transfer hook is implemented as a separate contract and registered with
the core FA2. Every time FA2 performs a transfer, it invokes a hook contract that
validates a transaction and either approves it by finishing execution successfully
or rejects it by failing.

The transfer hook makes it is possible to model different transfer permission
policies like whitelists, operator lists, etc. Although this approach introduces
gas consumption overhead (compared to an all-in-one contract) by requiring an extra
inter-contract call, it also offers some other advantages:

* FA2 core implementation can be verified once, and certain properties (not
  related to permission policy) remain unchanged.

* Most likely, the core transfer semantic will remain unchanged. If
  modification of the permission policy is required for an existing contract, it
  can be done by replacing a transfer hook only. No storage migration of the FA2
  ledger is required.

* Transfer hooks could be used for purposes beyond permissioning, such as
  implementing custom logic for a particular token application.

#### Transfer Hook Specification

An FA2 token contract has a single entry point to set the hook. If a transfer hook
is not set, the FA2 token contract transfer operation MUST fail. Transfer hook is
to be set by the token contract administrator before any transfers can happen.
The concrete token contract implementation MAY impose additional restrictions on
who may set the hook. If the set hook operation is not permitted, it MUST fail
without changing existing hook configuration.

For each transfer operation, a token contract MUST invoke a transfer hook and
return a corresponding operation as part of the transfer entry point result.
(For more details see [`set_transfer_hook`](#set_transfer_hook) )

`operator` parameter for the hook invocation MUST be set to `SENDER`.

`from_` parameter for each `hook_transfer` batch entry MUST be set to `Some(transfer.from_)`.

`to_` parameter for each `hook_transfer` batch entry MUST be set to `Some(transfer.to_)`.

A transfer hook MUST be invoked, and operation returned by the hook invocation
MUST be returned by `transfer` entry point among other operations it might create.
`SENDER` MUST be passed as an `operator` parameter to any hook invocation. If an
invoked hook fails, the whole transfer transaction MUST fail.

FA2 does NOT specify an interface for mint and burn operations; however, if an
FA2 token contract implements mint and burn operations, these operations MUST
invoke a transfer hook as well.

|  Mint | Burn |
| :---- | :--- |
| Invoked if registered. `from_` parameter MUST be `None` | Invoked if registered. `to_` parameter MUST be `None`|

#### `set_transfer_hook`

FA2 entry point with the following signature.

LIGO definition:

```ocaml
type transfer_descriptor = {
  from_ : address option;
  to_ : address option;
  token_id : token_id;
  amount : nat;
}

type transfer_descriptor_param = {
  batch : transfer_descriptor list;
  operator : address;
}

type set_hook_param = {
  hook : unit -> transfer_descriptor_param contract;
  permissions_descriptor : permission_policy_descriptor;
}

Set_transfer_hook of set_hook_param
```

Michelson definition:

```
(pair %set_transfer_hook
  (lambda %hook
    unit
    (contract
        (pair
          (list %batch
            (pair
              (option %from_ address)
              (pair
                (option %to_ address)
                (pair
                  (nat %token_id)
                  (nat %amount)
            )))
          )
          (address %operator)
        )
    )
  )
  (pair %permissions_descriptor
    (or %self
      (unit %self_transfer_permitted)
      (unit %self_transfer_denied)
    )
  (pair
    (or %operator
      (unit %operator_transfer_permitted)
      (unit %operator_transfer_denied)
    )
  (pair
    (or %receiver
      (unit %owner_no_op)
      (or
        (unit %optional_owner_hook)
        (unit %required_owner_hook)
    ))
  (pair
    (or %sender
      (unit %owner_no_op)
      (or
        (unit %optional_owner_hook)
        (unit %required_owner_hook)
    ))
    (option %custom
      (pair
        (string %tag)
        (option %config_api address)
      )
    )
  ))))
)
```

FA2 implementation MAY restrict access to this operation to a contract administrator
address only.

The parameter is an address plus hook entry point of type
`transfer_descriptor_param`.

The transfer hook is always invoked from the `transfer` operation; otherwise, FA2
MUST fail.

`hook` field in `set_hook_param` record is a lambda which returns a hook entry
point of type `transfer_descriptor_param`. It allows a policy contract implementor
to choose a name for the hook entry point or even implement several transfer hooks
in the same contract.

#### Transfer Hook Examples

##### Default Permission Policy

Only a token owner can initiate a transfer of tokens from their accounts ( `from_`
MUST be equal to `SENDER`).

Any address can be a recipient of the token transfer.

[Hook contract](./examples/fa2_default_hook.mligo)

##### Custom Receiver Hook/White List Permission Policy

This is a sample implementation of the FA2 transfer hook, which supports receiver
whitelist and `fa2_token_receiver` for token receivers. The hook contract also
supports [operators](#operator-transfer-behavior).

Only addresses that are whitelisted or implement the `fa2_token_receiver` interface
can receive tokens. If one or more `to_` addresses in FA2 transfer batch are not
permitted, the whole transfer operation MUST fail.

The following table demonstrates the required actions depending on `to_` address
properties.

| `to_` is whitelisted | `to_` implements `fa2_token_receiver` interface | Action |
| ------ | ----- | ----------|
| No  | No  | Transaction MUST fail |
| Yes | No  | Continue transfer |
| No  | Yes | Continue transfer, MUST call `tokens_received` |
| Yes | Yes | Continue transfer, MUST call `tokens_received` |

Permission policy formula `S(true) * O(true) * ROH(None) * SOH(Custom)`.

[Hook contract](./examples/fa2_custom_receiver.mligo)

## Future directions

Future amendments to Tezos are likely to enable new functionality by which this
standard can be upgraded. Namely, [read-only
calls](https://forum.tezosagora.org/t/adding-read-only-calls/1227), event logging,
and [contract signatures](https://forum.tezosagora.org/t/contract-signatures/1458).

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).
---
tzip: 12
title: FA2 - Multi-Asset Interface
status: Work In Progress
type: Financial Application (FA)
author: Eugene Mishura (@e-mishura)
created: 2020-01-24
---

## Summary

This document proposes a standard for a unified token contract interface, supporting
a wide range of token types and implementations.
This standard focuses on the interface, token transfer semantics, and support for
various transfer permission policies.

## Abstract

There are multiple dimensions and considerations while implementing a particular
token smart contract. Tokens might be fungible or non-fungible. A variety of
permission policies can be used to define how many tokens can be transferred,
who can initiate a transfer, and who can receive tokens. A token contract can be
designed to support a single token type (e.g. ERC-20 or ERC-721) or multiple
token types (e.g. ERC-1155) to optimize batch transfer and atomic swaps of the
tokens.

Such considerations can easily lead to the proliferation of many token standard
proposals, each optimized for a particular token type or use case. This dynamic
is apparent in the Ethereum ecosystem, where many standards have been proposed but
ERC-20 (fungible tokens) and ERC-721 (non-fungible tokens) are dominant.

Token wallets, token exchanges, and other clients then need to support multiple
standards and multiple token APIs. This standard proposes a unified token contract
interface which accommodates all mentioned concerns. It aims to provide significant
expressivity to contract developers to create new types of tokens while maintaining
a common interface standard for wallet integrators and external developers.

## Interface Specification

Token type is uniquely identified by a pair composed of the token contract address and
token id, which is a natural number (`nat`). If the underlying contract implementation
supports only a single token type (e.g. ERC-20-like contract), token id MUST be `0n`.
FA2 token contract is fully responsible to assign and manage token IDs. FA2 clients
MUST NOT depend on particular ID values to infer information about a token.

All entry points are batch operations which allow querying or transfer multiple
token types atomically. If the underlying contract implementation supports
only a single token type, the batch may contain single or multiple entries where
token id will always be a fixed `0n` value.

Token contract MUST implement the following entry points. Notation is given in
[cameLIGO language](https://ligolang.org) for readability but a Michelson interface
will also be provided:

```ocaml
type token_id = nat

type transfer = {
  from_ : address;
  to_ : address;
  token_id : token_id;
  amount : nat;
}

type balance_request = {
  owner : address;
  token_id : token_id;  
}

type balance_response = {
  request : balance_request;
  balance : nat;
}

type balance_param = {
  requests : balance_request list;
  callback : (balance_response list) contract;
}

type total_supply_response = {
  token_id : token_id;
  total_supply : nat;
}

type total_supply_param = {
  token_ids : token_id list;
  callback : (total_supply_response list) contract;
}

type token_metadata = {
  symbol : string;
  name : string;
  decimals : nat;
  extras : (string, string) map;
}

type token_metadata_response = {
  token_id : token_id;
  token_metadata : token_metadata;
}

type token_metadata_param = {
  token_ids : token_id list;
  callback : (token_metadata_response list) contract;
}

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

type is_operator_response = {
  operator : operator_param;
  is_operator : bool;
}

type is_operator_param = {
  operator : operator_param;
  callback : (is_operator_response) contract;
}

(* permission policy definition *)

type policy_config_api = address

type custom_permission_policy = {
  tag : string;
  config_api: policy_config_api option;
}

type self_transfer_policy =
  | Self_transfer_permitted
  | Self_transfer_denied

type operator_transfer_policy =
  | Operator_transfer_permitted
  | Operator_transfer_denied
  | Operator_custom of custom_permission_policy

type owner_transfer_policy =
  | Owner_no_op
  | Optional_owner_hook
  | Required_owner_hook
  | Owner_custom of custom_permission_policy

type permission_policy_descriptor = {
  self : self_transfer_policy;
  operator : operator_transfer_policy;
  receiver : owner_transfer_policy;
  sender : owner_transfer_policy;
  custom : custom_permission_policy option;
}

type fa2_entry_points =
  | Transfer of transfer list
  | Balance of balance_param
  | Total_supply of total_supply_param
  | Token_metadata of token_metadata_param
  | Permissions_descriptor of permission_policy_descriptor contract
  | Update_operators of update_operator list
  | Is_operator of is_operator_param
```

### Entry Point Semantics

#### `transfer`

Transfers amounts specified in the batch between given addresses. Transfers
should happen atomically; if at least one specified transfer cannot be completed,
the whole transaction MUST fail.

The transaction MUST fail if any of the balance(s) of the holder for token(s) in
the batch is lower than the respective amount(s) sent. If holder does not hold any
tokens of type `token_id`, holder's balance is interpreted as zero.

Transfer implementations MUST apply permission policy logic. If permission logic
rejects a transfer, the whole operation MUST fail.

A transfer operation MUST update token owners' balances exactly how it is specified
by its parameters. Transfer operation should not try to adjust transfer amounts
and/or try to add/remove additional transfers like transaction fees.

FA2 does NOT specify an interface for mint and burn operations; however, if an
FA2 token contract implements mint and burn operations, it MUST apply the same
permission logic as for the token transfer operation. Mint and burn can be considered
special cases of the transfer.

#### `balance`

Get the balance of multiple account/token pairs. Accepts a list of `balance_request`s
and a callback contract `callback` which accepts a list of `balance_response`
records.

#### `total_supply`

Get the total supply for multiple token types. Accepts a list of `total_supply_request`s
and a callback contract `callback` which accepts a list of
`total_supply_response` records.

#### `token_metadata`

Get the metadata for multiple token types. Accepts a list of `token_id`s
and a callback contract `callback` which accepts a list of
`token_metadata_response` records.

```ocaml
type token_metadata = {
  symbol : string;
  name : string;
  decimals : nat;
  extras : (string, string) map;
}
```

FA2 token amounts are represented by natural numbers (`nat`) and their **granularity**
(the smallest amount oif tokens which may be minted, burned or transferred) is
always 1.

`decimals` is the number of digits to use after the decimal point when displaying
the token amounts. If 0, the asset is not divisible. Decimals are used for display
purpose only and MUST NOT affect transfer operation.

#### `permissions_descriptor`

Gets the descriptor of the transfer permission policy.

```ocaml
type permission_policy_descriptor = {
  self : self_transfer_policy;
  operator : operator_transfer_policy;
  receiver : owner_transfer_policy;
  sender : owner_transfer_policy;
  custom : custom_permission_policy option;
}
```

For more details see [FA2 Permission Policies and Configuration](#FA2 Permission Policies and Configuration)

Some of the permission options require config API. Config entry points may be
implemented either within the FA2 token contract itself (then the returned address
will be `SELF`), or in a separate contract (see recommended implementation pattern
using [transfer hook](#Transfer Hook)).

#### Operators

Operator is a Tezos address which initiates token transfer operation on behalf of
the owner. Owner is a Tezos address which can hold tokens.
Operator, other than the owner, MUST be approved to manage particular token types
held by the owner to make a transfer from the owner account.

```ocaml
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

type is_operator_response = {
  operator : operator_param;
  is_operator : bool;
}

type is_operator_param = {
  operator : operator_param;
  callback : (is_operator_response) contract;
}

| Update_operators of update_operator list
| Is_operator of is_operator_param
```

### FA2 Permission Policies and Configuration

Most token standards specify some logic which defines who can initiate a transfer,
how much can be transferred, who can receive tokens etc. This standard
calls such logic *permission policy* and defines a framework to compose and configure
such permission policies from the standard behaviors and configuration APIs.

A particular permission policy defines the semantics (logic that defines if a
transfer operation is permitted or not) and MAY require additional internal data
(for example, operators). If the permission policy requires additional internal
data, it also requires the standard configuration API to manage that data.

Often, proposed token standards specify either a single policy (e.g. allowances
in ERC-20) or multiple non-compatible policies (e.g. ERC-777, which has both allowance
and operator APIs and two versions of the transfer entry point, one that invokes
sender/receiver hooks and one which does not).

FA2 specifies an interface `permissions_descriptor` allowing external contracts
(e.g. an auction) to discover an FA2 contract's permissioning policy and configure it.
This serves as a more modular alternative to the existing approaches in ERC-20 or
FA1.2 and helps to define consistent and non-self-contradictory policies.

#### A Taxonomy of Permission Policies

Permission policy semantics can be broken down into several orthogonal behavior patterns.
The concrete policy can be expressed as a combination of those behaviors.  

The proposed taxonomy framework and API allows other contracts to discover the properties
(behaviors) of the particular FA2 token contract permission policy and/or to configure
it on the chain.

##### Core Transfer Behavior

This behavior MUST be implemented by any FA2 token contract. If a token contract
implementation uses the [transfer hook](#Transfer Hook) design pattern, core transfer
behavior is to be part of the core transfer logic of the FA2 contract.

- Every transfer operation MUST be atomic. If the operation fails, all token transfers
MUST be reverted and token balances MUST remain unchanged.
- The amount of a token transfer MUST NOT exceed the existing token owner's balance.
If the transfer amount for the particular token type and token owner exceeds the existing
balance, the whole transfer operation MUST fail.
- Core transfer behavior MAY be extended. If additional constraints on tokens transfer
are required, FA2 token contract implementation MAY invoke additional permission
policies ([transfer hook](#Transfer Hook) is the recommended design pattern to
implement core behavior extension). If the additional permission hook fails, the whole
transfer operation MUST fail.
- Core transfer behavior MUST update token balances exactly as it is specified by
the operation parameters. No amount adjustments and/or additional transfers are
allowed.

##### Behavior Patterns

###### `Self` Transfer Behavior

This behavior specifies if the token owner can transfer its own tokens.

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
  | Operator_custom of custom_permission_policy
```

FA2 interface provides API to configure operators (see [operators config entry points](#operators)).
If an operator transfer is denied, those entry points MUST fail if invoked.

The policy has an extension point `Operator_custom`. If required, a custom operator
policy can be created and used instead of the standard ones.
For instance, operator's allowances per token type may be supported.

###### `Token Owner` Permission Behavior

Each transfer operation defines both a set of token owners that send tokens (senders)
and a set of token owners that receive tokens (receivers). Token owner contracts
MAY implement either an `fa2_token_sender` or `fa2_token_receiver` hook interface.
Permission behavior MAY call sender and/or receiver hooks which can approve the
transaction or reject it by failing. If such a hook is invoked and failed, the
whole transfer operation MUST fail. Token owner permission may be configured
to behave in one of the following ways:

- Ignore the owner hook interface.
- Treat the owner hook interface as optional. If a token owner contract implements
a corresponding hook interface, it gets invoked. If the hook interface is not implemented,
it gets ignored.
- Treat the owner hook interface as required. If a token owner contract implements
a corresponding hook interface, it gets invoked. If the hook interface is not implemented,
the entire transfer transaction gets rejected.

Token owner behavior is defined as following:

```ocaml
type owner_transfer_policy =
  | owner_no_op
  | Optional_owner_hook
  | Required_owner_hook
  | Owner_custom of custom_permission_policy
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
  batch : transfer_descriptor list;
  operator : address;
}

type fa2_token_receiver =
  | Tokens_received of transfer_descriptor_param

type fa2_token_sender =
  | Tokens_sent of transfer_descriptor_param
```

The policy has an extension point, `Owner_custom`. If required, a custom owner policy
can be created and used instead of the standard ones.
For instance, a behavior which combines an owner hook and a white list may be supported.

##### Permission Policy Formulae

Each concrete implementation of the permission policy can be described by a formula
which combines permission behaviors in the following form:

`Self(?) * Operator(?) *  Receiver(?) * Sender(?)`

For instance,
`Self(Self_transfer_permitted) * Operator(Operator_transfer_denied) * Receiver(Owner_no_op) * Sender(Owner_no_op)`
formula describes the policy which allows only token owners to transfer their own
tokens.

`Self(Self_transfer_denied) * Operator(Operator_transfer_denied) * Receiver(Owner_no_op) * Sender(Owner_no_op)`
formula represents non-transferable token (neither token owner, nor operators can
transfer tokens.

Permission token policy formula is expressed by the `permission_policy_descriptor`
returned by the [`permissions_descriptor`](#permissions_descriptor)
entry point.

```ocaml
type policy_config_api = address

type custom_permission_policy = {
  tag : string;
  config_api: policy_config_api option;
}

type self_transfer_policy =
  | Self_transfer_permitted
  | Self_transfer_denied

type operator_transfer_policy =
  | Operator_transfer_permitted of policy_config_api
  | Operator_transfer_denied
  | Operator_transfer_custom of custom_permission_policy

type owner_transfer_policy =
  | Owner_no_op
  | Optional_owner_hook
  | Required_owner_hook
  | Owner_custom of custom_permission_policy

type permission_policy_descriptor = {
  self : self_transfer_policy;
  operator : operator_transfer_policy;
  receiver : owner_transfer_policy;
  sender : owner_transfer_policy;
  custom : custom_permission_policy option;
}
```

It is possible to extend permission policy with a `custom` behavior which does not
overlap with already existing standard policies. This standard does not specify
exact types for custom config entry points. FA2 token contract clients which
support custom config entry points must know their types a priori and/or use a
`tag` hint of `custom_permission_policy`.

## Implementing FA2

### Transfer Hook

Transfer hook is one recommended design pattern to implement FA2 that enables separation
of the core token transfer logic and a permission policy. Instead of implementing
FA2 as a monolithic contract, a [permission policy](#FA2 Permission Policies and Configuration)
can be implemented as a separate contract. Permission policy contract provides an
entry point invoked by the core FA2 contract to accept or reject a particular
transfer operation (such entry point is called **transfer hook**).

#### Transfer Hook Motivation

Usually different tokens require different permission policies which define who
can transfer and receive tokens. There is no single permission policy that fits
all scenarios. For instance, some game tokens can be transferred by token owners
but no one else. In some financial token exchange applications, tokens are to be
transferred by special exchange operator account, not directly by the token
owners themselves.

Support for different permission policies usually requires customizing existing
contract code. The FA2 standard proposes a different approach in which the on-chain
composition of the core FA2 contract implementation does not change, and a
pluggable permission transfer hook is implemented as a separate contract and registered
with the core FA2. Every time FA2 performs a transfer, it invokes a hook contract
which validates a transaction and either approves it by finishing execution successfully
or rejects it by failing.

Using transfer hook, it is possible to model different transfer permission
policies like whitelists, operator lists, etc. Although this approach introduces
gas consumption overhead (compared to an all-in-one contract) by requiring an extra
inter-contract call, it also offers some other advantages:

- FA2 core implementation can be verified once and certain properties (not related
to permission policy) remain unchanged.
- Most likely, core transfer semantic will remain unchanged. If modification of the
permission policy is required for an existing contract, it can be done by replacing
a transfer hook only. No storage migration of the FA2 ledger is required.
- Transfer hooks could be used for purposes beyond permissioning such as implementing
custom logic for a particular token application.

#### Transfer Hook Specification

An FA2 token contract has a single entry point to set the hook. If a transfer hook is
not set, the FA2 token contract transfer operation MUST fail. Transfer hook is to be
set by the token contract administrator before any transfers can happen.
The concrete token contract implementation MAY impose additional restrictions on
who may set the hook. If the set hook operation is not permitted, it MUST fail
without changing existing hook configuration.

For each transfer operation, a token contract MUST invoke a transfer hook
and return a corresponding operation as part of the transfer entry point result.
(For more details see [`set_transfer_hook`](#set_transfer_hook) )

`operator` parameter for the hook invocation MUST be set to `SENDER`.

`from_` parameter for each `hook_transfer` batch entry MUST be set to `Some(transfer.from_)`.

`to_` parameter for each `hook_transfer` batch entry MUST be set to `Some(transfer.to_)`.

A transfer hook MUST be invoked, and operation returned by the hook
invocation MUST be returned by `transfer` entry point among other operations it
might create. `SENDER` MUST be passed as an `operator` parameter to any hook invocation.
If an invoked hook fails, the whole transfer transaction MUST fail.

FA2 does NOT specify an interface for mint and burn operations; however, if an
FA2 token contract implements mint and burn operations, these operations MUST invoke
a transfer hook as well.

|  Mint | Burn |
| :---- | :--- |
| Invoked if registered. `from_` parameter MUST be `None` | Invoked if registered. `to_` parameter MUST be `None`|

#### `set_transfer_hook`

FA2 entry point with the following signature:

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

FA2 implementation MAY restrict access to this operation to a contract administrator
address only.

The parameter is an address plus hook entry point of type `transfer_descriptor_param`.

The transfer hook is always invoked from the `transfer` operation; otherwise, FA2 MUST fail.

`hook` field in `set_hook_param` record is a lambda which returns a hook entry point
of type `transfer_descriptor_param`. It allows a policy contract implementor to
choose a name for the hook entry point or even implement several transfer hooks
in the same contract.

#### Transfer Hook Examples

##### Default Permission Policy

Only a token owner can initiate a transfer of tokens from their accounts
( `from_` MUST be equal to `SENDER`).

Any address can be a recipient of the token transfer.

[Hook contract](./examples/fa2_default_hook.mligo)

##### Custom Receiver Hook/White List Permission Policy

This is a sample implementation of the FA2 transfer hook which supports receiver
whitelist and `fa2_token_receiver` for token receivers. The hook contract also
supports [operators](#Operator` Transfer Behavior).

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
standard can be upgraded. Namely,
[read-only calls](https://forum.tezosagora.org/t/adding-read-only-calls/1227),
event logging, and [contract signatures](https://forum.tezosagora.org/t/contract-signatures/1458).

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

---
tzip: 12
title: FA2 - Multi-Asset Interface
status: Work In Progress
type: Financial Application (FA)
author: Eugene Mishura (@e-mishura)
created: 2020-01-24
---

## Summary

This document proposes a standard for a unified token contract interface to support
different token types and/or token contract implementations.
This standard focuses on token transfer semantics and support for various transfer
approval schemas.

## Abstract

There are multiple dimensions and considerations while implementing a particular
token smart contract. Tokens might be fungible or non-fungible. Different
permissioning schemas can be used to define who can initiate a transfer and who
can receive tokens. A token contract can support a single token type or multiple
token types to optimize batch transfer and atomic swaps of the tokens. Those
considerations can lead to the proliferation of multiple token standards, each
optimized for a particular token type or use case. This dynamic is apparent in
the Ethereum ecosystem, where many standards have been proposed but ERC-20
(fungible tokens) and ERC-721 (non-fungible tokens) are dominant.

Token wallets, token exchanges, and other clients then need to support multiple
standards and multiple token APIs. This standard proposes a unified token contract
interface which accommodates all mentioned concerns. It aims to provide significant
expressivity to developers to create new types of tokens while maintaining a common
interface standard for wallet integrations and other external developers.

## Specification

Token type is uniquely identified by a pair of the token contract address and
token id. If the underlying contract implementation supports only a single
token type (ERC-20-like contract), token id is represented by `unit`. If the
underlying contract implementation supports multiple tokens (in a Multi-Asset
Contract or MAC), token id is represented by `nat`.

All entry points are batch operations which allow to query or transfer multiple
token types atomically. If the underlying contract implementation supports
only a single token type, the batch may contain single or multiple entries where
token id will always be fixed `Single unit` value.

Token contract MUST implement the following entry points (notation is given in
[cameLIGO language](https://ligolang.org)):

```ocaml
type token_id =
  | Single of unit
  | Mac of nat

type transfer = {
  from_ : address;
  to_ : address;
  token_id : token_id;
  amount : nat;
}

type transfer_param = transfer list

type permission_config = 
  | No_config of address
  | Allowance_config of address
  | Operator_config of address
  | Whitelist_config of address

type balance_request = {
  owner : address; 
  token_id : token_id;  
}

type balance_response = {
  request : balance_request;
  balance : nat;
}

type balance_of_param = {
  balance_requests : balance_request list;
  balance_view : (balance_response list) contract;
}

type total_supply_response = {
  token_id : token_id;
  supply : nat;
}

type total_supply_param = {
  total_supply_requests : token_id list;
  total_supply_view : (total_supply_response list) contract;
}

type token_descriptor = {
  symbol: string;
  name : string;
  decimals : nat;
  extras : (string, string) map;
}

type token_descriptor_response = {
  token_id : token_id;
  descriptor : token_descriptor;
}

type token_descriptor_param = {
  token_ids : token_id list;
  token_descriptor_view : (token_descriptor_response list) contract
}

type hook_transfer = {
  from_ : address option;
  to_ : address option;
  token_id : token_id;
  amount : nat;
}

type hook_param = {
  batch : hook_transfer list;
  operator : address;
}

type fa2_entry_points =
  | Transfer of transfer_param
  | Balance_of of balance_of_param
  | Total_supply of total_supply_param
  | Token_descriptor of token_descriptor_param
  | Get_config_entry_points of permission_config contract
```

### FA2 permissiniong schemas and configuration

Often proposed token standards specify either a single schema (like allowances
in ERC-20) or multiple non-compatible schemas (like ERC-777 which has both allowances
and operators APIs; two versions of the transfer entry point, one which invokes
sender/receiver hooks and one which does not).

FA2 implementation may use different permissioning schemas to define who can initiate
a transfer and who can receive tokens. This specification defines a set of standard
configuration APIs. The concrete implementation of FA2 token contract MUST support
one of the standard config APIs, which can be discovered by FA2 token contract
clients such as wallets. For more details see description of `Get_config_entry_points`
entry point.

The particular implementation of FA2 token contract MAY extend one of the standard
configuration APIs with additional custom entry points. `permission_config` type
defines all standard config APIs.

#### `no_config`

Represent non-configurable FA2 implementation with the following default behavior
which represents minimal permissioning schema.

1. Only token owner can initiate a transfer of tokens from their accounts
( `from_` MUST be equal to `SENDER`)
2. Any address can be a recipient of the token transfer

#### `allowance_config`

Spender is a Tezos address which initiates token transfer operation.
Owner is a Tezos address which can hold tokens. Owner can transfer its own tokens.
Spender, other than the owner, MUST be approved to withdraw specific tokens held
by the owner up to the allowance amount.

The owner does not need to be approved to transfer its own tokens.

Config API provides the following entry points:

```ocaml
type set_allowance_param = {
  owner : address;
  token_id : token_id;
  spender : address;
  prev_allowance : nat;
  new_allowance : nat;
 }

 type allowance_id = {
  owner : address;
  token_id : token_id;
  spender : address;
 }

type get_allowance_response = {
  allowance_id : allowance_id;
  allowance : nat;
}

 type get_allowance_param = {
   allowance_ids : allowance_id list;
   view : (get_allowance_response list) contract;
 }

 type fa2_allowance_config_entry_points =
  | Set_allowance of set_allowance_param list
  | Get_allowance of get_allowance_param
```

#### `operator_config`

Operator is a Tezos address which initiates token transfer operation.
Owner is a Tezos address which can hold tokens. Owner can transfer its own tokens.
Operator, other than the owner, MUST be approved to manage all tokens held by
the owner to make a transfer from the owner account.

The owner does not need to be approved to transfer its own tokens.

Config API provides the following entry points:

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
  operator : operator_param list;
  view : (is_operator_response list) contract;
}

type fa2_operator_config_entry_points =
  | Add_operators of operator_param list
  | Remove_operators of operator_param list
  | Is_operator of is_operator_param
```

#### `whitelist_config`

Only addresses which are whitelisted can receive tokens. If one or more `to_`
addresses in FA2 transfer batch are not whitelisted the whole transfer operation
MUST fail.

Config API provides the following entry points:

```ocaml
type fa2_whitelist_config_entry_points =
  | Add_to_white_list of address list
  | Remove_from_white_list of address list
```

### Entry Point Semantics

#### `transfer`

Transfers amounts specified in the batch between given addresses. Transfers
should happen atomically: if at least one specified transfer cannot be completed,
the whole transaction MUST fail.

The transaction MUST fail if any of the balance(s) of the holder for token(s) in
the batch is lower than the respective amount(s) sent. If holder does not hold any
tokens of type `token_id`, holder's balance is interpreted as zero.

Transfer implementation must apply permissioning schema logic. If permissining logic
rejects a transfer, the whole MUST fail.

FA2 does NOT specify an interface for mint and burn operations. However, if an
FA2 token contract implements mint and burn operations, it MUST apply permissioning
logic as well.

#### `balance_of`

Get the balance of multiple account/token pairs. Accepts a list of `balance_request`s
and a callback contract `balance_view` which accepts a list of `balance_response`
records.

#### `total_supply`

Get the total supply for multiple token types. Accepts a list of `total_supply_request`s
and a callback contract `total_supply_view` which accepts a list of
`total_supply_response` records.

#### `token_descriptor`

Get the total supply for multiple token types. Accepts a list of `token_id`s
and a callback contract `token_descriptor_view` which accepts a list of
`token_descriptor_response` records.

#### `get_config_entry_points`

Get the address of the contract which provides permission configuration entry
points for the FA2 token contract. The particular option of the `permission_config`
type specifies one of the standard config API which MUST be implemented by the
permission configuration contract.

| `permission_config` option | config entry points type |
| :------------------------- | :----------------------- |
| `No_config`                | `unit` (there are no config entry poinst for this option) |
| `Allowance_config`         | `fa2_allowance_config_entry_points` |
| `Operator_config`          | `fa2_operator_config_entry_points`  |
| `Whitelist_config`         | `fa2_whitelist_config_entry_points` |

Config entry points may be implemented either by FA2 token contract (then the
returned address will be `SELF`), or by a separate contract (see recommended
implementation pattern using transfer hook).

## Transfer Hook

Transfer hook is a recommended design pattern to implement FA2. The idea is to separate
core token transfer logic and permissioning schema.

### Transfer Hook Motivation

Usually different tokens require different permissioning schemas which define who
can transfer and receive tokens. There is no single permissioning schema which fits
all scenarios. For instance, some game tokens can be transferred by token owners,
but nobody else. In some financial token exchange application tokens are to be
transferred by special exchange operator account, but not directly by token owners
themselves.

Support for different permissioning schemas usually require to customize
existing contract code. This standard proposes different approach with on-chain
composition of the core FA2 contract implementation which does not change and plugable
permission hook implemented as a separate contract and registered with the core FA2.
Every time FA2 performs a transfer it invokes hook contract which may validate a
transaction and approve it by finishing execution successfully  or reject it by
failing. Using transfer hook, it is possible to model different transfer permissioning
schemas like white lists, operator lists etc. Although this approach introduces
gas consumption overhead (compared to an all-in-one contract) by requiring an extra
inter-contract call, it has some other advantages:

- FA2 core implementation can be verified once and certain properties (not related
to permissioning schema) remain unchanged.
- Most likely core transfer semantic will remain unchanged. If modification of the
permissioning schema is required for an existing contract, it can be done by replacing
a transfer hook only. No storage migration of the FA2 ledger is required.
- Transfer hook may be used not only for permissioning, but to implement additional
custom logic required by the particular token application.

### Transfer Hook Specification

Transfer hook is required to perform transfer operation. FA2 token contract has
a single entry point to set the hook. If transfer hook is not set, FA2 token
contract transfer operation MUST fail. Transfer hook is to be set by the token
contract administrator before any transfers can happen. The concrete token contract
implementation MAY impose additional restrictions on who may set the hook. 
If set hook operation is not permitted, it MUST fail without changing existing hook state.

For each transfer operation token contract MUST invoke transfer hook
and return corresponding operation as part of the transfer entry point result.

`operator` parameter for the hook invocation MUST be set to `SENDER`.

`from_` parameter for each `hook_transfer` batch entry MUST be set to `Some(transfer.from_)`.

`to_` parameter for each `hook_transfer` batch entry MUST be set to `Some(transfer.to_)`.

Transfer hook MUST be invoked and operation returned by the hook
invocation MUST be returned by `transfer` entry point among other operations it
might create. `SENDER` MUST be passed as an `operator` parameter to any hook invocation.
If invoked hook fails, the whole transfer transaction MUST fail.

FA2 does NOT specify an interface for mint and burn operations. However, if an
FA2 token contract implements mint and burn operations, it MUST invoke transfer
hook as well.

|  Mint | Burn |
| :---- | :--- |
| Invoked if registered. `from_` parameter MUST be `None` | Invoked if registered. `to_` parameter MUST be `None`|

### `set_transfer_hook`

FA2 entry point with the following signature:

```ocaml
type set_hook_param = {
  hook : unit -> hook_param contract;
  config : permission_config;
}

Set_transfer_hook of set_hook_param
```

FA2 implementation MAY restrict access to this operation to a contract administrator
address only.

The parameter is a lambda which returns hook contract entry point of
type `unit -> hook_param contract`

The transfer hook is always invoked from the `transfer` operation.
Otherwise, FA2 MUST fail.

For more details see "Transfer Hook Specification" section.

### Transfer Hook Examples

### Default permissioning

Only token owner can initiate a transfer of tokens from their accounts
( `from_` MUST be equal to `SENDER`).

Any address can be a recipient of the token transfer.

[Hook contract](./examples/fa2_default.mligo)

#### Transfer allowances

This is a sample implementation of the FA2 transfer hook which supports transfer
allowances for token spenders.

Spender is a Tezos address which initiates token transfer operation.
Owner is a Tezos address which can hold tokens. Owner can transfer its own tokens.
Spender, other than the owner, MUST be approved to withdraw specific tokens held
by the owner up to the allowance amount.

Only token owner can set allowances for specific token types and spenders.
The owner does not need to be approved to transfer its own tokens.

[Hook contract](./examples/fa2_allowances.mligo)

#### Transfer operators

This is a sample implementation of the FA2 transfer hook which supports transfer
operators.

Operator is a Tezos address which initiates token transfer operation.
Owner is a Tezos address which can hold tokens. Owner can transfer its own tokens.
Operator, other than the owner, MUST be approved to manage all tokens held by
the owner to make a transfer from the owner account.

Only token owner can add or remove its operators. The owner does not need to be
approved to transfer its own tokens.

[Hook contract](./examples/fa2_operators.mligo)

#### Receiver whitelisting

This is a sample implementation of the FA2 transfer hook which supports receiver
whitelist.

Only addresses which are whitelisted can receive tokens. If one or more `to_`
addresses in FA2 transfer batch are not whitelisted the whole transfer operation
MUST fail.

[Hook contract](./examples/fa2_receiver_whitelist.mligo)
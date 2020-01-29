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
type transfer_param = {
  batch : transfer list;
  data : bytes option;
}

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
  from_ : address option; (* None for minting *)
  to_ : address option;   (* None for burning *)
  token_id : token_id;
  amount : nat;
}

type hook_param = {
  batch : hook_transfer list;
  data : bytes option;
  operator : address;
}

type set_hook_param = hook_param contract


type fa2_entry_points =
  | Transfer of transfer_param
  | Balance_of of balance_of_param
  | Total_supply of total_supply_param
  | Token_descriptor of token_descriptor_param
  | Set_transfer_hook of set_hook_param option
```

### Entry Point Semantics

#### `transfer`

Transfers amounts specified in the batch between given addresses. Transfers
should happen atomically: if at least one specified transfer cannot be completed,
the whole transaction MUST fail.

The transaction MUST fail if any of the balance(s) of the holder for token(s) in
the batch is lower than the respective amount(s) sent. If holder does not hold any
tokens of type `token_id`, holder's balance is interpreted as zero.

All registered hooks relevant for this transfer MUST be invoked and operations
returned by the hooks invocation MUST be returned by `transfer` entry point among
other operations it might create. Optional `data` parameter MUST be passed unaltered
to the hooks. `SENDER` MUST be passed as an `operator` parameter to any hook invocation.
If any of the invoked hooks fails, the whole transfer transaction MUST fail.
For more details on hooks semantics see "Transfer Hooks" section of this document.

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

### Transfer Hooks

Using transfer hook, it is possible to model different transfer permissioning
schemes like white lists, operator lists etc.

Transfer hook is optional and have a single entry point to set or reset the hook.
If transfer hook is not set, FA2 MUST fall back on default behavior.
The concrete token contract implementation MAY impose additional restrictions on
who may set and/or reset the hook. If set/reset hook operation is not permitted,
it MUST fail without changing registered hook state.

For each transfer operation token contract MUST invoke corresponding transfer hook
hook and return corresponding operation as part of the transfer entry point result.
Transfer operation MUST pass optional `data` parameter to hooks unaltered.

`operator` parameter for hook invocation MUST be set to `SENDER`.

`from_` parameter for each `hook_transfer` batch entry MUST be set to `Some(transfer.from_)`.

`to_` parameter for each `hook_transfer` batch entry MUST be set to `Some(transfer.to_)`.

If the token contract implements mint and burn operations, they MUST invoke transfer
hooks as well.

|  Mint | Burn |
| :---- | :--- |
| Invoked if registered. `from_` parameter MUST be `None` | Invoked if registered. `to_` parameter MUST be `None`|

The default behavior of FA2 when transfer hook is not set:

1. Only token owners can initiate transfer of the tokens from their accounts
( `from_` MUST equal `SENDER`)
2. Any address can be a recipient of the token transfer

The default behavior represents minimal permissioning schema. By seting a transfer
hook this default schema can be replaced with a different one. For instance, custom
permissioning schema may support operators, allowances, sender and receiver interface
invocation for token owners etc.

### `set_transfer_hook`

Set or remove a transfer hook. FA2 contract can have one or zero transfer hooks.
FA2 implementation MAY restrict access to this operation to a contract administrator
address only.

If input parameter is `None`, transfer hook is to be removed. If input parameter
is `Some` hook entry point, a new transfer hook is to be associated with the FA2
contract.

If present, the transfer hook is always invoked from the `transfer` operation.
Otherwise, FA2 MUST fallback to the default behavior.

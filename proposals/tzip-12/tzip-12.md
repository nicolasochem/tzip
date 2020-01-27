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
can receive tokens. Token contract can support a single token type or multiple
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
sub-token id. If the underlying contract implementation supports only a single
token type (ERC-20-like contract), sub-token id is represented by `unit`. If the
underlying contract implementation supports multiple sub-tokens (in a Multi-Asset
Contract or MAC), sub-token id is represented by `nat`.

All entry points are batch operations which allow to query or transfer multiple
sub-token types atomically. If the underlying contract implementation supports
only a single token type, the batch will always contain a single entry and sub-token
id would be fixed `Single unit` value.

Token contract MUST implement the following entry points (notation is given in
[cameLIGO language](https://ligolang.org)):

```ocaml
type sub_token_id =
  | Single of unit
  | Mac of nat


type transfer = {
  from_ : address;
  to_ : address;
  token_id : sub_token_id;
  amount : nat;
}
type transfer_param = {
  batch : transfer list;
  data : bytes option;
}

type balance_request = {
  owner : address; 
  token_id : sub_token_id;  
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
  token_id : sub_token_id;
  supply : nat;
}

type total_supply_param = {
  total_supply_requests : sub_token_id list;
  total_supply_view : (total_supply_response list) contract;
}

type token_descriptor = {
  symbol: string;
  name : string;
  decimals : nat;
  extras : (string, string) map;
}

type token_descriptor_response = {
  token_id : sub_token_id;
  descriptor : token_descriptor;
}

type token_descriptor_param = {
  token_ids : sub_token_id list;
  token_descriptor_view : (token_descriptor_response list) contract
}

type hook_param = {
  from_ : address option;
  to_ : address option;
  batch : transfer list;
  data : bytes option;
  operator : address;
}

type set_hook_param = hook_param contract


type fa2_entry_points =
  | Transfer of transfer_param
  | Balance_of of balance_of_param
  | Total_supply of total_supply_param
  | Token_descriptor of token_descriptor_param
  | Set_sender_hook of set_hook_param option
  | Set_receiver_hook of set_hook_param option
  | Set_admin_hook of set_hook_param option
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
to the hooks. `SENDER` MUST be passed as an `operator` parameter to a hooks invocation.
If any of the invoked hooks fails, the whole transfer transaction MUST fail.
For more details on hooks semantics see "Transfer Hooks" section of this document.

#### `balance_of`

Get the balance of multiple account/token pairs. Accepts a list of `balance_request`s
and callback contract `balance_view` which accepts a list of pairs of `balance_request`
and balance amount.

#### `total_supply`

Get the total supply for multiple token types. Accepts a list of `total_supply_request`s
and callback contract `total_supply_view` which accepts a list of pairs of
`total_supply_request` and total supply amount.

#### `token_descriptor`

Get the total supply for multiple token types. Accepts a list of `sub_token_id`s
and callback contract `token_descriptor_view` which accepts a list of pairs of
`sub_token_id` and `token_descriptor`.

### Transfer Hooks

Using transfer hooks, it is possible to model different transfer permissioning
schemes like white lists, operator lists etc.

The standard supports three types of hooks (all with the same parameter type).
All hooks are optional and have two entry points (set/remove hook) per each type.
The concrete token contract implementation MAY impose additional restrictions on
who may set and/or remove hooks. If set/remove hook operation is not permissioned,
it MUST fail without changing registered hook state.

The following table provides a description of each hook type and its semantics:

| Hook  | Who can set/remove | When to invoke | Comments                       |
| :---  | :----------------- | :------------- | :----------------------------- |
| Admin | contract admin     | on every transfer operation | There is one or zero admin hooks per FA2 contract |
| Sender| token owner        | on transfer operation where `from_` parameter is the address of a hook owner | There is one or zero sender hooks per each token owner address |
| Receiver| token owner      | on transfer operation where `to_` parameter is the address of a hook owner | There is one or zero receiver hooks per each token owner address |

For each transfer operation token contract MUST invoke corresponding admin, sender
and receiver hooks and return corresponding operations as part of the transfer entry
point result in this exact order. If one or more hooks are not registered, they
are skipped.

Transfer operation MUST pass optional `data` parameter to hooks unaltered.

`operator` parameter for hook invocation MUST be set to `SENDER`.

`from_` parameter for hook invocation MUST be set to `Some(transaction.from_)`.

`to_` parameter for hook invocation MUST be set to `Some(transaction.to_)`.

If the same `from_` and/or `to_` addresses appear in more than one transfer in
the batch, corresponding sender/receiver hook MUST be called only once.

If the token contract implements mint and burn operations, they MUST invoke relevant
hooks as well.

| Hook |  Mint | Burn |
| :--- | :---- | :--- |
| Admin | Invoked if registered. `from_` parameter MUST be `None` | Invoked if registered. `to_` parameter MUST be `None`|
| Sender | Never invoked. | Invoked if there is a registered hook for an owner address which received minted tokens.  `to_` parameter MUST be `None` |
| Receiver | Invoked if there is a registered hook for an owner address from which tokens are burnt.  `from_` parameter MUST be `None` | Never invoked.|

### `set_sender_hook`

Set or remove a sender hook for a token owner. FA2 contract can have one or zero
sender hooks per token owner. Only token owner can set its own sender hook.
Token owner address is an implicit parameter, FA2 implementation MUST use `SENDER`
address to be associated with the hook.

If input parameter is `None`, sender hook is to be removed. If input parameter is
`Some` hook entry point, a new sender hook is to be associated with the token owner
address (`SENDER`).

If present, sender hook is invoked when `from_` parameter of the `transfer` operation
is the same as the address of the sender hook owner.

### `set_receiver_hook`

Set or remove a receiver hook for a token owner. FA2 contract can have one or zero
receiver hooks per token owner. Only token owner can set its own receiver hook.
Token owner address is an implicit parameter, FA2 implementation MUST use `SENDER`
address to be associated with the hook.

If input parameter is `None`, receiver hook is to be removed. If input parameter
is `Some` hook entry point, a new receiver hook is to be associated with the token
owner address (`SENDER`).

If present, receiver hook is invoked when `to_` parameter of the `transfer` operation
is the same as the address of the receiver hook owner.

### `set_admin_hook`

Set or remove an admin hook. FA2 contract can have one or zero admin hooks.
FA2 implementation MAY restrict access to this operation to a contract administrator
address only.

If input parameter is `None`, admin hook is to be removed. If input parameter
is `Some` hook entry point, a new admin hook is to be associated with the FA2 contract.

If present, admin hook is always invoked from the `transfer` operation.

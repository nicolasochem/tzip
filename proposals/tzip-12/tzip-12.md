# TZIP-12 - FA2

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
considerations lead to proliferation of multiple token standards, each optimized
for a particular use case.

Token wallets, token exchanges and other clients need to support multiple standards
and multiple token API. This standard proposes a unified token contract interface
which accommodates all mentioned concerns.

## Specification

Token type is uniquely identified by a pair of the token contract address and
sub-token id. If the underlying contract implementation supports only a single
token type (FA1.2 like contract), sub-token id is represented by `unit`. If the
underlying contract implementation supports multiple sub-tokens (MAC), sub-token
id is represented by `nat`.

All entry points are batch operations which allow to query or transfer multiple
sub-token types atomically. If the underlying contract implementation supports
only a single token type, the batch will alway contain a single entry and sub-token
id would be fixed `Single unit` value.

Token contract MUST implement the following entry points (notation is given in
[cameLIGO language](https://ligolang.org)):

```ocaml
type sub_token_id =
  | Single of unit
  | Mac of nat


type transfer = {
  token_id : sub_token_id;
  amount : nat;
}
type transfer_param = {
  from_ : address;
  to_ : address;
  batch : transfer list;
  data : bytes;
}

type balance_request = {
  owner : address; 
  token_id : sub_token_id;  
}

type balance_of_param = {
  balance_requests : balance_request list;
  balance_view : ((balance_request * nat) list) contract;
}

type total_supply_request = {
  owner : address; 
  token_id : sub_token_id;  
}

type total_supply_param = {
  total_supply_requests : total_supply_request list;
  total_supply_view : ((total_supply_request * nat) list) contract;
}

type token_descriptor = {
  url : string;
}

type token_descriptor_param = {
  token_ids : sub_token_id list;
  token_descriptor_view : ((sub_token_id * token_descriptor) list) contract
}

type hook_param = {
  from_ : address option;
  to_ : address option;
  batch : transfer list;
  data : bytes;
  operator : address;
}

type set_hook_param = hook_param contract


type fa2_entry_points =
  | Transfer of transfer_param
  | Balance_of of balance_of_param
  | Total_supply of total_supply_param
  | Token_descriptor of token_descriptor_param
  | Set_sender_hook of set_hook_param
  | Remove_sender_hook of address
  | Set_receiver_hook of set_hook_param
  | Remove_receiver_hook of address
  | Set_admin_hook of set_hook_param
  | Remove_admin_hook of unit
```

### Entry Point Semantics

#### `transfer`

Transfers amounts specified in the batch between two given addresses. Transfers
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

#### Transfer Hooks

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

`from_` parameter for hook invocation MUST be set to `Some(transaction_param.from_)`.

`to_` parameter for hook invocation MUST be set to `Some(transaction_param.to_)`.

If the token contract implements mint and burn operations, they MUST invoke relevant
hooks as well.

| Hook |  Mint | Burn |
| :--- | :---- | :--- |
| Admin | Invoked if registered. `from_` parameter MUST be `None` | Invoked if registered. `to_` parameter MUST be `None`|
| Sender | Never invoked. | Invoked if there is a registered hook for an owner address which received minted tokens.  `to_` parameter MUST be `None` |
| Receiver | Invoked if there is a registered hook for an owner address from which tokens are burnt.  `from_` parameter MUST be `None` | Never invoked.|

---
title: views - read-only accessing instructions
status: Draft
author: ChiaChi (cct@marigold.dev), Gabriel (ga@marigold.dev)
type: -
created: 2020-12-09
date: 2021-7-12
version: 1
---

## Summary

We propose read-only access from a contract to another. Two Michelson primitives `VIEW` (instruction) and `view` (top-level keywork) are added.

## Abstract

Currently, there is no direct way to get a value computed by another contract.  Inter-contract interactions must be performed in continuation-passing style (CPS); see for instance [the CPS views of TZIP-4](https://gitlab.com/tezos/tzip/-/blob/master/proposals/tzip-4/tzip-4.md#view-entrypoints). This brings complexity but also security risk because when calling a smart contract in CPS, the caller has no guarantee that the callee won't modify its storage or even call back.

We propose to extend Michelson with built-in read-only views. To this aim, two new Michelson primitives are introduced: the `view` top-level keyword (to declare a view) and the `VIEW` instruction (to call a previously declared view).

## Specification

Views are a mechanism for contract calls that:

- are read-only: they may depend on the storage of the contract declaring the view but cannot modify it nor emit operations (but they can call other views),
- take arguments as input in addition to the contract storage,
- return results as output,
- are synchronous: the result is immediately available on the stack of the caller contract.

In other words, the execution of a view is included in the operation of caller's contract, but accesses the storage of the declarer's contract, in read-only mode.
Thus, in terms of execution, views are more like lambda functions rather than contract entrypoints,
Here is an example:


    code {
    ...;
    TRANSFER_TOKENS;
    ...;
    VIEW "view_ex" unit;
    ...;
    };


This contract calls a contract `TRANSFER_TOKENS`, and, later on, a view called "view_ex".
No matter if the callee "view_ex" is defined in the same contract with this caller contract or not,
this view will be executed immediately in the current operation,
while the operations emitted by `TRANSFER_TOKENS` will be executed later on.
As a result, although it may seem that "view_ex" receives the storage modified by `TRANSFER_TOKENS`,
this is not the case.
In other words, the storage of the view is the same as when the current contract was called.
In particular, in case of re-entrance, i.e., if a contract A calls a contract B that calls a view on A, the storage of the view will be the same as when B started, not when A started.

Views are **declared** at the toplevel of the script of the contract on which they operate,
alongside the contract parameter type, storage type, and code.
To declare a view, the `view` keyword is used; its syntax is
`view name 'arg 'return { instr; ... }` where:

- `name` is a string of at most 31 characters matching the regular expression `[a-zA-Z0-9_.%@]*`; it is used to identify the view, hence it must be different from the names of the other views declared in the same script;
- `'arg` is the type of the argument of the view;
- `'return` is the type of the result returned by the view;
- `{ instr; ... }` is a sequence of instructions of type `lambda (pair 'arg 'storage_ty) 'return` where `'storage_ty` is the type of the storage of the current contract. Certain specific instructions have different semantics in `view`: `BALANCE` represents the current amount of mutez held by the contract where `view` is; `SENDER` represents the contract which is the caller of `view`; `SELF_ADDRESS` represents the contract where `view` is; `AMOUNT` is always 0 mutez.

Note that in both view input (type `'arg`) and view output (type `'return`), the following types are forbidden: `ticket`, `operation`, `big_map` and `sapling_state`.

Views are **called** using the following Michelson instruction:

-  `VIEW name 'return`: Call the view named `name` from the contract whose address is the second element of the stack, sending it as input the top element of the stack.

```
'arg : address : 'S  ->  option 'return : 'S

> VIEW name 'return / x : addr : S  =>  Some y : S
    iff addr is the address of a smart contract c with storage s
    where c has a toplevel declaration of the form "view name 'arg 'return { code }"
    and code / Pair x s : []  =>  y : []

> VIEW name 'return / _ : _ : S  =>  None : S
    otherwise
```

If the given address is nonexistent or if the contract at that address does not have a view of the expected name and type,
`None` will be returned.
Otherwise, `Some a` will be returned where `a` is the result of the view call.
Note that if a contract address containing an entrypoint `address%entrypoint` is provided,
only the `address` part will be taken.
`operation`, `big_map` and `sapling_state` and `ticket` types are forbidden for the `'return` type.


Here is an example using views, consisting of two contracts.
The first contract defines two views at toplevel that are named `add_v` and `mul_v`.


    { parameter nat;
      storage nat;
      code { CAR; NIL operation ; PAIR };
      view "add_v" nat nat { UNPAIR; ADD };
      view "mul_v" nat nat { UNPAIR; MUL };
    }


The second contract calls the `add_v` view of the above contract and obtains a result immediately.


    { parameter (pair nat address) ;
      storage nat ;
      code { CAR ; UNPAIR; VIEW "add_v" nat ;
             IF_SOME { } { FAIL }; NIL operation; PAIR }; }


## Backwards Compatibility

The change is adding new instructions without changing the fundamental architecture. It's backward compatible.

## Test Cases

https://gitlab.com/tezos/tezos/-/merge_requests/2359/


## Implementations

https://gitlab.com/tezos/tezos/-/merge_requests/2359/

## Appendix

- [Adding Read-Only Calls](https://forum.tezosagora.org/t/adding-read-only-calls/1227)
- [Merge Request](https://gitlab.com/tezos/tezos/-/merge_requests/2359)
- [Concurrency, BFS vs DFS (and a proposal)](https://forum.tezosagora.org/t/concurrency-bfs-vs-dfs-and-a-proposal/1994)
- [Problems with Concurrency](https://forum.tezosagora.org/t/problems-with-concurrency/1771)


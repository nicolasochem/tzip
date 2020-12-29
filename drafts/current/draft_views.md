
---
title: views - read-only accessing instructions
status: Draft
author: ChiaChi (cct@marigold.dev), Gabriel (ga@marigold.dev)
type: -
created: 2020-12-09
date: 2020-12-16
version: 0
---

## Summary

This propose is to provide ways for read-only accessing anther contracts. Three Michelson instructions `GET_STORAGE`, `VIEW` (operation) and `VIEW` (on top-level) are implemented for.

## Abstract

Currently, there is no direct way to get output from another contract. The sequence of operations execution of Tezos was designed in Breadth First Search order. That allows Tezos satisfied in terms of ACID transactions. However, it prevents us to interact with another contract. If it breaks each of the terms, it may repeat the mistake like reentrancy attacks. Therefore, the available solution is proposed as read-only in Continuation Passing Style. Three Michelson instructions `GET_STORAGE`, `VIEW` (operation) and `VIEW` (on top-level) are providing for this.  

## Specification

For the Three Michelson instructions:

- `GET_STORAGE 'return_ty`: It allows obtaining storage contents from a given address. If the given address is nonexistent, NONE will be returned. Otherwise, Some a will be returned.
    
    > address : 'S -> option 'return : 'S
    >\> GET_STORAGE 'return_ty / address : S => option 'return_ty : S
       
- `VIEW name 'arg_ty 'return_ty { (instr) ; ... }`: This VIEW should be defined in the top-level. Like the main Michelson program, it maintains a stack and its initial value contains a pair in which the first element is an input value and the second element is a storage contents .

- `VIEW name 'arg_ty 'return_ty`: It allows to use of predefine VIEW in top-level and a result can be obtained immediately. If the given address or name is nonexistent, NONE will be returned. Otherwise, Some a will be returned.

    > arg : address : 'S -> option 'return_ty : 'S
    >\> VIEW name 'arg_ty 'return_ty / arg : address : S => option 'return_ty : S
    
Here is an example of contracts: In the first contract, it defines two view s in top-level which named add_v and mul_v.

    { parameter nat;
      storage nat;
      code { CAR; NIL operation ; PAIR };
      view "add_v" nat nat { UNPAIR; ADD };
      view "mul_v" nat nat { UNPAIR; MUL };
    }
    
In this contract, it calls the add_v of the above contract and obtains a result immediately.

    { parameter (pair nat address) ;
      storage nat ;
      code { CAR ; UNPAIR; VIEW "add_v" nat nat ;
             IF_SOME { } { FAIL }; NIL operation; PAIR }; 
    }
    
In this one, it obtains storage contents from a given address.

    { parameter (pair nat address) ;
      storage nat;
      code { CAR ; UNPAIR; DROP; GET_STORAGE nat ;
             IF_SOME { } { FAIL } ; NIL operation ; PAIR }
    }

## Backwards Compatibility

The change is adding new instructions without changing the fundamental architecture. It's backward compatible.

## Test Cases

### test cases for compile time error 
- VIEW toplevel
    - multiple entries with the repeating name should return D`uplicated_view_name`.
    - if the return type mismatch type from its signature, the message "not compatible with type" will be returned.
    - if the number of arguments of `VIEW`, the message "primitive view expects 4 arguments" will be return
    - if the name of `VIEW` isn't a string, return `Bad_view_name`.

- VIEW op
    - if the number of arguments of `VIEW`, the message "primitive view expects 3 arguments" will be return
    - if the name of `VIEW` isn't a string, return `Bad_view_name`
    - if the return type mismatch, the type error message, for example, "two branches don't end with the same stack type", will be returned.
    - if the input type mismatch, the message "not compatible with type" will be returned.


- GET_STORAGE op
    - if the number of arguments of `GET_STORAGE`, the message "primitive view expects 1 argument" will be returned.


### test cases for runtime
- VIEW toplevel
    - multiple entries with regular cases → ok
    - identity review (the view code block is empty): return Pair (arg, storage) → ok
    - testing arbitrary operation: add → ok

- VIEW op
    - if the target address is nonexistent, return `None`.
    - if the target function is nonexistent, return `None`.
    - if the input type mismatch to target contract's `VIEW`, return `None`
    - if the output type mismatch to target contract's `VIEW`, return `None`

- GET_STORAGE op
    - regular case, return `Some a`.
    - if the target address is nonexistent, return `None`
    - if the type mismatch to target contract's storage, return `None`

## Implementations

- `src/proto_alpha/lib_protocol/michelson_v1_gas.ml`
Define the gas consumption of new Michelson instructions

- `src/proto_alpha/lib_protocol/script_interpreter.ml`
Define the evaluation of new Michelson instructions.

- `src/proto_alpha/lib_protocol/script_ir_translator.ml`
Define the type-checking of new Michelson instructions.

## Appendix

- [Adding Read-Only Calls](https://forum.tezosagora.org/t/adding-read-only-calls/1227)
- [Merge Request](https://gitlab.com/tezos/tezos/-/merge_requests/2359)
- [Concurrency, BFS vs DFS (and a proposal)](https://forum.tezosagora.org/t/concurrency-bfs-vs-dfs-and-a-proposal/1994)
- [Problems with Concurrency](https://forum.tezosagora.org/t/problems-with-concurrency/1771)


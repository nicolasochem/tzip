---
title: Iteration over range of numbers
status: Draft
author: Arthur (@murbard), Raphaël (@rafoo_), Fedor (@shrmtv)
type: L
created: 2021-08-02
date: 2021-08-02
version: 0
---


## Summary

This TZIP proposes extension of Michelson language to support "for" loops.

## Abstract

At the moment Michelson offers instructions for iterating over lists, sets, or
maps (`ITER`), for iteration until some condition is false (`LOOP`), and for
iteration with accumulator (`LOOP_LEFT`). We propose to add support for
iteration over range of numbers, in a few variations.

## Motivation

Dedicated instruction for iteration over range of numbers should improve code
readability and reduce gas cost, compared to defining similar behaviour
implemented via `LOOP` instruction.

Iteration defined as number of steps maybe be useful for a "cleanup" entry point
of a contract. Cleanup that requires iteration over large data structure may not
complete at once, due to gas limit. In this case entrypoint can be implemented
as a loop, doing some number of cleanup steps and stopping, relying on another
transaction to continue cleanup. Author of the contract would adjust number of
steps in a single cleanup transaction to avoid hitting gas limit.

## Specification

We propose to extend existing `ITER instr` instruction and support argument of
the following types on the stack (in addition to supported `list`, `set`, and
`map`):
- `nat`
- `pair nat nat`,
- `pair int int`,
- `pair nat nat nat`,
- `pair int int int`.

Variant taking single argument `end` would apply `instr` to the sequence of
values `0`, `1`, .. , `end - 1`. This variant supports only `nat` type because
ranges starting at zero and ending at a negative number would be empty.

Variant taking two arguments `start` and `end` would apply `instr` to the
sequence of values `start`, `start + 1`, .. , `end - 1`.

Variant taking three arguments `start`, `end`, and `step` would apply `instr` to
the sequence of values `start`, `start + step`, `start + (step * 2)` .. ,
`start + (step * k)` where `start + (step * k) < end` if `step` is positive, or
`start + (step * k) > end` if `step` is negative. This is similar to `range()`
function in Python.

Note that in the case of `int` arguments any of `start`, `end` and `step` values
can be negative.

Range may be empty (e.g. if `start >= end`) - in that case `instr` should not be
executed.

Example of a contract using new `ITER` instruction (for parameter value `n` adds
values `0`, `1`, .. , `n - 1` to the value in storage).

```
parameter nat;
storage nat;
code { UNPAIR; SWAP;
       ITER { ADD };
       NIL operation; PAIR }

```

## Rationale

We propose to extend existing instruction `ITER` rather than add a new one (e.g.
`ITER_N`) because semantics of iteration of over range of number is very close
to iteration over list of numbers.

## Backwards Compatibility

Existing `ITER` instruction for lists and sets should not be affected.

## Security Considerations

It should not be possible to construct infinite loop using this new instruction.

## Test Cases

Integration tests should cover edge cases (empty range etc.). Also we should
test that iteration over large range of numbers is terminated when it runs out
of gas.

## Implementations

Implementation of the simplest case (single `nat` argument) is provided in
https://gitlab.com/tezos/tezos/-/merge_requests/3311.

## Appendix

Original suggestion and discussion: https://gitlab.com/tezos/tezos/-/issues/802.

Ranges in Python for comparison:
https://docs.python.org/3/library/stdtypes.html#range.

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

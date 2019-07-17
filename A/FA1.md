---
tzip: FA1
title: Unsafe Ledger
status: WIP
type: Financial Application
author: John Burnham, Konstantin Ivanov
advocate: John Burnham, Konstantin Ivanov
created: 2019-04-12
---

## Summary

This document describes a smart contract that implements a ledger that maps
identities to balances. This ledger is described in a minimalistic way, and is
inteneded to be just a starting point or a single component of an application,
and not an application in its own right. To reemphasize: **This ledger is
unsafe. Do not use it without first adding safety features.**

Ideally, developers will prevent users from directly interacting with this
ledger at all and will layer additional interfacing contracts over it.

## Abstract

There is a need for a minimal abstract ledger that can be used as a component in
applications requiring some notion of fungible asset (or "token"). The space of
all possible contracts that require fungibility is vast, so this standard is
defined in the most general possible way.

Important possible features such as transfer approvals, fallback addresses or
monetary supply management are left to developers or extensions of this
standard.

## Unsafe Ledger Interface

This interface relies on [multiple entrypoints feature](https://gitlab.com/nomadic-labs/tezos/merge_requests/59). According to it, parameter of any contract implementing the interface should be a tree of `Or`s, some of its leaves should correspond to interface methods.

For FA1, parameter should contain the following leaves:

1. `(address :to, nat :value) %transfer`
2. `view unit nat             %getTotalSupply`
3. `view address nat          %getBalance`

See also [syntax explanation](https://gitlab.com/tzip/tzip/blob/master/A/A1.md#adt-syntax-sugar) and [Michelson Contract Interfaces and Conventions Document](https://gitlab.com/tzip/tzip/blob/master/A/A1.md#view-entry-points).

## Entry-points

### transfer

This entry point will credit the account of the addresss passed in the
parameter, while debiting the account matching the contract source address.
Should the source address have insufficient funds, the transaction will fail and
no state will be mutated.

### getTotalSupply

This view returns the sum of all participants' balances.

### getBalance

This view will return balance of the given address, or zero if no such address
is registered.

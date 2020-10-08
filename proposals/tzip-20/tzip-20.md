---
tzip: 20
title: Off-chain Events
author: Michael Zaikin <mz@baking-bad.org>
status: Work In Progress
type: Interface
created: 2020-10-07
requires: TZIP-16
---

## Summary

An extension of the [Contract Metadata](https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-16/tzip-16.md) standard specifying new kinds of [Off-chain Views](https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-16/tzip-16.md#semantics-of-off-chain-views) which are intended to derive an additional receipt from the operation's content and result without extra context queries.

## Abstract

Off-chain events can be used for various purposes but one of the most obvious use cases is indexing token balances.  
The problem is that it's not possible for the indexer to determine which particular balances have changed if the invoked method is not standardized (e.g. FA2/FA1.2 transfer), or if there was an initial token distribution at the origination.  
The current approach is using custom handlers for known contracts. Obviously, it is tied to a specific indexer implementation and is not scalable, so we need a better alternative that is:

* Flexible enough to cover the majority of cases;
* Simple enough to implement/integrate with existing codebase;
* Not tied to any specific entity nor implementation.

A reasonable approach is to take all the custom logic out of the indexer and enable contract developers to write those pieces of logic. A suggested path is to reuse TZIP-16 inerface and introduce several new Off-chain View kinds for deriving token balance updates (receipts).
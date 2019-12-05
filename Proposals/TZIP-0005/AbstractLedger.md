---
tzip: 5 (FA1)
author: John Burnham, Konstantin Ivanov
created: 2019-07-17
---

## Summary

This document describes an implementation of [FA1 interface](/Proposals/TZIP-0005/FA1.md).

Michelson code of resulting contract can be found [here](/Proposals/TZIP-0005/AbstractLedger.tz).

## Unsafe Ledger Parameter

```
parameter
  ( (address :from, (address :to, nat :value)) %transfer
  | view unit nat                              %getTotalSupply
  | view (address :owner) nat                  %getBalance
  );
```

See also [syntax explanation](/Proposals/TZIP-0004/A1.md#pairs-and-ors-syntax-sugar) and [Michelson Contract Interfaces and Conventions Document](/Proposals/TZIP-0004/A1.md#view-entrypoints).

## Unsafe Ledger Storage

```
storage (big_map address nat, nat :total_supply);
```

The storage maintains a map of addresses to balances.

The `nat :total_supply` is to be supplied by the originator and must correctly
equal the sum of all balances in the `big_map` at origination. Any changes to
the sum of balances must be reflected by a corresponding changing the `nat
:total_supply`

## Implementation

This contract has been written in Lorentz eDSL - a [language over Haskell](https://hackage.haskell.org/package/morley-0.3.0.1) which provides some extensions to basic Michelson and generally improves development experience.

The contract code can be found
[here](https://gitlab.com/morley-framework/morley/blob/ce28076a79b93d48aa7745271e6a1395b8b9e50d/lorentz-contracts/src/Lorentz/Contracts/AbstractLedger.hs), resulting Michelson code resides [here](/Proposals/TZIP-0005/AbstractLedger.tz).

### Compiling Lorentz contract

In order to compile Lorentz implementation of Managed Ledger into Michelson the following steps should be performed:
1. [Build the project](https://gitlab.com/morley-framework/morley/blob/ce28076a79b93d48aa7745271e6a1395b8b9e50d/README.md#running-and-building).
2. Run `stack exec lorentz-contracts -- print -n AbstractLedger > AbstractLedger.tz`.

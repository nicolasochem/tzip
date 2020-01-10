---
tzip: 5
author: John Burnham, Konstantin Ivanov <kivanov@serokell.io>
created: 2019-07-17
---

## Summary

This document describes an implementation of the [TZIP-5](/proposals/tzip-5/tzip-5.md) interface.

Michelson code of resulting contract can be found [here](/proposals/tzip-5/AbstractLedger.tz).

## Unsafe Ledger Parameter

```
parameter
  ( (address :from, (address :to, nat :value)) %transfer
  | view unit nat                              %getTotalSupply
  | view (address :owner) nat                  %getBalance
  );
```

See also [syntax explanation](/proposals/tzip-4/tzip-4.md#pairs-and-ors-syntax-sugar) and [Michelson Contract Interfaces and Conventions Document](/proposals/tzip-4/tzip-4.md#view-entrypoints).

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
[here](https://gitlab.com/morley-framework/morley/blob/ce28076a79b93d48aa7745271e6a1395b8b9e50d/lorentz-contracts/src/Lorentz/Contracts/AbstractLedger.hs), resulting Michelson code resides [here](/proposals/tzip-5/AbstractLedger.tz).

### Compiling Lorentz contract

In order to compile Lorentz implementation of Managed Ledger into Michelson the following steps should be performed:
1. [Build the project](https://gitlab.com/morley-framework/morley/blob/ce28076a79b93d48aa7745271e6a1395b8b9e50d/README.md#running-and-building).
2. Run `stack exec lorentz-contracts -- print -n AbstractLedger > AbstractLedger.tz`.

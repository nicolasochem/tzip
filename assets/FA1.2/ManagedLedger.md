---
tzip: FA1.2
title: Managed Ledger
type: Financial Application
author: Konstantin Ivanov, Ivan Gromakovskii
advocate: Konstantin Ivanov, Ivan Gromakovskii
created: 2019-06-24
---

## Summary

This document describes a smart contract which implements
[FA1.2 interface](/A/FA1.2.md).
This contract also maintains an entity called _administrator_ which has an exclusive right to perform management operations like `Mint` and `Pause`.

## Managed Ledger parameter

Parameter of this contract has the following type:

```
parameter

  # Implementation of FA1.2
  or ((address :from, address :to, nat :value)  %transfer) (
  or ((address :spender, nat :value)            %approve) (
  or ((view (address :owner, address :spender) (nat :remaining))
                                                %getAllowance) (
  or ((view (address :owner) (nat :balance))    %getBalance) (
  or ((view unit (nat :totalSupply))            %getTotalSupply) (

  # Additional operations
  or (bool                                      %setPause) (
  or (address                                   %setAdministrator) (
  or ((view () (address :administrator))        %getAdministrator) (
  or ((address :to, nat :value)                 %mint) (
  or ((address :from, nat :value)               %burn)

  )))))))));
```

See also [syntax explanation](https://gitlab.com/tzip/tzip/blob/master/A/A1.md#adt-syntax-sugar) and [Michelson Contract Interfaces and Conventions Document](https://gitlab.com/tzip/tzip/blob/master/A/A1.md#view-entry-points).

## Errors

This contract follows exactly the same format for errors as described in
[FA1.2](/A/FA1.2.md#Errors).

For example, if an entry point is stated to fail with `SenderIsNotAdmin` error,
then a client should expect contract to fail with `("SenderIsNotAdmin", Unit)` pair.
The second element of this pair may vary depending on the kind of error.

## Entry-points

Along with entry points supposed by FA1.2, this contract exposes basic management operations.

### setPause

This entry point pauses operations when the parameter is `True`,
and resumes them when the parameter is `False`. During the pause,
no contract can perform `transfer` or `approval` operations.

The administrator is still allowed to perform his operations.

This entry point can fail with the following errors:
* `SenderIsNotAdmin` - caller is not the token administrator.

### setAdministrator

Change the current administrator.

This entry point can fail with the following errors:
* `SenderIsNotAdmin` - caller is not the token administrator.

### getAdministrator

This view returns the current administrator.

### mint

This entry point produces tokens on the account associated with the given address.

Can fail with the following errors:
* `SenderIsNotAdmin` - caller is not the token administrator.

### burn

This entry point destroys the given amount of tokens on the account associated with the given address.

Can fail with the following errors:
* `SenderIsNotAdmin` - caller is not the token administrator.
* `NotEnoughBalance` - insufficient funds on the given account.
The error will contain a `(nat :required, nat :present)` pair, where
`required` is requested amount of tokens to burn, `present` is available amount.

## Implementation

This contract has been written in Lorentz eDSL - a [language over Haskell](https://hackage.haskell.org/package/morley-0.3.0.1) which provides some extensions to basic Michelson and generally improves development experience.

The contract code can be found
[here](https://gitlab.com/morley-framework/morley/blob/436127c4b2a4fe9c3f0fb512dc01148a96be9be6/lorentz-contracts/src/Lorentz/Contracts/ManagedLedger.hs).

Resulting contract in Michelson is [also provided](./ManagedLedger.tz).

### Compiling Lorentz contract

Currently, in order to compile Lorentz implementation of Managed Ledger into Michelson the following steps should be performed:
1. [Build the project](https://gitlab.com/morley-framework/morley/blob/436127c4b2a4fe9c3f0fb512dc01148a96be9be6/README.md#running-and-building).
2. Run `stack exec lorentz-contracts -- print -n ManagedLedger > ManagedLedger.tz`.
3. Add necessary annotations to contract parameter type.
At the moment, this step has to be performed manually because Lorentz does not support annotations (it provides similar safety guarantees in a different way). We are [planning to implement this feature](https://issues.serokell.io/issue/TM-64), after which annotations will be set automatically.
4. After step 3 contract may stop compiling, reporting mismatch of some annotations. Insert required `CAST` instructions.

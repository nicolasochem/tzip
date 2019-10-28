---
tzip: FA1.2
author: Konstantin Ivanov, Ivan Gromakovskii
created: 2019-06-24
---

## Summary

This document describes a smart contract that implements [FA1.2 interface](/A/FA1.2.md).
The contract also maintains an entity called _administrator_ which has an exclusive right to perform management operations like `Mint` and `Pause`.

The contract compiled to Michelson is provided in [ManagedLedger.tz](/assets/FA1.2/ManagedLedger.tz).

## Managed Ledger interface

`ManagedLedger.md` has entrypoints specified in FA1.2 along with additional entrypoints which make the ledger _managed_:
  * `bool %setPause`
  * `address %setAdministrator`
  * `(view () address) %getAdministrator`
  * `(address :to, nat :value) %mint`
  * `(address :from, nat :value) %burn`

See also:
* [Syntax sugar explanation](/A/A1.md#pairs-and-ors-syntax-sugar).
* [Explanation of `view`](/A/A1.md#view-entrypoints).

## Deployment

To deploy `ManagedLedger.tz`, you have to originate the contract with the following initial value and it will be immediately usable:
`Pair {} (Pair MANAGER_ADDR (Pair False 0))`.
Here `MANAGER_ADDR` is the address of the manager, `False` means that operations are not paused and `0` is the initial total supply.

## Errors

The contract follows exactly the same format for errors as described in
[FA1](/A/FA1.md#errors).

For example, if an entrypoint is stated to fail with `SenderIsNotAdmin` error,
then a client should expect contract to fail with `("SenderIsNotAdmin", Unit)` pair.
The second element of this pair may vary depending on the kind of error.

## Entrypoints

Along with entrypoints described in FA1.2, the contract exposes basic management operations.

### setPause

This entrypoint pauses operations when the parameter is `True`,
and resumes them when the parameter is `False`. During the pause,
no contract can perform `transfer` or `approval` operations.

The administrator is still allowed to perform management operations: `mint`, `burn` and `setAdministrator`.

This entrypoint can fail with the following errors:
* `SenderIsNotAdmin` - caller is not the token administrator.

### setAdministrator

Change the current administrator.

This entrypoint can fail with the following errors:
* `SenderIsNotAdmin` - caller is not the token administrator.

### getAdministrator

This view returns the current administrator.

### mint

This entrypoint produces tokens on the account associated with the given address.

Can fail with the following errors:
* `SenderIsNotAdmin` - caller is not the token administrator.

### burn

This entrypoint destroys the given amount of tokens on the account associated with the given address.

Can fail with the following errors:
* `SenderIsNotAdmin` - caller is not the token administrator.
* `NotEnoughBalance` - insufficient funds on the given account.
The error will contain a `(nat :required, nat :present)` pair, where
`required` is requested amount of tokens to burn, `present` is available amount.

## Implementation

The contract has been written in Lorentz eDSL - a [language over Haskell](https://hackage.haskell.org/package/morley-0.3.0.1) which provides some extensions to basic Michelson and generally improves development experience.

The contract code can be found
[here](https://gitlab.com/morley-framework/morley/tree/0b649ef128f7282b4bcc985792cf70ad58d8c7b5/lorentz-contracts/src/Lorentz/Contracts/ManagedLedger.hs).

### Compiling Lorentz contract

Currently, in order to compile Lorentz implementation of Managed Ledger into Michelson the following steps should be performed:
1. [Build the project](https://gitlab.com/morley-framework/morley/blob/0b649ef128f7282b4bcc985792cf70ad58d8c7b5/README.md#running-and-building).
2. Run `stack exec lorentz-contracts -- print -n ManagedLedger -o ManagedLedger.tz`.
3. Add necessary annotations to contract parameter type.
At the moment, this step has to be performed manually because Lorentz does not support annotations (it provides similar safety guarantees in a different way). We are [planning to implement this feature](https://issues.serokell.io/issue/TM-64), after which annotations will be set automatically.
4. After step 3 contract may stop compiling, reporting mismatch of some annotations. Insert required `CAST` instructions.

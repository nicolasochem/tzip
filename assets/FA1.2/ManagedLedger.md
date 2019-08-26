---
tzip: FA1.2
author: Konstantin Ivanov, Ivan Gromakovskii
created: 2019-06-24
---

## Summary

This document describes smart contracts which implement
[FA1.2 interface](/A/FA1.2.md) and its modification for Athens — [FA1.2.1](/A/FA1.2.1.md).
The contracts also maintain an entity called _administrator_ which has an exclusive right to perform management operations like `Mint` and `Pause`.

We provide two implementations:
* One is simpler and satisfies the requirement of FA1.2 which says that the contract must have certain entrypoints.
It targets Babylon and future versions of Michelson.
* The other one satisfies FA1.2.1.
It targets Athens and implements the approach proposed in the [relevant section of FA1.2.1](/A/FA1.2.1.md#implementation-suggestions).

There are three contracts:
* `ManagedLedger` is the version for Babylon.
* `ManagedLedgerAthens` is a more complicated version with additional entrypoints which make it usable by proxy.
* `ManagedLedgerProxy` is a proxy contract which has parameter type required by FA1.2.1 and calls `ManagedLedgerAthens`.

These contracts compiled to Michelson are [provided in this directory](/assets/FA1.2).

## Managed Ledger interface

* All three contracts have entrypoints specified in FA1.2.
* `ManagedLedgerProxy.md` has parameter type that we call `fa12core` in FA1.2.1.
It does not have any additional entrypoints.
* `ManagedLedgerAthens.md` has `transferViaProxy`, `approveViaProxy` and `setProxy` entrypoints as described in FA1.2.1.
* Both `ManagedLedgerAthens.md` and `ManagedLedger.md` have additional entrypoints which make these ledgers _managed_:
    * `bool %setPause`
    * `address %setAdministrator`
    * `(view () address) %getAdministrator`
    * `(address :to, nat :value) %mint`
    * `(address :from, nat :value) %burn`

See also:
* [Syntax sugar explanation](/A/A1.md#pairs-and-ors-syntax-sugar).
* [Explanation of `view`](/A/A1.md#view-entry-points).

## Deployment

* Deployment of `ManagedLedger.tz` is straightforward.
You have to originate the contract with the following initial value and it will be immediately usable:
`Pair {} (Pair MANAGER_ADDR (Pair False 0))`.
Here `MANAGER_ADDR` is the address of the manager, `False` means that operations are not paused and `0` is the initial total supply.
* Deployment of FA1.2.1 compatible contract is more complicated.
You have two originate two contracts and call one entrypoint.
  1. Originate `ManagedLedgerAthens.tz` first.
  Its initial storage value should be the following:
  `Pair {} (Pair (Pair MANAGER_ADDR False) (Pair 0 (Left YOUR_ADDR)))`.
  The additional field is `Left YOUR_ADDR`.
  `YOUR_ADDR` should be some address from which you can send a transaction.
  2. After that originate `ManagedLedgerProxy.tz` passing the address of `ManagedLedgerAthens.tz` as its initial storage.
  3. At the last step you should call the `setProxy` entrypoint of `ManagedLedgerAthens.tz` with the address of `ManagedLedgerProxy.tz`.
  You should pass the following parameter: `Right (Right (Right (Right PROXY_ADDR))))`.

## Errors

These contracts follow exactly the same format for errors as described in
[FA1.2](/A/FA1.2.md#errors).

For example, if an entry point is stated to fail with `SenderIsNotAdmin` error,
then a client should expect contract to fail with `("SenderIsNotAdmin", Unit)` pair.
The second element of this pair may vary depending on the kind of error.

## Entry-points

Along with entry points described in FA1.2, these contracts expose basic management operations.

### setPause

This entry point pauses operations when the parameter is `True`,
and resumes them when the parameter is `False`. During the pause,
no contract can perform `transfer` or `approval` operations.

The administrator is still allowed to perform management operations: `mint`, `burn` and `setAdministrator`.

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

These contracts have been written in Lorentz eDSL - a [language over Haskell](https://hackage.haskell.org/package/morley-0.3.0.1) which provides some extensions to basic Michelson and generally improves development experience.

The contracts code can be found
[here](https://gitlab.com/morley-framework/morley/tree/e4915c5b7d4e0dfea19ad5044ff3ea63ffbeb4cc/lorentz-contracts/src/Lorentz/Contracts/ManagedLedger).

### Compiling Lorentz contracts

Currently, in order to compile Lorentz implementation of Managed Ledger into Michelson the following steps should be performed:
1. [Build the project](https://gitlab.com/morley-framework/morley/blob/e4915c5b7d4e0dfea19ad5044ff3ea63ffbeb4cc/README.md#running-and-building).
2. Run `stack exec lorentz-contracts -- print -n CONTRACT_NAME -o CONTRACT_NAME.tz`.
`CONTRACT_NAME` can be one of the following `ManagedLedger`, `ManagedLedgerProxy`, `ManagedLedgerAthens`.
3. Add necessary annotations to contract parameter type.
At the moment, this step has to be performed manually because Lorentz does not support annotations (it provides similar safety guarantees in a different way). We are [planning to implement this feature](https://issues.serokell.io/issue/TM-64), after which annotations will be set automatically.
4. After step 3 contract may stop compiling, reporting mismatch of some annotations. Insert required `CAST` instructions.

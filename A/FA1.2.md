---
tzip: FA1.2
title: Approvable Ledger
type: Financial Application
author: Konstantin Ivanov, Ivan Gromakovskii
advocate: Konstantin Ivanov, Ivan Gromakovskii
created: 2019-06-20
---

## Summary

This document describes a smart contract which implements a ledger that maps
identities to balances. This ledger implements token transfer operations,
as well as approvals for spending tokens from other accounts.

## Approvable Ledger Interface

A contract which implements approvable ledger must have a parameter of type

```
parameter
  or ((address :from, address :to, nat :value)      %transfer) (
  or ((address :spender, nat :value)                %approve) (
  or ((view (address :owner, address :spender) nat) %getAllowance) (
  or ((view (address :owner) nat)                   %getBalance) (
  or ((view unit nat)                               %getTotalSupply)
     x
  )))));
```
for some `x`.

Note that this parameter is consitent with [multiple entrypoints feature](https://gitlab.com/nomadic-labs/tezos/merge_requests/59).
Once implemented, the contract's extension point can be used to add new entry points in a backward-compatible way.

See also [syntax explanation](https://gitlab.com/tzip/tzip/blob/master/A/A1.md#adt-syntax-sugar) and [Michelson Contract Interfaces and Conventions Document](https://gitlab.com/tzip/tzip/blob/master/A/A1.md#view-entry-points).

## Errors

Failures of this contract are represented as
`(string, d)` pairs, the first element of which
is an identifier of an error and the second element keeps details of this error,
or `unit` if no details required.

For example, attempt to withdraw `5` tokens when only `3` is present
will result in the following error:
`("NotEnoughBalance", (5, 3))`

## Entry-points

### transfer

This entry point will credit the account of the address passed in the
`"to"` parameter, while debiting the account corresponding to the `"from"` parameter.
Should the sender address have insufficient funds, the transaction will fail and
no state will be mutated.

This entry point serves multiple purposes.
When called with `"from"` account equal to the transaction sender, we assume that
the user transfers their own money and this does not require approval. Otherwise,
the amount of approval equal to the number of transferred tokens is consumed.

This entry point can fail with the following errors:
* `NotEnoughBalance` - insufficient funds on the sender account to perform a given
transfer. The error will contain a `(nat :required, nat :present)` pair, where
`required` is the requested amount of tokens, `present` is the available amount.
* `NotEnoughAllowance` - a given account has no permission to withdraw a given
amount of funds. The error will contain a `(nat :required, nat :present)` pair,
where `required` is the requested amount of tokens, `present` is the current allowance.

### approve

This entry point called with `(address: to, nat: val)`
parameters allows `to` account to withdrawal from the sender, multiple times,
up to the `val` amount. Each call of `transfer` entry point decreases the
allowance amount on the transferred amount of tokens.

If this entry point is called again, it overwrites the current allowance
with `val`.

Changing approval value from non-zero value to a non-zero value is
forbidden to prevent the [corresponding attack vector](https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM).

This entry point can fail with the following errors:
* `UnsafeAllowanceChange` - attempt to change approval value from non-zero to
non-zero was performed. The error will contain `nat :previous` value, where
`previous` stands for the allowance value upon the contract call.

### getAllowance

This view will return the approval value between two given addresses.

### getBalance

This view will return the balance of the address in the ledger.

### getTotalSupply

This view simply returns the total number of tokens.

## Related work

[ERC-20](https://eips.ethereum.org/EIPS/eip-20) is a standard used in Ethererum for implementing tokens.
It also describes transfer and approval operations.
The interface we propose here differs from ERC-20. Specifically, we have `transfer`
and `transferFrom` analogies merged into a single entry point.
Also, ERC-20 is known to suffer from some vulnerabilities, and we took them into
account when implementing our interface.

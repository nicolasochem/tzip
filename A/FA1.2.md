---
tzip: FA1.2
title: Approvable Ledger
status: WIP
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

A contract which implements approvable ledger must have the following entrypoints:
* `(address :from, (address :to, nat :value))    %transfer`
* `(address :spender, nat :value)                %approve`
* `(view (address :owner, address :spender) nat) %getAllowance`
* `(view (address :owner) nat)                   %getBalance`
* `(view unit nat)                               %getTotalSupply`

See also:
* [Syntax sugar explanation](./A1.md#pairs-and-ors-syntax-sugar).
* [Explanation of `view`](./A1.md#view-entry-points).

## Entrypoints in Michelson

Entrypoints are added to Michelson in Babylon update which should become available in Mainnet on October 15.
Since our proposed interface relies on this feature, it can not be used in the previous version before Babylon — Athens.
Hence we propose a temporary approvable ledger standard in another TZIP — [FA1.2.1](./FA1.2.1.md).
That TZIP has a stricter requirement on the parameter type.

Our guidance is the following:
1. First of all, if you develop a simple Approvable Ledger which does not have any entrypoints apart from required by this document,
your contract should comply with [FA1.2.1](./FA1.2.1.md) even if you do not plan to use it in Athens.
2. If you develop an "Approvable Ledger" contract which is not supposed to be used in Mainnet until Babylon is available, you can ignore FA1.2.1 and adhere to this document.
3. If you develop an "Approvable Ledger" smart contract and want to use it in Athens, please refer to [FA1.2.1](./FA1.2.1.md).
Once Babylon is available in Mainnet, you are encouraged to ask users of your contract to update their code so that it uses the entrypoints feature of Michelson and can rely on FA1.2 instead.
4. If you develop an application or a smart contract which should work with an arbitrary Approvable Ledger and do not plan to use it in Mainnet until Babylon, you MUST use the entrypoints feature of Michelson to call FA1.2 methods and rely only on this document (FA1.2).
You can use a network running Babylon for testing (e. g. Zeronet).
5. If you develop an application or a smart contract which should work with an arbitrary Approvable Ledger and want to use it in Athens, you MUST require that smart contracts you work with comply with FA1.2.1.

## Errors

Failures of this contract are represented as
`(string, d)` pairs, the first element of which
is an identifier of an error and the second element keeps details of this error,
or `unit` if no details required.

For example, attempt to withdraw `5` tokens when only `3` is present
will result in the following error:
`("NotEnoughBalance", (5, 3))`

## Entrypoints

### transfer

This entrypoint will credit the account of the address passed in the
`"to"` parameter, while debiting the account corresponding to the `"from"` parameter.
Should the `"from"` address have insufficient funds, the transaction will fail and
no state will be mutated.

This entrypoint serves multiple purposes:
* When called with `"from"` account equal to the transaction sender, we assume that
the user transfers their own money and this does not require approval.
* Otherwise, the transaction sender must be previously authorized to transfer at least the requested number of tokens from the `"from"` account using the `approve` entrypoint.
In this case current number of tokens that sender is allowed to withdraw from the `"from"` address is decreased by the number of transferred tokens.

This entrypoint can fail with the following errors:
* `NotEnoughBalance` - insufficient funds on the sender account to perform a given
transfer. The error will contain a `(nat :required, nat :present)` pair, where
`required` is the requested amount of tokens, `present` is the available amount.
* `NotEnoughAllowance` - a given account has no permission to withdraw a given
amount of funds. The error will contain a `(nat :required, nat :present)` pair,
where `required` is the requested amount of tokens, `present` is the current allowance.

### approve

This entrypoint called with `(address :spender, nat :value)`
parameters allows `spender` account to withdraw from the sender, multiple times,
up to the `value` amount.
Each call of `transfer` entrypoint decreases the allowance amount on the transferred amount of tokens unless `transfer` is called with `from` account equal to sender.

If this entrypoint is called again, it overwrites the current allowance
with `value`.

Changing allowance value from non-zero value to a non-zero value is
forbidden to prevent the [corresponding attack vector](https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM).

This entrypoint can fail with the following errors:
* `UnsafeAllowanceChange` - attempt to change approval value from non-zero to
non-zero was performed. The error will contain `nat :previous` value, where
`previous` stands for the allowance value upon the contract call.

### getAllowance

This view will return the approval value between two given addresses.

### getBalance

This view will return the balance of the address in the ledger.

### getTotalSupply

This view will return the total number of tokens.

## Related work

[ERC-20](https://eips.ethereum.org/EIPS/eip-20) is a standard used in Ethererum for implementing tokens.
It also describes transfer and approval operations.
The interface we propose here differs from ERC-20. Specifically, we have `transfer`
and `transferFrom` analogies merged into a single entrypoint.
Also, ERC-20 is known to suffer from some vulnerabilities, and we took them into
account when implementing our interface.

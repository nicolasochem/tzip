---
tzip: FA1.2.1
title: Approvable Ledger (Athens)
status: WIP
type: Financial Application
author: Ivan Gromakovskii
advocate: Ivan Gromakovskii
created: 2019-08-01
---

## Summary

There is [TZIP-FA1.2](./FA1.2.md) which specifies approvable ledger.
It relies on the entrypoints feature of Michelson.
However, at the moment of writing, current version of Tezos (Athens) does not support entrypoints in Michelson.
They will be available on Mainnet only in the next version (Babylon) on October 15.
Hence we propose a stricter version of approvable ledger interface which will be deprecated as soon as multiple entrypoints become available on Mainnet.

## Approvable Ledger Interface

A contract which implements approvable ledger must have the following parameter type which we will call `fa12core`.
```
parameter
  or ((address :from, (address :to, nat :value))    %transfer) (
  or ((address :spender, nat :value)                %approve) (
  or ((view (address :owner, address :spender) nat) %getAllowance) (
  or ((view (address :owner) nat)                   %getBalance)
     ((view unit nat)                               %getTotalSupply)
  )));
```

See also:
* [Syntax sugar explanation](./A1.md#pairs-and-ors-syntax-sugar).
* [Explanation of `view`](./A1.md#view-entry-points).

Note that if a contract complies with this strict version of the standard, it complies with [FA1.2](./FA1.2.md) as well.
That is, it has five entrypoints as specified in Michelson 005.
These entrypoints have the same semantics as described in FA1.2.

## Implementation suggestions

In Athens, we must know concrete parameter type of a contract we want to call from another contract.
That's why we specify concrete parameter type above.
However, it imposes a severe restriction: a contract with `fa12core` parameter type can not have entrypoints other than those specified in this document.
In order to overcome this restriction we propose a technique based on using a proxy contract.
It allows one to write a contract with additional entrypoints which is compatible with this strict version of the standard.

**Note:** if all you need is a simple token without any additional entrypoints, this technique is not needed.
Also note that it is only one possible way to make a contract compatible with this document's requirement.
It is not required to use this technique.

Let's say we have a contract called `X` which implements all entrypoints from this document as well as some other entrypoints.
Since it has additional entrypoints, it can not have exactly `fa12core` parameter.
However, since it implements all required entrypoints, it is compatible with FA1.2.
To achieve compatibility with FA1.2.1, we originate an additional proxy contract called `Y` and update `X` by adding three additional entrypoints to it and one field to its storage.
Specifically:

* `X` stores an additional field in its storage, its type is `(address | address)`.
During origination it must be set to `Left a` where `a` is an address we (people who deploy `X`) trust.
This field is supposed to store the address of `Y` (when set to `Right`).
We can not set it during origination because `Y` should know address of `X`, so we have the "chicken or the egg" problem.
We originate `Y` first.
* Since we can not pass the address of `Y` to `X` during origination, we have to set it afterwards.
We add a `setProxy` entrypoint to `X` whose argument has type `address`.
When it is called, we check that `SENDER` equals to `a` and update additional storage field to `Right y` where `y` is the argument passed to `setProxy`.
`SENDER` check makes it impossible for adversary to successfully call `setProxy` with a malicious address.
* Apart from `setProxy`, `X` has two additional entrypoints: `(address :sender, (address :from, (address :to, nat :value))) %transferViaProxy` and `(address :sender, (address :spender, nat :value)) %approveViaProxy`.
The may be called only by `Y`, i. e. internally they check that proxy is set and is equal to `SENDER`.
Semantically, they are equivalent to calling `transfer` and `approve` respectively with sender set to `address :sender`.
* `Y`'s parameter type is exactly `fa12core` which makes it compliant with the strict version of FA1.2.
* `Y`'s storage is `contract xParam` where `xParam` is parameter of `X`.
* When `Y`'s entrypoint is called, it propagates the call to `X` by calling the same entrypoint with the same data.
Since `approve` and `transfer` entrypoints depend on `SENDER`, `Y` does not call them, but instead it calls `transferViaProxy` and `approveViaProxy`.

In order to deploy these contracts one should originate `X` first, obtain its address, then originate `Y` passing `X`'s address to it and then call `X`'s `setProxy` entrypoint.

It is a textual description of the idea.
A sample implementation can be found in [the asset directory for this TZIP](/assets/FA1.2).

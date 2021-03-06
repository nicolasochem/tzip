---
tzip: 007
status: Final
author: Konstantin Ivanov <kivanov@serokell.io>, Ivan Gromakovskii (@gromak)
created: 2019-04-12
---

## Why do not you require contract parameter type to be concrete?

Parameter is the only easy way for a caller to pass some data to a contract.
We do not know in advance which data an arbitrary contract can use.
If we specify a concrete parameter type which is a tree of `or` types where each leaf corresponds to some method from TZIP-007, it means that contract can not have any other input data, hence it can not have methods other than those listed in TZIP-007.
While we can use a proxy contract to adapt a more general parameter type to a concrete one, such an approach has the following disadvantages:
1. It is harder to implement and use, hence more error-prone.
In particular, special care should be taken to make sure that proper `SENDER` value is propagated by the proxy contract.
2. It is substantially less efficient in terms of gas costs.

We can add one more leaf to this tree of `or`s with type `(string, bytes)` where the first item denotes method name and the second one carries method's argument in serialized form.
However, this approach adds a certain degree of unsafety (one may supply non-existing method name or incorrectly packed data), consumes more gas (unpacking is not a cheap operation) and makes parameter type less descriptive.

Rather, we rely on the entrypoints feature available since Tezos Babylon upgrade.
Since the caller of a contract can specify an entrypoint she wants to invoke, we are not forced to require a concrete parameter type anymore.

## Why do not you require concrete shape of parameter tree?

Michelson documentation defines "a contract with entrypoints" as "a contract that takes a disjunctive type (a nesting of `or` types) as the root of its input parameter, decorated with constructor annotations".
We could require this disjunctive type to have a particular shape, e. g. to be a right- or left-hand comb or a balanced tree with all TZIP-007 methods located in some specific place.
However, such a requirement would have a few drawbacks:
1. It complicates composability of contract interfaces.
If our interface requires certain methods to be in a particular place and another interface has a similar requirement, these two interfaces most likely will be incompatible.
If we only require all TZIP-007 methods to have a common node in the tree of `or`s, we'll encounter an incompatibility issue if another interface has methods with the same names and a similar requirement.
2. It imposes unnecessary restriction on contract developers.
We consider this restriction unnecessary, because the entrypoints feature allows one to call contract's method without knowing anything about its parameter shape.
Without this restriction high level languages can pick representation of nested `or` types which is more suitable for them.

## Why using `SENDER` address rather than `SOURCE`?

Using `SOURCE` instruction is considered treacherous, at least by
[Ethereum community](https://consensys.github.io/smart-contract-best-practices/recommendations/#avoid-using-txorigin).

There are chances that this instruction will be deprecated in Michelson some day.

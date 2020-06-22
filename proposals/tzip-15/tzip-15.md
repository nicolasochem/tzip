---
tzip: 15
title: A2 - Filterlist Interface
author: Michael J. Klein (@michaeljklein)
status: Draft
type: Application (A)
created: 2020-05-14
---

## Summary

TZIP-15 proposes a standard for a filterlist interface:
a lighteight permission schema suitable for asset allocation and transfer.

This schema is versatile and can either be used as part of a token
contract (i.e. in a _monolith_ configuration) or as a separate contract that's
queried on demand.

This document provides an overview and rationale for the interface,
which is implemented in Lorentz, SmartPy, and partially in LIGO.


## Abstract

Token contracts often need to control which users can perform transfers,
especially when K.Y.C. (Know Your Customer) regulations are in play,
and this often takes the form of user "_filterlists_", i.e.
lists of which users may be the sender/receiver of a transfer.

Common features include the following:
- Many users share the same permissions
- Some privileged "issuer" account distributes funds to new users
- The lists are updated using granular changes

Some optimizations implemented:
- Many users are assigned a single filterlist
- Outbound and inbound filterlists can be combined: we use just outbound filterlists
  * E.g. to allow transfers to `X` from all filterlists,
    allow outbound transfers to `X` on all filterlists.
- Outbound filterlists are updated by providing a "patch" of `filterlistId`'s to
  add and remove.
  * This allows "big" (using `big_map`'s) and "small" (using `map`'s and `set`'s)
    implementations to use the same interface.
- There is an issuer, who may transfer to any user that can accept transfers:
  this simplifies the state and is extensible:
  * The issuer can be disabled by setting the `userId` to an account that
    otherwise can't perform transfers, e.g. an empty contract.
  * The issuer can be split into multiple accounts by using a multisig or a
    "permissioned proxy", i.e. a contract acts as the issuer and forwards
    authenticated contract calls.
- Calling `FAILWITH` on error allows a contract to check filterlisting with a single call to `TRANSFER_TOKENS`
- Key operations to update state are commutative (up to primary keys), viz.
  `updateUser` and `updateFilterlist`, which allows easier batching of updates.


## Specification

#### `userId`

`userId` is a comparable type representing a user.

The `userId` will normally be `address`, but other types can be useful:
- `nat` can be used when multiple `address`es may be associated with a single user
- `key` (public key) can be used when users provide explicit `signature`s
- `bytes` can to avoid some overhead in parsing/preprocessing other types


#### Abstract storage specification

This is how the contract must behave, but no particular Michelson
types or layouts are specified.

The filterlists are split up into two "tables":
- `users`:
  * `key: userId`
    + Each user has exactly one `filterlistId`
  * `val: filterlistId`
    + `filterlistId` is a `nat`
- `filterlists`:
  * `key: filterlistId`
  * `val: (unrestricted, allowedFilterlists)`
    + `unrestricted` is a `bool`. if it's `False`, the filterlist is restricted
      and its users will fail `assertReceivers`, `assertTransfers`. A restricted
      filterlist will generally behave as if its `allowedFilterlists` is empty.
    + `allowedFilterlists` is a set of `filterlistId`
      * Note: `allowedFilterlists` is not necessarily a Michelson `set` in the
        contract's storage, e.g. it could be implemented using a `big_map`.

In short, user `X` may transfer to user `Y` if `Y`'s `filterlistId` is in
`X`'s filterlist's set of `allowedFilterlists` and both filterlists are
unrestricted.

The storage also contains one variable:
- `issuer`: `userId`

The issuer is treated as a user who:
- Can't be explicitly added to `users`
- Is always `unrestricted`
- Whose `allowedFilterlists` is the set of ALL `filterlistId`'s

#### Ways to use the interface

The interface has three types of entrypoints:
assertion, management, and informative.

It may be used in two primary ways:
- As a compile-time wrapper
  + In this case, the entire filterlist contract is inlined into another contract, e.g. a token contract.
  + The assertion entrypoints are used like library functions in the other contract.
  + The management and informative entrypoints are REQUIRED.
- As an on-chain wrapper
  + In this case, the filterlist contract is deployed separately from any contract using it, e.g. a token contract.
  + The assertion entrypoints are called from the other contract, without requiring callbacks since they call `FAILWITH` when they fail.
  + The assertion, management and informative entrypoints are REQUIRED.


## Entrypoints

### Assertion

These entrypoints MUST be exposed and callable by arbitrary `address`es,
except when the filterlist is used as a compile-time wrapper.

When one of these entrypoints fails, it must use the `FAILWITH` Michelson
instruction.

#### `assertReceivers`

Succeed if and only if, for each `userId` in the list:
- The given `userId` is in `users`, and thus has a `filterlistId`
- The associated `filterlistId` refers to an existing, `unrestricted` filterlist

```
(list %assertReceivers userId)
```

#### `assertTransfers`

Succeed if and only if, for each `from` and their associated `to`'s in the list,
either:
- Both
  * `assertReceivers` would succeed for both the `from` and `to` `userId`'s
  * `to`'s `filterlistId` is in the `set` of `from`'s filterlist's set of allowed outbound filterlists
- Or both:
  * `assertReceivers` would succeed for the `to` `userId`
  * The `from` `userId` is the `issuer`'s `userId`

This is equivalent to the following pseudocode:

```python
def assertTransfers(input_list):
  for from, tos in input_list:
    for to in tos:
      if from == issuer:
        assertReceivers [to]
      else:
        assertReceivers [from, to]
        users.get(to) in filterLists.get(users.get(from)).allowedFilterlists
```

```
(list %assertTransfers (pair (userId %from)
                             (list %tos userId)))
```

See [FA2's `transfer`](https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-12/tzip-12.md#transfer)
for an example of a similarly batched entrypoint.

##### Examples

Consider the following setup where `userId` is `string`:

Users:
- `"alice": 0`
- `"bob": 0`
- `"charlie": 1`
- `"dan": 2`

Filterlists:
- `0: (unrestricted: True, allowedFilterlists: {0, 2})`
- `1: (unrestricted: True, allowedFilterlists: {1})`
- `2: (unrestricted: False, allowedFilterlists: {1, 2})`

Then suppose the following call to `assertTransfers` were made:

```
assertTransfers 
  { Pair "alice" { "bob", "dan" }
  , Pair "bob" { "alice" }
  , Pair "charlie" { "charlie", "dan" }
  }
```

- `alice -> bob`: `alice` and `bob` are on the same filterlist (`0`),
  which contains itself in its `allowedFilterlists` and is `unrestricted`,
  so this succeeds
- `alice -> dan`: `alice` is on a filterlist (`0`) that contains `dan`'s `filterlistId` (`2`) in its `allowedFilterlists` and is `unrestricted`,
  but it fails because `dan`'s filterlist is restricted
- `bob -> alice`: This succeeds by the same logic as `alice -> bob`: they're on the same `unrestricted` filterlist that contains its own `filterlistId` in its `allowedFilterlists`
- `charlie -> charlie`: This succeeds since `charlie`'s filterlist is unrestricted and contains its own `filterlistId` in its `allowedFilterlists`
- `charlie -> dan`: This fails because `dan`'s filterlist (`2`) is restricted

Thus the above call to `assertTransfers` will fail.

### Management

These entrypoints MUST be exposed, but need not be callable by arbitrary `userId`'s.

For example, they all may be callable by a single administrator address
(not necessarily the issuer).

#### `setIssuer`

Set the issuer's `userId`

```
(userId %setIssuer)
```

#### `updateUser`

Add, update, or remove a user:
- To add or update a user, provide `Some` `filterlistId`
- To remove a user, provide `None` for `filterlistId`
- This must fail with `FAILWITH` if the issuer's `userId` is provided.
- This must NOT fail if the `filterlistId` is NOT in `filterlists`.
  In other words, it must be possible to create the filterlist
  _after_ calling `updateUser`.


```
(pair %updateUser (userId %user)
                  (option (nat %filterlistId)))
```

#### `updateFilterlist`

Add, update, or remove a filterlist:
- To add or update a filterlist, provide `Some`:
  * `disallowFilterlists` is a `list` of `filterlistId`'s to remove from the `allowedFilterlists`
  * `allowFilterlists` is a `set` of `filterlistId` to add to the `allowedFilterlists`
  * NOTE: `disallowFilterlists` _must_ run before `allowFilterlists`.
    In other words, if a `filterlistId` is in both `disallowFilterlists` and `allowFilterlists`,
    it will be idempotently added to `allowedFilterlists`.
- To remove a filterlist, provide `None` for the `option`
- This must NOT fail if any `filterlistId` provided in `allowedFilterlists` is NOT in `filterlists`.
  In other words, it must be possible to create the filterlists
  in `allowedFilterlists` _after_ calling `updateFilterlist`.

```
(pair %updateFilterlist (nat %filterlistId)
                        (option (pair (bool %unrestricted)
                                      (pair (list %disallowFilterlists nat)
                                            (set %allowFilterlists nat)))))
```


### Informative

These entrypoints MUST be exposed and callable by arbitrary `userId`'s.

#### `getIssuer`

Get the issuer's `userId`

```
(pair %getIssuer unit
                 (contract %callback userId))
```

#### `getUser`

Get `Some` `user`'s `filterlistId` if and only if the provided `userId` exists in `users`, or `None` otherwise

```
(pair %getUser (userId %user)
               (contract %callback (option %filterlistId nat)))
```

#### `assertFilterlist`

Succeed if and only if:
- `Some` is provided and:
  + The given `filterlistId` exists in `filterlists`
  + The given `unrestricted` `bool` matches its `unrestricted` state
  + The given `allowedFilterlists` is a subset of its `allowedFilterlists`
- `None` is provided and the `filterlistId` does _not_ exist in `filterlists`

```
(pair %assertFilterlist (nat %filterlistId)
                        (option (pair (bool %unrestricted)
                                           (set %allowedFilterlists nat))))
```


## Test Cases

NOTE: These test cases reflect the version of this TZIP _before_
[`1720bd90b55e6ba8d7667c643cefa7929282fdb8`](https://gitlab.com/tzip/tzip/-/commit/1720bd90b55e6ba8d7667c643cefa7929282fdb8).

Test cases for each entrypoint:

- Implemented using [Lorentz](https://gitlab.com/morley-framework/morley/-/tree/master/code/lorentz),
  may be found [here](https://github.com/tqtezos/lorentz-contract-whitelist/blob/54013493d1c8c8a8101236a7ce186f42a321b29f/test/Test/Whitelist.hs)
- Implemented using [Taquito](https://tezostaquito.io),
  may be found [here](https://gitlab.com/tezos-paris-hub/whitelisting-smartpy/-/tree/master/test)

## Implementations

NOTE: These implementations reflect the version of this TZIP _before_
[`1720bd90b55e6ba8d7667c643cefa7929282fdb8`](https://gitlab.com/tzip/tzip/-/commit/1720bd90b55e6ba8d7667c643cefa7929282fdb8).

- An implementation of compile-time wrapping and separate-contract filterlists in Lorentz may be found
  [here](https://github.com/tqtezos/lorentz-contract-whitelist)
- A partial implementation of a compile-time wrapper in LIGO may be found
  [here](https://github.com/tqtezos/ligo-contract-whitelist)
- An implementation of the separate-contract filterlist in SmartPy may be found
  [here](https://gitlab.com/tezos-paris-hub/whitelisting-smartpy)

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).


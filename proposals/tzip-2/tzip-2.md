---
tzip: 2
title: TZIP Types and Naming
status: Submitted
type: Meta
author: John Burnham, Julien Hamilton (@julien.hamilton)
created: 2019-04-10
---

## Summary

This document lists the different types a TZIP can be, with their descriptions. In addition, we explain how to use types to name some TZIPs (e.g. FA1, FA1.2, LA1).


## List of TZIP Types

| Type Prefix | Topic                  | Description                |
|-------------|------------------------|----------------------------|
|             | Meta                   | This type describes a process surrounding Tezos or proposes a change to (or an event in) a process. Examples include procedures, guidelines, changes to the TZIP process itself, or proposals for new social institutions and spaces. The present document is a Meta TZIP. |
| `A`         | Application            | Applications built on top of Tezos, particularly smart contract or higher layer applications. |
| `LA`        | Layer-n Application    | Higher-layer applications which use the Tezos chain e.g. for settlement or communication. |
| `FA`        | Financial Application  | Applications involving the management, allocation or transfer of instruments which mediate economic value, such as assets or liabilities. |
| `I`         | Interface              | Improvements around client API/RPC specifications and standards. |
| `L`         | Language               | Improvements to smart contract, formal proof, or implementation languages. Examples are specifications for [Michelson](https://tezos.gitlab.io/whitedoc/michelson.html), [LIGO](https://ligolang.org/), [SmartPy](https://smartpy.io/), [Morley](http://hackage.haskell.org/package/morley), [Fi](https://learn.fi-code.com/), or best practices for Tezos projects using OCaml, Haskell, Rust, JavaScript, Coq, Agda, etc. |
| `N`         | Networking             | Improvements to the peer-to-peer layer. |
| `X`         | Cryptography           | Improvements to cryptographic primitives. |
| `Z`         | Informational          | Discusses a Tezos design issue, or provides general guidelines or information to the Tezos community. |

Additional types of TZIP may be proposed, and existing TZIP types may also be deprecated by future Meta TZIPs. All the updates will be maintained in this TZIP ([TZIP-2](/proposals/tzip-2/tzip-2.md)).


## Naming

Some TZIPs, like smart contract specifications, have a distinct *name* that is used to identify them. This is in addition to their TZIP number.

We define the TZIP name as two components:

1. An alphabetic Type prefix (e.g. FA or P) which signifies the standard's topic or domain of relevance. The valid TZIP types are available in the *List of Types* discussed above.
2. A serial number represented as a list of dot separated numbers (e.g. 1.2.3 or 15), which signifies whether the standard is an extension or specialization of another more general standard. For example 2.34 would be the extension number 34 of the root standard number 2.


## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

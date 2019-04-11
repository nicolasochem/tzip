---
tzip: 2
title: TZIP Index
status: Active
type: Meta
author: John Burnham
advocate: John Burnham
created: 2019-04-10
---

## Summary

## Abstract

## Background: A brief history of the RFC document

Expressing standards in a "Request for Comments" or `RFC` document is a
tradition that goes all the way back to the beginning of the Internet. The
first RFC was an informal memo written in 1969 by Steve Crocker to the `ARPANet`
Network Working Group to figure out how to get `ARPANet` hosts to talk to each
other properly (you can read `RFC-1` in its full glory, complete with ASCII
diagrams here: https://www.rfc-editor.org/rfc/pdfrfc/rfc1.txt.pdf).

Since then, the `RFC` process has evolved and is now formalized under the
auspices of the `IETF`, which additionally canonizes certain `RFC`s (or sets of
`RFC`s) as [Internet Standard][Internet Standard] which contains standards for
things like `ASCII` (RFC-20), `TCP` (RFC-793), `DNS` (RFC-1035), etc.  ([a list
of notable `RFC`s][RFC])

Roughly speaking the `RFC` [process][pubprocess]
works like this:

1. Submit a draft to the RFC Editor
2. Various review procedures for independent submissions (RFCs generated
   by the IETF itself skip this step)
3. Editing and review by the RFC Editor
4. Assign an `RFC` serial number
5. Author's review
6. Publish

All in all, this process typically takes a few months, but delays are common;
it is designed to be deliberative and thorough, to "move slow and break
nothing."

A full state diagram for the RFC Editor process:
https://www.rfc-editor.org/wp-content/uploads/rfc-editor-process.gif

The relevant part of this process for our purposes is step 4 (Assign an `RFC`
serial number). RFC numbers are issued in order, steadily ticking up as each
submission in the RFC Editor queue is approved for publication. With some
exceptions, this pattern has held mostly steady since `RFC 1`.

In 2015, the nascent Ethereum community faced a need for a more formal
standardization process and so [took inspiration][issue-16] from the above
`IETF` process for `RFC`s, which their current [Ethereum Improvement
Proposal][EIP] process resembles (by descent through Bitcoin and Python, which
have analogous `Bitcoin Improvement Proposal` and `Python Enhancement Proposal`
processes). The `RFC` name itself lives on in the `Ethereum Request for
Comments` or `ERC`, an `EIP` subtype that deals specifically with
application-level standards (most notably token standards such as `ERC-20`).

## Problem: Blockchain RFCs

There are two major problems with using an `IETF`-style RFC process to
generate standards for a blockchain or cryptocurrency platform:

First there is a problem of governance: Who approves the standards? Does the
standards process have legitimacy and community buy-in? Can disagreements on
standards be resolved through means other than hard-forking? This problem is
relatively well understood, particularly in the Tezos community, so I will not
focus on it here.

Secondly there is a problem of branding: The term "ERC-20" has
become a brand name used by projects and investors in the ICO marketplace.
"ERC-20" even has its own [Wikipedia page][ERC20]
In one sense, this is a standard working properly, people need common language
to cooordinate with one another. However, using the name "ERC-20" (i.e. issue
number 20 in the EIP repository) for this purpose is perverse. Standards serial
numbers are not designed for marketing copy; imagine calling `TCP/IP`
"RFC-[1347][RFC1347]/[791][RFC791]".  At best, the additional layer of jargon
obscures meaning. At worst, it can lead to cargo cult mentality in those who
misunderstand the purpose of standards and thus conflate compliance with the
generation of real value.

https://dilbert.com/strip/1997-09-24
"What's the difference between ERC-20 and ERC-223? Oh, about 103."

An egregious (and fascinating) example of this abuse is the adoption of the
`*RC-20` pattern by other platforms, such as the use of `TRC-20` by `TRON`
(which does not, as far as I can tell, have a formalized `RFC` process).

To be clear, this problem is not the fault of designers the EIP process, which
is in-line with other successful RFC processes such as Python. The problem is
in the unexpected emergent interaction between technical standards and the
largely marketing-driven token economy.

## Solution: Meaningful RFC serial numbers

We can mitigate the above problems by giving `RFC`s more meaningful serial
numbers.

We define the TZIP index code as two components:

1. An alphabetic Domain prefix (e.g. `FA` or `G`) which signifies the standard's
   topic or domain of relevance. This prefix can be empty, which indicates a
   meta-level standard (a standard about the standards process itself). The
   mapping between specific letter prefixes and domains is maintained in a
   registry
2. A serial number represented as a list of dot separated numbers (e.g. `1.2.3`
   or `15`), which signfies whether the standard is an extension or
   specialization of another more general standard. For example `2.34` would be
   extension number 34 of root standard number 2.

As a worked example, let us imagine where we would classify a port of the
`ERC-20` standard to Michelson as a Tezos Standard index code.

`ERC-20` instantiates an asset by maintaining a ledger of accounts and balances
and providing an interface to transfer balances between accounts. Since
`ERC-20` balances are fungible (all units of the asset are interchangeable and 
without distinction, aside from their ownership).

Let's suppose that the code `A` is mapped to the topic "Asset", and its
extension `FA` is mapped to "Fungible Asset"  in our Domain Prefix Registry
(prefixes specialize from right to left by prepending characters). Our prefix
for our `ERC-20` port is thus `FA`.

Serial numbers are assigned in the same approval queue as the RFC process, so if
is already a standard with the code `FA1`, which our `ERC-20` port is not an
extension of, our index code will then be `FA2`.

Crucially, domain prefixes export distinct namespaces, so `A1` and `FA1` are
not necessarily related and might be completely independent.

Now let's further suppose that some time later we return to our `FA2` standard
and wish to make an extension, say by adding a transfer restriction function to
the contract interface. Supossing there have been three extensions to `FA2`
already, our assigned index code for our extension will be `FA2.4`. However,
should the extension cause a meaningful divergence from the root, perhaps by
implying a radically different purpose or implementation, the standards editor
may assign a separate root index code (e.g. `FA3`) or a code in a different
domain prefix altogether.

Standards may be extended indefinitely by appending additional `.` characters.
However, it is likely that repeated extension will be less preferable at a
certain point than issuing a new root code.

In contexts where the overall index code may appear with abbreviations
or serial numbers from external platforms (such as `RFC` or `EIP` numbers), the
letters `TZIP` should be prepended to the code like so:

```
TZIP-FA2
TZIP-A3.4
```

Meta-level standards (such as this one `TZIP-2`) should always have `TZIP`
prepended to their index codes.

## TZIP Index: Types

### List of Types

| Type Prefix | Topic                          |
|-------------|--------------------------------|
|             | Meta                           |
| A           | Application                    |
| AA          | Asset Application              |
| LA          | Layer-n Application            |
| FAA         | Fungible Asset Application     |
| NAA         | Non-fungible Asset Application |
| I           | Interface                      |
| L           | Language                       |
| N           | Networking                     |
| O           | Operations                     |
| P           | Protocol                       |
| X           | Cryptography                   |
| Z           | Informational                  |

### Descriptions:

**(A) Application**: Applications built on top of Tezos, particularly smart
contract or higher layer applications.

**(LA) Layer-n Applications**: Higher-layer applications which use the Tezos
chain e.g. for settlement or communication.

**(AA)** Assets: Applications which implement a resource with economic value
which users own or control with some expectation of future benefit.

**(FAA)** Fungible Assets: Assets whose units are interchangeable and of equal
value.

**(NAA)** Nonfungible Assets: Assets whose units are are not
interchangeable or of equal value.

**(P) Protocol**: improvements to the Tezos protocol requiring a
recourse to the protocol amendment process.

**(N) Networking**: improvements to the peer-to-peer layer

**(X) Cryptographic**: improvements to cryptographic primitives

**(I) Interface**: improvements around client API/RPC specifications and
standards

**(L) Language**: improvements to smart contract, formal proof, or
implementation languages. Examples are specifications for
[Michelson], [LIGO, [SmartPy], [Morley], [Liquidity], [Fi] or best practices
for Tezos projects using OCaml, Haskell, Rust, JavaScript, Coq, Agda, etc.

**(Z) Informational**: Tezos design issue, or provides general guidelines or
information to the Tezos community.

A **Meta TZIP** describes a process surrounding Tezos or proposes a change
to (or an event in) a process. Examples include procedures, guidelines,
changes to the TZIP process itself, or proposals for new social institutions
and spaces. This document is a Meta TZIP.

Unlike other types of TZIP, active Meta TZIPs should be consistent with one
another as much as possible and are binding on TZIP editors.

Additional types of TZIP may be proposed, and existing TZIP types may also be
deprecated by future Meta TZIPs. The TZIP Editors will maintain up-to-date list
of active TZIP types in [TZIP-2: TZIP Index][TZIP-2].

## Additional Documents

[TZIP-1]: (/TZIP-1.md)
[issue-20]: https://github.com/ethereum/EIPs/issues/20
[issue-16]: https://github.com/ethereum/EIPs/issues/16
[pubprocess]: https://www.rfc-editor.org/pubprocess/
[EIP]: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1.md
[RFCs]: https://en.wikipedia.org/wiki/List_of_RFCs,
[Internet Standard]: (https://en.wikipedia.org/wiki/Internet_Standard).
[ERC20]: https://en.wikipedia.org/wiki/ERC-20

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).
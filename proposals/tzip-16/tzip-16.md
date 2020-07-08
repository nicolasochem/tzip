---
tzip: 16
title: Contract Metadata
status: Work In Progress
type: Interface
author: Seb Mondet <seb@mondet.org>
created: 2020-06-30
---

## Abstract

This document describes a standard for Tezos smart contracts to advertise
metadata about themselves.

The standard defines:

- A basic structure to find _some_ metadata in a contract's storage.
- An URI scheme to find data: on-chain (contract storage) or off-chain
  (web-services or IPFS).
- An extensible JSON format (JSON-LD or JSON-Schema) to describe the metadata,
  it contains among other things:
    - provenance information,
    - references to other standards implemented,
    - off-chain “views” (Michelson functions to query the contract), and
    - custom extensions.
- an optional entry-point to validate metadata information
 
The standard is meant to be extended/specialized by other TZIPs, for instance by
adding fields to the JSON format of the metadata or imposing certain off-chain
views.


## Meta-draft Section

<b style="color: red">This section will disappear as draft gets properly written</b>

Cf. old HackMD with ideas/discussions: <https://hackmd.io/CiBPx3RYQZWGXmSXuAlpVw>

- Intro
    - justification: no need to change protocol for off-chain things
    - justification: we need a standard for contract devs & tools, wallets, and
      indexers/explorers to agree on formats and semantics
- Use-case Example
    - Quick round-trip / non-detailed “example”
    - Get an IPFS URI, get the JSON, call an offchain view.
- Define the piece of Michelson storage
    - big-map + default “first key”
- Define URI format
    - refer to other known URIs: `https:`, `ipfs:`
    - define how to point inside a contract
- Define The metadata blobs “meta-format”
    - [JSON-LD](https://en.wikipedia.org/wiki/JSON-LD)
    - or [JSON Schema](https://en.wikipedia.org/wiki/JSON#JSON_Schema)
    - with links using the previous URI format
- Define Reserved simple fields
    - authorship/provenance
    - other TZIP references
- Define Offchain views
    - micheline encoded as concrete strings? or JSON? or both options/
    - exact semantics with examples
- Define Optional entry-point
    - not sure about this
- How to “derive” from TZIP-16
    - should we also modify TZIP-12 or just provide examples?
- Implementations
    - reference known implementations

All the “Define …” could be sub-sections of a **Definition of The Standard** section

## Introduction

**TODO**


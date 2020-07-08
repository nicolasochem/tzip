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
    - In the `.md` file: only informal-ish but precise enough definition
    - Some fields are links which use the previous URI format
    - Attachment: [JSON Schema](https://en.wikipedia.org/wiki/JSON#JSON_Schema)
      or [JSON-LD](https://en.wikipedia.org/wiki/JSON-LD)
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


## Example Use-Case

## Definition of The Standard

### Contract Storage

To provide a TZIP-16-compliant initial
access-point to the metadata from a given on-chain contract (`KT1...`
address)
one must 
include the `%metadata` field in the contract-storage.

The field can be anywhere within the storage type but must have the following
type:

```
(big_map %metadata string string)
```

At least one value must be present: 

- the one for the empty string key (`""`).
- the value must be an URI as specified in the following section which points to
  a JSON document as specified in the one after

### Metdata URIs

URIs are used here first to locate metadata contents, but the format may be reused 
in other similar cases for instance in extensions to this specification.

See the specification an URI's generic format:
<https://tools.ietf.org/html/rfc3986>

In the context of this specification, valid schemes include:

- `http`/`https` <https://tools.ietf.org/html/rfc7230#section-2.7>
- `ipfs` <https://www.iana.org/assignments/uri-schemes/prov/ipfs>
  <https://github.com/ipfs/in-web-browsers/blob/master/ADDRESSING.md#addressing-with-native-url>
- `tezos-storage`: defined below
- `sha256`: defined right after

#### The `tezos-storage` URI Scheme

URIs that point at the storage of a contract

Host:

- location of the contract pointed to
- e.g. `KT1QDFEu8JijYbsJqzoXq7mKvfaQQamHD1kX.mainnet` or
  `KT1QDFEu8JijYbsJqzoXq7mKvfaQQamHD1kX.NetXNfaaGTuJUGF`
- this is all optional, if contract address or network are not provided the
  defaults are “current” ones in a given context.

Path: a string used as key in the `%metadata` big-map of the contract

Examples:

- `tezos-storage:hello`: in the current contract fetch the value
  at key `"hello"` from the `%metadata` big-map.
- `tezos-storage://KT1QDFEu8JijYbsJqzoXq7mKvfaQQamHD1kX/foo`: get the value at
  `foo` from the metadata big-map of the contract
  `KT1QDFEu8JijYbsJqzoXq7mKvfaQQamHD1kX` (on the current network).


#### The `sha256` URI Scheme

This is a compound URI, the host must be understood the SHA256 hash of the
resource being pointed at by the path of the URI in hexadecimal format.

Example:

`sha256://eaa42ea06b95d7917d22135a630e65352cfd0a721ae88155a1512468a95cb750/https:%2F%2Ftezos.com`


### Metadata JSON Format


We first define the format in a rather informal way.






---
tzip: 16
title: Contract Metadata
status: Work In Progress
type: Interface
author: Seb Mondet <seb@mondet.org>
created: 2020-06-30
---

## Abstract

This document (will) describe a standard for Tezos smart contracts to advertise
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


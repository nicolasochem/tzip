---
Headers marked with "*" are optional. All other headers are required.
tzip: <TZIP index code> (this is determined by the editor)
title: <TZIP title>
author: <a list of the author's or authors' name(s) and/or username(s), or
name(s) and email(s). [More Details](/TZIP-1.md#author-header)>
advocate *: <a list of the author's or authors' name(s) and/or username(s), or
name(s) and email(s). [More Details](/TZIP-1.md#author-header)>
gratuity *: <a Tezos address controlled by an author capable of receiving
gratuities from grateful Tezoi>
discussions-to *: <a url pointing to the official discussion thread>
status: <WIP | Draft | Last Call | Final | Active | Pending | Protocol | Rejected | Superseded>
review-period-end *: <date review period ends>
type: <Defined in [TZIP-2](/TZIP-2.md#tzip-index-types)>
created: <date created on>
updated *: <comma separated list of dates>
requires *: <TZIP indices>
replaces *: <TZIP indices>
superseded-by *: <TZIP indices>
---

## Simple Summary

“If you can’t explain it simply, you don’t understand it well enough.” Provide a simplified and layman-accessible explanation of the TZIP

## Abstract

A short (200-500 word) description of the technical issue being addressed.

## Motivation

The motivation is critical for TZIPs that want to change the Tezos protocol. It should clearly explain why the existing protocol specification is inadequate to address the problem that the TZIP solves.

## Specification

The technical specification should describe the syntax and semantics of any new feature. The specification should be detailed enough to allow competing interoperable implementations.

## Rationale

The rationale fleshes out the specification by describing what motivated the design and why particular design decisions were made. It should describe alternate designs that were considered and related work, e.g. how the feature is supported in other languages. The rationale may also provide evidence of consensus within the community, and should discuss important objections or concerns raised during discussion.

## Backwards Compatibility

All TZIPs that introduce backwards incompatibilities or supersede other TZIPs must include a section describing these incompatibilities, their severity, and solutions.

## Test Cases

Test cases for an implementation are strongly recommended as are any proofs of correctness via formal methods.

## Implementations

Any implementation must be completed before any TZIP is given status “Last Call”, but it need not be completed before the TZIP is merged as draft.

## Copyright

All TZIPs must be in the public domain, or a under a permissive license substantially identical to placement in the public domain. Example of a copyright waiver.

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

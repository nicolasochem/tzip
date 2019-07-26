---
tzip: 1
title: TZIP-1 (TZIP Purpose and Guidelines) FAQ
status: WIP
type: Meta
author: John Burnham, Jacob Arluck
advocate: John Burnham, Jacob Arluck
created: 2019-04-12
---

## What is a TZIP?

Response copied from [TZIP-1](/TZIP-1.md#what-is-a-tzip):

An TZIP is a design document providing information to the Tezos community,
describing a feature for Tezos or its processes or environment, and supporting
the formal protocol governance process.

## Why do we need this?

Let's start from the assumption that Tezos needs some sort of asset standards
comparable to the role "ERC" plays on Ethereum, which is something a lot of
people have asked for. If we accept this premise, then there are two options:

1. Informal standards with no standards process
2. Formal standards with a a standards process

There are examples of both kinds of standards in the blockchain community, but
in our opinion informal standards are much more common. In general, informal
standards make decision-making processes opaque and result in poorer quality
standards documents. High-quality standards don't just appear overnight; they
are public goods that have to be carefully and thoughtfully *built*. We think
that a formal standards process is the best way to do this.

## Wouldn't it be simpler to just write the application standards first?

We are developing the application standards [A1: Michelson Contract Interfaces
and Conventions], [FA1: Abstract Ledger], [FA1.1: Transfer Approvals on an
Abstract Ledger] at the same time as the Meta-level TZIPs.

This is a lot more work, but we think it's a fairer and more fruitful
alternative to just unilaterally promulgating our own standards.

We do genuinely need the application standards we're working on, but already
we've found that we've held our work to higher level of quality by thinking of
them in the context of a larger standards process.

## What's to prevent TZIP from becoming a centralized authority like EIP?

EIP has power in Ethereum because it acts as [Schelling
point](https://en.wikipedia.org/wiki/Focal_point_(game_theory) in their system
of hard fork governance. This is reinforced by the fact that the EIP editors
are substantially the most influential or notable members of the Ethereum core
developer community.

Tezos has a different, and we believe more game-theoretically optimal, Schelling
point in the protocol amendment process by the Tezos Quorum. We've proposed this
design of the TZIP process to support the Quorum by making TZIP an effective
process for producing good quality documentation that is completely non-binding
upon anyone. In a very real sense, we've tried to imagine what EIP would look
like if it only had an "Informational" standards track.

## Who are the editors going to be?

We don't know! We've left this question open because it needs to be answered by
the Tezos community as a whole. We hope we can all collectively design a fair
and legtimate mechanism for electing (and removing) TZIP editors. One possible
way to do this might be to use a Quorum vote to select the editors. Another way
might be to have an in-person election at some future Tezos conference.

Whatever the mechanism, we think it should be democratic and transparent:
If the composition of TZIP editors ends up looking analogous the composition of
EIP editors, we will consider this entire proposal to have been a failure.

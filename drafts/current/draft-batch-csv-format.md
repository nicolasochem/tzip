---
title: Batch Definitions in CSV
status: Draft
author: samuel.bourque@nomadic-labs.com
type: TZIP type as defined in TZIP-002
created: 2021-05-28
date: 2021-05-28
version: 0
---


## Summary

This TZIP proposes a standard specification in CSV[1] to describe a batch which can be loaded into a wallet for signature and injection.

## Abstract

Sending large numbers of transactions are both cumbersome and costly; building batches in wallets is also a laborious and error-prone process.

Batch File Format Specification, as defined herein, allow the convenience of scaling large batches with the additional benefit of reusability and interoperability across wallets. Starting from a simple, human-readable CSV file, a batch can be loaded into a wallet ready for signature and injection.

## Motivation

Some users--particlarly heavy users--who send out large numbers of transactions as once, have had to either endure a laborious process to send out large batches (or large number of single transactions) or have had to come up with clever scripting means to ease the process.

A simple interoperable means is easily achieved by devising a standard file format--particlarly one that's familiar in finance and accounting: CSV.

## Specification

### Formal Specification

```
file = transaction *(CRLF transaction) [CRLF]
transaction = teztx | tokentx
teztx = destination COMMA amount CRLF
tokentx = destination COMMA amount COMMA tokenaddr *(COMMA tokenid)
destination = tz[123][A-Za-z0-9]+{33}
amount = [0-9]+(.[0-9]*)
tokenaddr = KT1[A-Za-z0-9]+{33}
tokenid = [0-9]+
COMMA = %x2C
```

### Transaction

In a wallet setting, the sending account is to be specified outside of the batch definition.

The justification for this is that the batch is agnostic of where the transaction originates; in this way, the batch may be shared and reused.

#### Simple Tez Transaction

As per the [specification](#Formal Specification)'s `teztx` definition, the base-token tez transaction requires:
1. a tz(1|2|3) address as the intended destination; and
1. the amount of tez to send

#### Token Transaction

As per the [specification](#Formal Specification)'s `tokentx` definition, a token transaction requires:
1. a tz(1|2|3) address as the intended destination;
1. the amount of token to send;
1. the address to the contract that manages the token; and
1. (optional) the token_id of the token within the contract

## Exception Handling

If any line does not match a transaction specification, the line, the transaction, the file and the batch are considered invalid.

## Rationale

### Why CSV?

CSV is (or should be) well understood by financiers and accountants; in addition, spreadsheets support simple export/conversion of data to CSV.

### Why does the whole Batch fail at once?

Context: if one line is not validated while parsing the Batch definition, the whole batch is not validated.

Reason: the protocol handles Batches in a similar way; if one operation of the batch fails, the whole batch is considered failed, and not applied.

## Backwards Compatibility

[N/A]

## Security Considerations

[N/A]

## Example

```
tz1Z3JYEXYs88wAdaB6WW8H9tSRVxwuzEQz2,1.23456
tz1cbGwhSRwNt9XVdSnrqb4kzRyRJNAJrQni,1000,KT1RJ6PbjHpwc3M5rw5s2Nbmefwbuwbdxton,2
tz1cbGwhSRwNt9XVdSnrqb4kzRyRJNAJrQni,2000,KT1RJ6PbjHpwc3M5rw5s2Nbmefwbuwbdxton
```

> Commentary: 
>   1. a simple tez transaction, destined for the address in the first field, in the amount of the second field
>   2. a simple token transaction, defined by the contract in the third field and the tokenid of the fourth field
>   3. a simple token transaction with the default tokenid of 0, or ignored in the case of a single-asset contract

## Implementations

See [Umami Wallet](https://gitlab.com/nomadic-labs/umami-wallet/umami) as a working implementation, since v0.3.7.

## Future Extension

It is understood that this standard limits operations to transactions only.

A possible extension to this standard may involve generalizing a batch to include arbitrary operations--such as contract calls (other than token transactions, which are included herein).

## Appendix

[1] CSV Standard: https://datatracker.ietf.org/doc/html/rfc4180

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

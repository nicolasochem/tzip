---
tzip: 9
title: Info Field for Payment Requests
status: Work In Progress
type: Informational
author: Martin Pospěch <martin@smartcontractlabs.ee>
created: 2019-06-25
---

## Summary

Miscellaneous information extension for payment requests.

## Abstract

This document describes an extension to [TZIP-8](/proposals/tzip-8/tzip-8.md) that adds an extra field to Tezos payment requests. The field can contain simple description of payment or their purpose. Wallets can dispay this in transaction history or when approving the payment.

## Motivation

UX of Tezos-based applications and wallets would be improved if it was possible to attach descriptions to payments. Although transactions to regular addresses can't contain any extra information, it can still be kept and displayed by wallets.

## Specification

The payment request consists of a payload, which is encoded with Base58Check, and a prefix. The payload is an array of objects, one for each requested operation. It always contains the `content` object, which holds the request data. Extra information used by extensions can use another object called `extensions`. Each extension has its own namespace there.

Information about the purpose of the payment will use a field called `info` within the `tzip9` namespace in the `extensions` object:

```json
[
    {
        "content": {
            "kind": "transaction",
            "amount": "123000",
            "destination": "tz1Ph8mdwaRp71XvixaExcNKtPvQshe5BwcR"
        },
        "extensions": {
            "tzip9": {
                "info": "1 Blockaccino, 1 Scala Chip Frappuccino"
            }
        }
    }
]
```

## Appendix

### TZIP-8 Implementations Supporting the Standard
* TBA

### Wallets Implementing the Standard
* TBA

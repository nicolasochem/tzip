---
tzip: FA1.2
title: Approvable Ledger
type: Financial Application
author: Konstantin Ivanov, Ivan Gromakovskii
advocate: Konstantin Ivanov, Ivan Gromakovskii
created: 2019-04-12
---

## Why using `SENDER` address rather than `SOURCE`?
<a name="sender-vs-source"></a>

Using `SOURCE` instruction is considered treacherous, at least by
[Ethereum community](https://consensys.github.io/smart-contract-best-practices/recommendations/#avoid-using-txorigin).

There are chances that this instruction will be deprecated in Michelson some day.

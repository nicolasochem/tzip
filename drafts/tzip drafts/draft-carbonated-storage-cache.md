---
title: Carbonated Storage Cache
status: Draft
author: YunYan (yunyan@marigold.dev), Gabriel (ga@marigold.dev)
type: -
created: 2020-12-09
date: 2020-12-15
version: 0
---

## Summary

This TZIP proposes a cache mechanism for carbonated storage on protocol level.

## Abstract

Tezos charges gas fee for all database I/O. But, charging for every access may significantly increase the total cost of contract execution. Therefore having a mechanism for decreasing gas consumption brings extra competitive advantage to Tezos.

This TZIP proposes an in-memory cache mechanism which caches all requested serialized data so that re-access any already requested data will be more efficient. This cache mechanism would be transparent to Tezos protocol so that the gas fee for database accessing can be reduced correspondingly.

## Motivation

All storage data access takes time and gas because it requires to access the underneath database. That is to say, if a contract need multiple storage data or access same data repeatedly, the contract will need to pay more gas and have longer execution time.

To improve the data access efficiency is simple, one could just introduce the database cache. This solution, however, wouldn't be able to reduce gas fee. Because how the database cache will be executed is basically a black box to Tezos protocol. In other words, Tezos cannot actually benefit from using database cache in the point of view of gas fee.

The way to go is clear, a cache mechanism should be added into the Tezos protocol so that the database access rate could be decreased and the gas fee would be reduced correspondingly.

## Design

### The Cache Structure

A _cache record_ should correspond to a _database access_ which can be viewed as an *index*-to-*value* mapping, where, in Tezos case, *index* can always be translated into `string list` and *value* is actually a `bytes`. Therefore, it's natural to pick a `map` of `string list` and `bytes` as the structure of the cache required here.

### Cache Mechanism and Gas Consumption

All data will be cached during its introducing, updating or accessing. The contract will still need to pay the full cost of those operations. However, all data retrieving from cache will cost no gas (might still need pay the cost for _deserializing_).

### The Space Limitation and Replacement Policy

The memory is a limited resource. One cannot expect for putting everything into a cache. Thoerefore introduce a space limitation is practical and necessary. Currently the expected space upper-bound of cache is 2GB unless it proved insufficient.

The primary desien is to realize two replacement policies - the [FIFO](https://en.wikipedia.org/wiki/Cache_replacement_policies#First_in_first_out_(FIFO)) and the [LFRU](https://en.wikipedia.org/wiki/Cache_replacement_policies#Least_frequent_recently_used_(LFRU)). Once any one policy is determined to be superior to the other one in our use case, the inferior should be removed.

## Test Cases

One of the places where the carbonated storage are used is the *big_map*. It's fair to verify the proposed cache by testing how th big_map will be affected. There are two main angles here: firstly, we would test its *operability* to make sure the cache is actually working as we designed. On top of it, we would also check if the gas consumption is reduced accordingly. Let's also categorize tests by its safety. Meaning, a test is *safe* if it wouldn't raise any error; and, is *unsafe* if it could raise some error.

|             | **unsafe**                                              | **safe**                                                |
| ----------- | --------------------------------------------------- | --------------------------------------------------- |
| **operability** | [x] set<br>[x] get<br>[x] delete | [x] set<br>[x] get<br>[x] delete |
| **reduction**   | [x] get | [x] get |

All test cases can be found in [test_cache.ml](https://gitlab.com/marigold-dev/tezos/-/blob/yy@carbonated-storage-cache/src/proto_alpha/lib_protocol/test/cache.ml).

To run all tests:

```
dune build @src/proto_alpha/lib_protocol/runtest
```

To run tests only for cache:

```
dune build @src/proto_alpha/lib_protocol/runtest_proto_alpha_cache
```

## Implementations

Please check [https://gitlab.com/marigold-dev/tezos/-/commits/yy@carbonated-storage-cache](https://gitlab.com/marigold-dev/tezos/-/commits/yy@carbonated-storage-cache) for more implementation detail.

### The Cache Structure

The cache structure and its operators are defined in module `Raw_context` and exported through module `Raw_context.T`.

- [src/proto_alpha/lib_protocol/raw_context.ml](https://gitlab.com/marigold-dev/tezos/-/blob/yy@carbonated-storage-cache/src/proto_alpha/lib_protocol/raw_context.ml)
- [src/proto_alpha/lib_protocol/raw_context.mli](https://gitlab.com/marigold-dev/tezos/-/blob/yy@carbonated-storage-cache/src/proto_alpha/lib_protocol/raw_context.mli)

### Reduce the Gas Consumption

Not every storage would be affected. In fact, since the goal is to reduce the cost of all gas-required storage accesses, only the carbonated storage should be modified.

- [src/proto_alpha/lib_protocol/storage_functors.ml](https://gitlab.com/marigold-dev/tezos/-/blob/yy@carbonated-storage-cache/src/proto_alpha/lib_protocol/storage_functors.ml)

## Appendix

- The *Hot and Cold Storage* section in this [post (tezos agora)](https://forum.tezosagora.org/t/ideas-for-a-faster-cheaper-tezos/1789)
- [Cache replacement policies (wikipedia)](https://en.wikipedia.org/wiki/Cache_replacement_policies)
- [Reducing the cost of Michelson execution and typechecking (hackmd)](https://hackmd.io/Ia37mg4-Sqy1WEgzsLSPng?view)

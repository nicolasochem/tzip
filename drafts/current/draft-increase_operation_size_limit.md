---
title: Increase Operation Size Limit to 32KB
status: Draft
author: Keefer Taylor <keefer@tessellatedgeometry.com>
type: 
created: 2021-01-08
date: 2021-01-08
version: 0
---

## Summary

The current size limit of an encoded operation payload on Tezos is 16KB. It is proposed that this limit be increased to 32KB.

## Description and Rationale

Operations in the Tezos protocol are limited to 16KB. This is fine for most use cases, such as batch transfer operations or contract invocations.

Smart contracts are deployed by serializing a Michelson contract to bytes, and deploying them as an origination operation. Often, complicated contracts exceed 16KB in size.

It is possible to get around the current 16KB limit by placing code inside lambdas that are stored within bigmaps, but it not always convenient to do so. Additionally, it appears that loosening the limit from 16KB to 32KB will cover a large fraction of impacted contracts without any substantial harm to the nettwork.

Tezos has a system for charging users for space on chain (storage burn) that ensures that users have proper incentives to keep their storage use as low as possible. Increasing this limit therefore has significant positive impact but does not appear to have any significant negative consequences as users already pay for the cost of their storage.

## Specification

Implementation will require modification of a single constant in the economic protocol.

Currently, the limit is specified as:

```ocaml=
let max_operation_data_length = 16 * 1024 (* 16kB *)
```

The code would instead read:

```ocaml=
let max_operation_data_length = 32 * 1024 (* 16kB *)
```


## Backwards Compatibility

The change is fully backwards compatible with the existing chain.

## Security Considerations

It is possible that the change may impact chain performance because of bottlenecks in transmitting and validating operations at the P2P communications level, the mempool level, and other places in the protocol.

This therefore represents a potential for a DoS attack against the chain, or for accidental overload of resources. In practice, it is not believed that doubling the limit will have a significant impact, but testing will need to be performed to confirm this.

Tezos' economic model (transaction fees, node mempool filters, storage burn) should provide sufficient protection against these attacks; if testing reveals otherwise, then the cost models should be updated to prevent such issues.

Additionally, larger contracts consume more space on disk, but presuming that storage charges are commensurate with actual costs, this should not have any impact, as larger contracts will pay more for their storage. Again, if this is not currently true, the cost model should be updated.

## Test Cases

In additional to normal unit and integration tests, we should test three cases to verify that this change has not had a negative impact:
1) Operations under 16KB can still be injected. (Proves that previous functionality is still intact.)
2) Operations above 16KB and under 32KB can be injected (Proves that new functionality works as intended.)
3) Operations above 32KB are rejected (Proves limit still exists.)
4) Large numbers of large contracts should be injected into a test system to demonstrate that this does not present a Denial of Service vector. (Proves that there has not been an unexpected impact on performance.)

These tests can be perfomed as unit tests using a Flextesa environment. 

## Implementations

A full implementation is given in the following merge request: https://gitlab.com/tezos/tezos/-/merge_requests/2460

## Appendix

Original bug: https://gitlab.com/tezos/tezos/-/issues/1053

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

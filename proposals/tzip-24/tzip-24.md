---
tzip: 24
title: Single-step Meta-transactions Interface
author: Mudit Marda (mudit@tezosindia.foundation), Sachin Tomar (sachin.tomar@biconomy.io), Ahmed Al-Balaghi (ahmed@biconomy.io), Viswanath Kapavarapu (vishy@biconomy.io)
status: Draft
type: Interface (I)
created: 2021-03-08

---

## Summary

TZIP-024 is an extension of [TZIP-17](https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-17/tzip-17.md) and proposes a standard for a single-step gasless or "Meta" transaction interface: a lightweight and secure on-chain emulation of tzn accounts without requiring to pay gas for transactions. 

## Abstract

On-boarding users to Tezos blockchain and smart contracts usually requires a normal Tezos `tz1`, `tz2`, etc. account to submit transactions by paying fees. This requires:

- A pre-existing Tezos account to inject the `reveal` operation, which currently costs
  `0.06425 Tez`
- A method to pay the holder of the pre-existing account for the reveal

The Single-step Meta-transaction interface emulates `tzn` accounts in the contracts, providing an incredible and easy way for user onboarding, retention and usability of DApps. It supports many use cases such as gasless transactions, paying gas fees in another token, batched transactions and more, ultimately bettering the overall UX on DApps. 

For operability of meta-transactions, this proposal defines:

- A signing message format similar to TZIP 17, with all the necessary information to perform a meta-transaction
- Safeguards such as user specific counter, to protect the user from replay attacks across chains, across the contracts and within the contract itself
- A way to verify the meta-transaction signature on the smart contract
- Modifications to the target contract like replacing `sp.sender` with `sp_sender`

To use the interface:

- A user reads the `counter` specific to the user from the storage of the target contract.
- The user lists the parameters, hashes them, and signs the hash of the parameter along with the safeguarding context variables (counter, chain Id, etc.) to create a `Meta-transaction Blob`. The message signing format is similar to that in TZIP 17, with the addition of a `tx_expiry_time` field.
- Any account may then submit the `Meta-transaction Blob` on behalf of the user to the target contract for immediate execution.

## Motivation
Currently UX on Dapps do not do a good job for being user friendly, and dapps have to spend quite a lot of efforts to solve problems at the crypto transactional layer. Thus by leveraging meta-transactions, its an incredible tool developers can use to simplify and remove crypto complexities from their Dapp to spearhead adoption - ultimately removing friction expands markets. 

This TZIP is intended to provide a standard for a secure protocol that leverages meta-transactions for any Dapp on Tezos that wishes to provide single-step gasless transaction functionality and more. It is also intended to support new stakeholders called relayers that are able to support and relay transactions. In addition, this TZIP provides an elegant and efficient solution by not requiring to rewrite the contract or adding duplicate specialized entrypoints for meta-transaction.

## Specification

As a part of this TZIP, we have created a `MetaTransactionTemplate` contract which performs signature validity and counter related checks. The Base contract is consumed by the `MetaTransactionTemplate` contract which spits outs the modified meta-transaction enabled base contract. This is done using the `buildExtraMessages` function of SmartPy, which modifies the functions of a SmartPy Contract Class on compile time.

### Contract Modifications

The following syntactical and semantic changes need to be introduced in the SmartPy smart contracts to enable meta-transactions:
- Use `sp_sender` instead of `sp.sender` across the entire base contract.
Here is a sample code snippet, `sp.verify(sp_sender, self.data.owner)`
- All entry_points of the base contract should take a single `params` argument record instead of accepting multiple arguments to the entry_point.
For example, the entrypoint should look like `def your_entry_point(params)` instead of `def your_entry_point(x, y)` and params should be accessed as `params.x` and `params.y` inside the function.

### Storage specification and updates

All user counters are mapped to their addresses and stored in the `user_counter` big_map where the key is the `user address` and the value is the `counter nat`.

When a Meta-transaction is executed for a particular user address, the `counter: nat` of the specific user in the big_map `user_counter` is updated.

### Usage

To make a Meta-transaction Blob, a user having a `public_key` with the desired key hash, i.e. `tz1`, `tz2`, etc. should

- Read the `counter` specific to the user from the `user_counter` big_map within the storage of the target contract
- Choose the entrypoint of the target contract required to be triggered and form the Michelson parameters it accepts (params)
- Apply the Michelson instructions `PACK` on the params, followed by `BLAKE2B` to get the hash(`param_hash`) for signing
- Sign the hash of the params(`param_hash`) along with the safeguarding context variables including the chain ID(`chain_id`), counter(`counter`), an optional meta transaction expiry time (`tx_expiry_time`) and target contract address(`contract_addr`) to create the `Meta-transaction Blob` which is ready to be relayed to the blockchain. 

Thereafter, any account may submit the `pair (option %meta_tx_params) %params` (where `%meta_tx_params` is `pair (pair (nat %counter) (key %pub_key)) (pair (signature %sig) (option %tx_expiry_time timestamp))`) to the target contract and execute the corresponding meta-transaction on behalf of the user's `public_key`.

In the meta-transaction blob,

- `public_key` is the user's/signer's public key which would be the source of the meta-transaction
- `param_hash` is the `Blake2B` hash of the `pack`ed `params`
  - For example, if the parameter is `42`, we might calculate it using:
    `PUSH nat 42; PACK; BLAKE2B`
  - For example, if the parameters are `42`, `tz123`, we might calculate it using:
    `PUSH nat 42; PUSH address tz123; PAIR; PACK; BLAKE2B`
- `sig` is by the given `public_key` and signs the `bytes` with the following safeguarding context variables
  - `chain_id` - The network identifier at which the target contract exists
  - `contract_addr` - The address of the target contract where the meta-transaction blob will be executed
  - `counter` - The new value of a user-specific non-deterministic strictly-increasing counter to ensure that the meta-transactions gets included in order. A transaction can only be executed if the supplied counter is greater than the `last_used_counter`, and once a transaction has occurred, the `last_used_counter` will be updated to the current one. This prevents transactions to be executed out of order or more than once.
  - `tx_expiry_time` - An optional timestamp till which the meta-transaction blob is valid and should be executed. Thereafter the meta-transaction blob will expire. If not supplied, it defaults to the `default_expiry` timestamp. This `default_expiry` can be configured using the `set_default_expiry` entrypoint which requires owner privileges. The recommended value of the `default_expiry` timestamp is one hour. Further, the `tx_expiry_time` should be within a realistic upper bound so as to prevent transactions signed long ago by users to continue to remain valid. Again, this upper bound called `max_expiry` can be configured using the `set_max_expiry` entrypoint which requires owner privileges. The recommended value of the `max_expiry` timestamp is one day. 
  
The safeguarding context variables are signed along with the hashed entry_point parameters to prevent replay attacks as follows:

  - Chain ID - across chains
  - Target Contract's Address - across contracts
  - Counter - on the same contract
  
The optional meta transaction expiry time safeguarding context variable is also signed along with the other safeguarding context variables and the hashed entry_point parameters to protect against misuse of stale meta transactions and prevent unintended actions.

### Transaction execution

To differentiate a meta-transaction from a regular user transaction, the receiver contract simply checks if the optional field, i.e. the `meta_tx_params` (a record containing `counter`, `public_key`, `sig` and an optional `tx_expiry_time`) is explicitly included along with the contract parameters. If it is included, the transaction is handled as a meta-transaction and otherwise it is handled as a regular user transaction. 

When executing such meta-transactions, the contract verifies the signature and the safeguarding context variables (`chain_id`, `contract_addr`, `counter` and `tx_expiry_time`) as per the criteria specified above. The receiver contract also adjusts the `sp_sender` correctly with the key hash of the user `public_key` who is the source of the meta-transaction.

### Missigned and Expired Meta-transaction Blobs

If a Meta-transaction Blob is missigned, the called entrypoint must fail with (`FAILWITH`) the string `"MISSIGNED"`.

If an expired Meta-transaction Blob is attempted to be executed, the called entrypoint must fail with (`FAILWITH`) the string `"META_TX_EXPIRED"`.

### Off-chain Views

The `MetaTransactionTemplate` contract implements the following [TZIP-016](https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-16/tzip-16.md) off-chain-views:
- `GetDefaultExpiry: unit → nat` To access the contract's default expiry in seconds
- `GetCounter: unit → nat` To access the current counter
- `GetMaxExpiry: unit → nat` To access the upper bound of the contract's expiry in seconds

## Implementations and Test Cases

- An implementation of meta-transaction in SmartPy with appropriate test cases may be found
  [here](https://github.com/bcnmy/mexa-tezos/tree/dev)

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

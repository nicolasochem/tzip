# Indexer events

While off-chain events are a generic purpose mechanism, they are perfectly suitable for specifying custom indexing logic. This is a good alternative to limitations on contract storage type or other restricting standards.  
Currently there are two major use cases off-chain events help to handle: non-standard token balance updates and contract/token metadata updates.  

An indexer event is defined by its `"name"` and `"returnType"`.  
While parsing the event name an indexer should remove delimiters (non alphanumeric characters) and convert string to lowercase in order to allow a certain level of flexibility for being in sync with the source language guidelines.

## Token balances

It is not possible for the indexer to determine which particular balances have changed if the invoked method is not standardized (i.e. any method except for *FA2/FA1.2* `transfer`), or if there was an initial token distribution at the origination time.  

Using events one can tell indexer which particular accounts are altered and what are the balance changes. Typical scenarios for the `michelsonParameterEvent` kind are `mint` and `burn` calls responsible for token issuance and withdrawal respectfully. Accordingly, the `michelsonInitialStorageEvent` kind will work for the predefined token distribution at the time of contract creation.  

NOTE, that depending on the event kind it's only possible to determine either balance deltas or entire new balances. This ambiguity is resolved by the event return type:

| Event kind | Delta/Balance | Value type |
| ---------- | ------------- | ---- |
| `michelsonParameterEvent` | Delta | `int` |
| `michelsonExtendedStorageEvent` | Balance | `nat` |
| `michelsonInitialStorageEvent` | Delta, Balance | `int`, `nat` |

Naturally this is not applied to the NFT case.

### Single asset balance updates

For *FA1.2* ([TZIP-7](https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-7/tzip-7.md)) and *FA2* ([TZIP-12](https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-12/tzip-12.md)) contracts with a single asset (token ID = 0) it is suggested to use a simple approach which does not take `token_id` into consideration. It allows to write more concise hence effective event scripts.  

#### Name

`singleAssetBalanceUpdates`

#### Return type

Token balance deltas/values (can be both positive and negative) grouped by account.

| Language  | Delta type definition | Balance type definition |
| --------- | --------------------- | ------------------------|
| Michelson | `map address int`     | `map address nat` |
| Pascaligo | `map (address, int)`  | `map (address, nat)` |
| Smartpy   | `sp.TMap(sp.TAddress, sp.TInt)` | `sp.TMap(sp.TAddress, sp.TNat)` |

Micheline expression:

```json
{"prim": "map", "args": [
    {"prim": "address"}, 
    {"prim": "int"}]}
```

#### Example

- Pascaligo [source](./examples/004_fa2_sa_parameter_event.ligo)
- TZIP-20 JSON [file](./examples/004_fa2_single_asset.json)

### Multi asset balance updates

For FA2 contracts holding multiple assets one should use the event variation that differentiates tokens.

#### Name

`multiAssetBalanceUpdates`

#### Return type

Token balance deltas (can be both positive and negative) grouped by account and token ID.

| Language  |  Delta type definition | Balance type definition |
| --------- | ---------------------- | ----------------------- |
| Michelson | `map (pair address nat) int` | `map (pair address nat) nat` | 
| Pascaligo | `map ((address * nat), int)` | `map ((address * nat), nat)` |
| Smartpy   | `sp.TMap(sp.TRecord(account = sp.TAddress, token_id = sp.TNat), sp.TInt)` | `sp.TMap(sp.TRecord(account = sp.TAddress, token_id = sp.TNat), sp.TNat)` |

Micheline expression:

```json
{"prim": "map", "args": [
    {"prim": "pair", "args": [        
        {"prim": "address"},
        {"prim": "nat"}], 
    {"prim": "int"}]}
```

#### Example

- Cameligo [source](./examples/005_fa2_ma_parameter_event.mligo)
- TZIP-20 JSON [file](./examples/005_fa2_multi_asset.json)

### NFT balance updates

For FA2 contracts holding NFT assets that could be issued in a single copy only. The "owner" field made optional in order to handle token burn.

#### Name

`nftAssetBalanceUpdates`

#### Return type

| Language  |  Type definition |
| --------- | ---------------- |
| Michelson | `map nat (option address)` |
| Pascaligo | `map (nat, option (address))` |
| Smartpy   | `sp.TMap(sp.TNat, sp.TOption(sp.TAddress))` |

Micheline expression:

```json
{"prim": "map", "args": [
    {"prim": "nat"},
    {"prim": "option", "args": [{"prim": "address"}]}]}
```

## Metadata

There are cases when it's not possible to (effectively) detect a metadata change:

- Http/https metadata URI is used to locate the [TZIP-16](https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-16/tzip-16.md#metadata-uris) file.
- Off-chain view is used for [custom storage access](https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-12/tzip-12.md#token-metadata-storage-access)

A suggested approach is letting indexer know about metadata changes via off-chain events.

### Token metadata updates

#### Name

`tokenMetadataUpdates`

#### Return type

Set of IDs of tokens that require metadata update.

| Language  |  Type definition |
| --------- | ---------------- |
| Michelson | `set nat` |
| Pascaligo | `set (nat)` |
| Smartpy   | `sp.TSet(sp.TNat)` |

Micheline expression:

```json
{"prim": "set", "args": [{"prim": "nat"}]}
```

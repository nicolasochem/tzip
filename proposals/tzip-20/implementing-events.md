# Implementing off-chain events

Writing an off-chain event is quite simple, the main difficulty is to carefully convert types and to properly construct the resulting TZIP-20 section.

## Inferred events

First of all, make sure that you really need to implement an off-chain event: if you are using one of the [predefined types](./tzip-20.md#basic-approach) for storing token balances/metadata, indexers (or other consumers) will be able to infer updates on their own.

## Event kind

Selection of the event kind depends on two things:
1. Which operation kind do you want to handle, transaction or origination;
2. What data do you need to process.

If need to cover the storage initialization during the contract deployment, your choice is the `michelsonInitialStorageEvent`.  
If you can derive event logs just from the entrypoint arguments — use `michelsonParameterEvent`.  
If it's not enough, there is `michelsonExtendedStorageEvent` which gives you access to the contract storage and those lazy *Big_map* that have changed.

## Return type

Return type is storage type of the event script. The only requirement is not to use types that don't have or have an ambiguous empty value. For instance:
```
option => None ✅
map => {} ✅
list => {} ✅
set => {} ✅
string => "" ⛔️
bytes => 0x ⛔️
address => ? ⛔️
pair string string => ? ⛔️ 
```

### Indexer events

In case you want to emit events about token balance updates or changes to the metadata, you should use the types described in the [indexer events](./indexer-events.md) doc.  
The principle is simple:
If you are developing a 
- Single asset contract => use `singleAssetBalanceUpdates`  
- Multi asset contract => `multiAssetBalanceUpdates`
- NFT contract => `nftAssetBalaceUpdates`  

## Parameter type

All event kinds allow to reuse most of the types you defined in your contract implementation.

### Parameter event

Event parameter type is equal to the contract parameter type, i.e. you can reuse it as is.  Alternatively one can derive a reduce subset of entrypoints needed for triggering this particular event.  

For instance, you have a contract implementing TZIP-12 interface, but you only need to trigger the event on "mint" calls. You can craft a parameter type consisting of this entrypoint only `or (pair %mint address nat) unit` and be sure you won't miss anything because we are working with normalized parameters.

Indeed, the following parameter value is correctly typechecked against both full and reduced parameter type:
```json
{
    "entrypoint": "mint",
    "value": {"prim": "Pair", "args": [{"string": "tz1QwPbZtpjJ3Jv7VJjFgs2dEcjqCFDhmzi2"}, {"int": "1"}]}
}
```

### Initial storage event

Event parameter type is derived from the contract storage type by replacing all `big_map` occurrences with plain `map`. This allows you to iterate over lazily stored data.  

Example:  
`(big_map %ledger address nat)` is converted to `(map %ledger addres nat)`.

### Extended storage event

Event parameter type is derived from the contract storage type by replacing all `big_map` occurrences with plain `map` and wrapping `big_map` values with `option`. This allows you to iterate over lazily stored data and handle cases when `big_map` entries are removed.  
  
Example:  
`(big_map %owners nat address)` is converted to `(map %owners nat (option address))`.

## Code

Implementing event script is basically writing a contract that consumes a value of type `pair (<parameter>) (<returnType>)` and leaves a value of type `pair (list operation) (<returnType>)` on the stack.  

Also, rememeber that you cannot use most of Tezos-specific instructions, the only exception made for:
- `SOURCE`
- `SENDER`
- `AMOUNT`
- `CHAIN_ID`
- `NOW`
- `LEVEL`

## Generating TZIP-20 entry

Finally, you can generate the off-chain events section for your TZIP-16 JSON.  
The inputs are:
- Event name, either inferred (if you implement one of the indexer events) or custom (camelCase);
- Event script — an output from the event contract compilation, in Micheline JSON;
- A list of entrypoints your event has to fire on (applied to parameter/extended storage event kinds)

The output is produced as follows:
```json
{
    "events": [{
        "name": "eventName",
        "description?": "Optional description",
        "implementations": [{
            "parameter": /* eventScript[0]['args'][0] */,
            "returnType": /* eventScript[1]['args'][0] */,
            "code": /* eventScript[2]['args'][0] */,
            "entrypoints?": []
        }]
    }]
}
```

NOTE the way event script is unboxed: sections 0-2 are `parameter`, `storage`, and `code` respectfully.
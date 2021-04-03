# Invoking off-chain events

## Event script

In order to reconstruct the Michelson script from a TZIP-20 entry one have to do the following substitution:

```json
{
    {"prim": "parameter", "args": [ /* parameter {} */ ]},
    {"prim": "storage", "args": [ /* return-type {} */ ]},
    {"prim": "code", "args": /* code [] */ }
}
```

This is actually a valid Michelson contract that could be deployed, or executed via standard node RPC.
NOTE that this scheme is a bit different from the one used in TZIP-16 off-chain views.

### Empty initial value

In order to invoke the Michelson script one need to supply an initial storage (empty state). TZIP-20 spec states that off-chain event return type has to have a non ambiguous empty value, e.g.:

```
option => None
map => {}
list => {}
set => {}
```

## Event parameters and trigger rules

Depending on the event kind and operation type one has to use different strategies of constructing parameters for the event script. Also, there are 

### Parameter event

Applied to transactions (both external and internal). Transaction parameters have to be normalized (see data normalization) and then forwarded to the event script invocation.

```
{
    "kind": "transaction",
    "parameters": {
        "entrypoint": "",
        "value": {}
    }
}
```

TZIP-20 entry for a parameter event contains a list of entrypoints one should trigger the event invocation. NOTE that you have to do normalization prior to checking for inclusion.

### Initial storage event

Triggered on contract origination. Initial storage from the deployed contract script is passed as a parameter to the event script.

```
{
    "kind": "origination",
    "script": {
        "storage": {}
    }
}
```

NOTE that there might be cases when initial storage contains raw Big_map pointers instead of initial state (usually when data is copied from another Big_map). Such cases are not handled by the current event kind, because it would require additional context calls and Big_map indexing, which is the opposite to the stateless nature of events.

### Extended storage event

Triggered when one of the entrypoints listed has been called. Storage and list of *Big_map* updates from operation result are combined into an "extended" storage (see data normalization for details) and then forwarded to the event script.
  
#### External transaction
```
{
    "kind": "transaction",
    "metadata": {
        "operation_result": {
            "storage": {},
            "big_map_diff": []
        }
    }
}
```

#### Internal transaction
```
{
    "kind": "transaction",
    "result": {
       "storage": {},
       "big_map_diff": []
    }
}
```

## Data normalization

All the data passed to the event scripts has to be normalized depending on the event kind.

### Eliminating `Big_maps`

All off-chain event kinds forbid usage of `big_map` type thus all such occurences are replaced by `map` in every event implementation.  
Accordingly, all the values of type `big_map` have to be handled appropriately. 
There are two possible representations that `big_map` can have in *Micheline* (concrete syntax for the Michelson language):

1. A list of key-value pairs `[{"prim": "Elt", "args": [{"string": "key"}, {"string": "value"}]}, ...]`
2. An integer pointer to an existing *Big_map* `{"int": "42"}`

#### Initial storage

Initial storage is provided together with the contract code in the origination operation. Typically it doesn't contain *Big_map* pointers, instead there are lists of key-value pairs.  
However pointers can occur, and this is the case event currently cannot handle. A typical scenario is a contract factory that initializes child contract storage with content of an existing *Big_map* (i.e. *Big_map* copy workflow).

#### Extended storage

Extended storage is basically *Big_map_diff* items merged into the resulting storage attached to the operation receipt. *Big_map_diff* can contain both upserts and removals, and in order to reflect that in Michelson we need to wrap diff value with `option`. 

Consider the following storage type:
```
storage (pair (big_map %ledger address nat) (nat %totalSupply))
```

And an operation receipt:
```json
{
    "storage": {"prim": "Pair", "args": [{"int": "42"}, {"int": 200000}]},
    "big_map_diff": [{
        "action": "update",
        "big_map": "42",
        "key_hash": "exprus2Taan1pH5Xdx2zp1hBXvLxHwSYm14DH1p1Af4PegCartdjgV",
        "key": {
            "string": "tz1iXizjXT7wnWGFQrmQgRTbYFDhPuAoijaT"
        },
        "value": {
            "int": "100500"
        }
    }, {
        "action": "update",
        "big_map": "42",
        "key_hash": "exprtuEE6N3BTSaaPnXqDoAo7nbfWTCqUkegnKWMRRHXu2HKhz8TVM",
        "key": {
            "string": "tz1XW4RqNY4WMEiSyAfb49CJTGqZK5AkrXB3"
        }
    }],
    // ... rest of operation result ...
}
```

The extended storage will be:
```json
{
    "prim": "Pair",
    "args": [
        [{
            "prim": "Elt",
            "args": [
                {"string": "tz1iXizjXT7wnWGFQrmQgRTbYFDhPuAoijaT"},
                {"prim": "Some", "args": [{"int": "100500"}]}
            ]
        }, {
            "prim": "Elt",
            "args": [
                {"string": "tz1XW4RqNY4WMEiSyAfb49CJTGqZK5AkrXB3"},
                {"prim": "None"}
            ]
        }],
        {"int": "200000"}
    ]
}
```

A general algorithm for generating event parameters:

```json
[{
    "prim": "Elt",
    "args": [{ /* key */ }, {"prim": "Some", "args": [{ /* non-null value */ }]}]
}, {
    "prim": "Elt",
    "args": [{ /* key */ }, {"prim": "None"}]
}]
```

Where event parameter type is `map (<key_type>) (option (<val_type>))`.
  
NOTE how *Big_map* pointer converts to a list of key pairs from *Big_map_diff*.  
If there are no items for a particular ID, an empty list should be merged.

### Resolving entrypoint ambiguity

There can be more than one way to invoke a certain method of a smart contract in Tezos. The concept of entrypoints is very lightweight in Michelson, and under the hood it's still a value of a single type (`parameter`) that is actually pushed onto the stack.  

Example:

```json
{
    "entrypoint": "default",
    "value": {"prim": "Left", "args": {"prim": "Unit"}}
}
```

given `parameter (or (unit %foo) (string %bar))` is equivalent to

```json
{
    "entrypoint": "foo",
    "value": {"prim": "Unit"}
}
```

The latter will be called the "normal form".  

Normalizing parameters is essential for the `"michelsonParameterEvent"` case:

1. For correct event triggering.
2. To be able to specify only needed entrypoints in the event script.

Say you have a contract with 20+ entrypoints and you want to fire an event if only one of them is being invoked. Instead of copying the entire `parameter` type from the contract code you can derive a reduced type, e.g. `parameter (or (%target_entrypoint string) unit)`

## Patching context

Event developers are allowed to use several Tezos-specific Michelson instructions. Here is the complete list of such instructions and the according bindings and types:

- `SOURCE` => source address of the external (initiating) operation (`address`)
- `SENDER` => source address of the current operation (`address`)
- `AMOUNT` => operation amount (`mutez`)
- `CHAIN_ID` => chain ID specified in the operation group (`chain_id`)
- `NOW` => timestamp of the block containing this particular operation (`timestamp`)
- `LEVEL` => level of the block containing this particular operation (`nat`)

### Using node RPC

- `eventScript` => Micheline JSON `[{"prim": "parameter"}, {"prim": "storage"}, {"prim": "code"}]`
- `emptyState` => an according empty value for the specified `returnType` in Micheline JSON, e.g. `option => {"prim": "None"}, map => [], list => [], set => []`
- `entrypoint` => forward the operation entrypoint in case of `michelsonParameterEvent`, otherwise set `default`
- `parameterValue` => Micheline JSON for the event parameters

```
POST /chains/main/blocks/<LEVEL>/helpers/scripts/run_code
{
    "script":       <eventScript>,
    "storage":      <emptyState>,
    "entrypoint":   "<entrypoint>",
    "input":        <parameterValue>,
    "amount":       "<AMOUNT>",
    "chain_id?":    "<CHAIN_ID>",
    "source?":      "<SENDER>",
    "payer?":       "<SOURCE>",
    "balance":      "0"  // Since Edo
}
```

In response you will get the following structure:
```json
{   
    "operations": [],
    "big_map_diff?": [],
    "lazy_storage_diff?": [],
    "storage": /* return value */
}
```

## Inferred events

You may noticed that all predefined types for storing token balances/metadata are *Big_map* based, which means we will be looking for updates in the *Big_map_diff* receipt.  

In order to match the standardized updates we first need to establish a relation between *Big_map* names and pointers and confirm the type. We will need contract storage type and a resulting storage value from the operation receipt to do so.

Consider the following example:
```
storage (pair (big_map %ledger address nat) (nat %total_supply)) ;
```
By traversing the storage type AST one can locate the node having a suitable field annotation and argument types.

```json
{
    "prim": "Pair",
    "args": [
        {"int": "42"},  /* Big_map ID  */
        {"int": "100500"}
    ]
}
```
By matching a storage value against its type we can deduce the current ID for the inspected *Big_map*.  

Now we can filter *Big_map_diff* items and depending on the case (single/multi/nft asset) apply balance updates:
```json
{
    "big_map_diff": [{
        "action": "update",
        "big_map": "42",
        "key_hash": "exprus2Taan1pH5Xdx2zp1hBXvLxHwSYm14DH1p1Af4PegCartdjgV",
        "key": {
            "string": "tz1iXizjXT7wnWGFQrmQgRTbYFDhPuAoijaT"
        },
        "value": {
            "nat": "100500"
        }
    }]
}
```
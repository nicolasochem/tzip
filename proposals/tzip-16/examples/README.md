# Examples for TZIP-16

## Contract Metadata Examples

In increasing complexity order:

- `example-000.json` → the “empty” one
- `example-001.json` → just one field
- `example-002.json`
- `example-003.json`
- `example-004.json` → on view with two implementations
- `example-005.json` → `#004` + another view with more Michelson

Here is `#005` pretty-printed by `tezos-client`:

```
    Version: 0.42.0
    License: MIT (The MIT License)
    Interfaces: TZIP-16, TZIP-12
    Views:
     View "view0":
       Michelson-storage:
         Code: '{}'
         Annotations: 
       REST-API-Query:
         Specification-URI: https://example.com/v1.json
         Specification-URI: /get-something
         Path: GET
     View "view-01":
       Michelson-storage:
         Version: PsCARTHAGazKbHtnKfLzQg3kms52kSRpgnDY982a9oYsSXRLQEb
         Parameter: '(pair (mutez %amount) (string %name))'
         Return-type: '(map string string)'
         Code: '{ DUP ; DIP { CDR ; PUSH string "Huh" ; FAILWITH } }'
         Annotations:
          %amount -> The amount which should mean something in context. It's
            in `mutez` which should also mean something more than lorem ipsum
            dolor whatever …
          %name -> The name of the thing being queried.
```


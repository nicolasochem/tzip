---
tzip: 16
title: Contract Metadata
status: Work In Progress
type: Interface
author: Seb Mondet <seb@mondet.org>
created: 2020-06-30
---

## Abstract

This document describes a standard for Tezos smart contracts to advertise
metadata about themselves.

The standard defines:

- A basic structure to find _some_ metadata in a contract's storage.
- An URI scheme to find data: on-chain (contract storage) or off-chain
  (web-services or IPFS).
- An extensible JSON format (JSON-LD or JSON-Schema) to describe the metadata,
  it contains among other things:
    - provenance information,
    - references to other standards implemented,
    - off-chain “views” (Michelson functions to query the contract), and
    - custom extensions.
- an optional entry-point to validate metadata information.
 
The standard is meant to be extended/specialized by other TZIPs, for instance by
adding fields to the JSON format of the metadata or imposing certain off-chain
views.


## Meta-draft Section

<b style="color: red">This section will disappear as draft gets properly written</b>

Cf. old HackMD with ideas/discussions: <https://hackmd.io/CiBPx3RYQZWGXmSXuAlpVw>

- Intro
    - Justification: no need to change protocol for off-chain things
    - Justification: we need a standard for contract devs & tools, wallets, and
      Indexers/explorers to agree on formats and semantics
- Use-case Example
    - Quick round-trip / non-detailed “example”
    - Get an IPFS URI, get the JSON, call an offchain view.
- Define the piece of Michelson storage
    - Big-map + default “first key”
    - There is a proposal to have the option of replacing the big-map with a
      view entrypoint (*I*, Seb, don't think it's worth the extra complexity)
- Define URI format
    - Refer to other known URIs: `https:`, `ipfs:`
    - Define how to point inside a contract
    - Should the hash in `hash://` really start with `0x` to allow future other
      encodings?
- Define The metadata blobs “meta-format”
    - In the `.md` file: only informal-ish but precise enough definition
    - Some fields are links which use the previous URI format
    - Attachment: [JSON Schema](https://en.wikipedia.org/wiki/JSON#JSON_Schema)
      or [JSON-LD](https://en.wikipedia.org/wiki/JSON-LD)
- Define Reserved simple fields
    - Authorship/provenance
    - Other TZIP references
- Define Offchain views
    - Micheline encoded as concrete strings? or JSON? or both options?
        - Likely **going to move towards JSON-only** (WIP).
    - Exact semantics with examples
- (should-we) Define Offchain big-map-diffs or events (?)
    - cf.
      [agora](https://forum.tezosagora.org/t/deriving-fa-token-balance-updates-from-big-map-diff/1972)
- Define Optional `assertMetadataSHA256` Entrypoint
    - Not sure about this
    - Do we want other hashes?
- How to “derive” from TZIP-16
    - Should we also modify TZIP-12 or just provide examples?
- Implementations
    - Reference known implementations

All the “Define …” could be sub-sections of a **Definition of The Standard** section.

## Introduction


## Example Use-Case

## Definition of The Standard

### Contract Storage

To provide a TZIP-16-compliant initial access-point to the metadata from a given
on-chain contract (`KT1...` address) one must include a `%metadata` field in
the contract-storage.

The field can be anywhere within the top-level tree of nested pairs forming the
storage type (meaning that it cannot be inside an `or`, an `option`, a `map`,
etc.) and must have the following type:

```
(big_map %metadata string bytes)
```

At least one value must be present: 

- the one for the empty string key (`""`).
- the value must be a URI as specified in the following section which points to
  a JSON document as specified in the one after.

### Metadata URIs

URIs are used here first to locate metadata contents, but the format may be reused 
in other similar cases for instance in extensions to this specification.

See the specification of a URI's generic format:
<https://tools.ietf.org/html/rfc3986>

In the context of this specification, valid schemes include:

- `http`/`https`: see
  [RFC 7230](https://tools.ietf.org/html/rfc7230#section-2.7).
- `ipfs`: see IPFS URIs
  [specification](https://www.iana.org/assignments/uri-schemes/prov/ipfs), and
  [documentation](https://github.com/ipfs/in-web-browsers/blob/master/ADDRESSING.md#addressing-with-native-url).
- `tezos-storage`: defined in the section below.
- `sha256`: defined in the section right after.

#### The `tezos-storage` URI Scheme

URIs that point at the storage of a contract, should provide the following
information:

**Host:**

- Location of the contract pointed to, with the format `<address>.<network>`.
- Example: `KT1QDFEu8JijYbsJqzoXq7mKvfaQQamHD1kX.mainnet` or
  `KT1QDFEu8JijYbsJqzoXq7mKvfaQQamHD1kX.NetXNfaaGTuJUGF`
- This is all optional, if contract address or network are not provided the
  defaults are “current” ones within a given context. If only one is present, it
  should be interpreted as a contract address within the current network.

**Path:** a string used as key in the `%metadata` big-map of the contract. If
the path starts with a `/` we remove it; only the first “slash” character is
removed, if any (*rationale:* URIs containing a host component always start with
a `/`, cf.  [section 3.3](https://tools.ietf.org/html/rfc3986#section-3.3) of
RFC 3986).

Examples:

- `tezos-storage:hello`: in the current contract fetch the value
  at key `"hello"` from the `%metadata` big-map.
- `tezos-storage://KT1QDFEu8JijYbsJqzoXq7mKvfaQQamHD1kX/foo`: get the value at
  `foo` from the metadata big-map of the contract
  `KT1QDFEu8JijYbsJqzoXq7mKvfaQQamHD1kX` (on the current network).
- `tezos-storage://KT1QDFEu8JijYbsJqzoXq7mKvfaQQamHD1kX//foo`: like the above,
  but the key is `/foo` (first `/` removed from the path).

#### The `sha256` URI Scheme

This is a compound URI, the *host* must be understood as the SHA256 hash in
hexadecimal format (preceded by `0x` as in Michelson) of the resource being
pointed at by the path of the URI (which should be percent-encoded to avoid
ambiguity with `/` characters).

Example:

`sha256://0xeaa42ea06b95d7917d22135a630e65352cfd0a721ae88155a1512468a95cb750/https:%2F%2Ftezos.com`


### Metadata JSON Format

We first define the format in a rather informal way; a JSON-Schema specification
is provided as an annex to this document (**TODO**).

The metadata should be a valid JSON object
([STD-90](https://tools.ietf.org/html/std90) /
[RFC-8259](https://www.rfc-editor.org/info/rfc8259)) with various top-level
fields.

*All* top-level fields are optional, i.e. the empty object `{}` is valid
metadata.

For compatibility, a compliant parser should ignore any extra fields it doesn't
know about.

#### Reserved Fields

This standard defines a few top-level fields:

`"name"`:

- A single string, free format.
- It is recommended to have “name” strings help identifying the purpose of the
  contract.

`"description"`:

- A single string, free format.
- Preferably a set of proper *natural language* paragraphs.

`"version"`:

- A single string, free format.
- It is recommended to have version strings which attempt at uniquely
  identifying the exact Michelson contract, or at least its behavior, as a
  precision w.r.t the `name` field.  Of course, none of that can be enforced.

`"license"`:

- Either a single string value or an extensible object
 `{ "name": <string> , "details" : <string> }`.
- It is recommended to use _de facto standard_ short names when possible, see
  the Debian
  [guidelines](https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/#license-short-name)
  for instance.

`"authors"`:

- A list of strings.
- Each author should obey the `"Print Name <'contact'>"`, where the `'contact'`
  string is either an email address, or a web URI.

`"interfaces"`

- A list of strings.
- Each string should allow the consumer of the metadata to know which interfaces
  and behaviors the contract *claims* to obey (other than the obvious TZIP-16).
- In the case of standards defined as TZIPs in the present repository, the
  string should obey the pattern `"TZIP-<number><extras>"` where `<extras>` is
  additional information prefixed with a space character.
- Example: an FA2 contract would (at least) have an `"interfaces"` field
  containing `["TZIP-12"]` or `["TZIP-12 git 6544de32"]`.

`"views"`:

- A list of off-chain-view objects, defined in the following section.

Example:

```json
{
  "version": "foo.1.4.2",
  "license": "ISC",
  "authors": [ "Seb Mondet <seb@mondet.org>" ],
  "interfaces": [ "TZIP-12" ],
  "views": [
     // ... see below ...
  ]
  // ... potential extensions ...
}
```


#### Semantics of Off-chain Views

An off-chain view object has at least 3 fields:

- `"name"`; the canonical name of the query (as in function name,
  e.g. `"get-balance"`).
- `"description"`: a human readable description of the behavior of the view
  (optional field).
- `"implementations"`: a list of implementation objects: usable definitions of
  the views. Each implementation is a one-field object where the field name
  discriminates between various kinds of views. Below, this standard defines 2
  of those kinds, `"michelson-storage-view"` and `"rest-api-query"`, further
  deriving standards may add new ones.
- `"pure"` (optional, default: `false`): a boolean “tag” advertising that the
  view should be considered *a (pure) function* of the storage of the contract
  and extra parameters passed to the view. I.e., that if no operation changes
  the storage of the contract, one can assume that the view returns always the
  same result for a given parameter. Examples of non-pure views are for instance
  queries which depend on the current time & date.

Example:

```json
{
  "name": "get-allowance-for-user",
  "description": "Get the current allowance for a user of the contract.",
  "pure": "true",
  "implementations": [
     { "michelson-storage-view" : { /* ,,, see below ... */ } },
     { "rest-api-query" : { /* ,,, see below ... */ } },
     // ... potential extensions ...
  ]
}
```

##### Michelson Storage Views

The `"michelson-storage-view"` field is a JSON object describing a sequence of
Michelson instructions to run on a pair formed by a given parameter and the
storage of the contract being queried in order to leave the execution stack with
the queried value.  For this object we define 3 fields and a custom type
“`michelson`” (see below) and an extra optional field:

- `"parameter"` (optional): an (annotated) Michelson type of the potential
  external parameters required by the view code; if the field is absent the view
  does not require any external input parameter.
- `"return-type"` (required): the type of the result of the view (i.e. for the
  value left on the stack); the type can also be annotated.
- `"code"` (required): the Michelson code expression implementing the view.
- `"annotations"`: a list of objects documenting the annotations used in the 3
  above fields. These objects have two string fields `"name"`, the annotation
string, and a human-readable blob of text `"description"`.
- `"version"` (optional): a string representing the version of Michelson that
  the view is meant to work with; Michelson versions *are* base58check-encoded
  protocol hashes.

The 3 “Michelson” fields have the same format, they are JSON values obeying the
Michelson JSON format of the Tezos protocol (sometimes referred to as
“Micheline” encoding).

Example:

```json
{
  "parameter": {
    "prim": "pair", "args": [
      {"prim": "mutez", "annots": ["%amount"]},
      {"prim": "string", "annots": ["user"]}
    ]
  },
  "return-type": {"prim": "nat"},
  "code": [
    {"prim": "DUP"},
    {"prim": "DIP", "args": [
        [
          {"prim": "CDR"},
          {"prim": "PUSH", "args": [
    // ....
  ],
  "annotations": [
     { "name": "amount", "description": "The number of token in question." },
     { "name": "user", "description": "The token-user being referred to." },
     // ...
  ]
}
```

#### Rest API Views

The `"rest-api-query"` field is an object describing how to map the view to an
[Open API](https://github.com/OAI/OpenAPI-Specification) description of a
REST-API.

- `"specification-uri"` (required): a string giving the location (URI) of the
  full Open API specification.
- `"base-uri"` (optional): The recommended `"server"` to use.
- `"path"` (required): The API path within the Open API specification that
  implements the view.
- `"method"` (optional, default: `"GET"`): The method used for the view.

Example:

```json
{
  "specification-uri": "https://example.com/openapi/my-token",
  "base-uri": "https://example.com/my-token/v2",
  "path": "/allowances",
}
```

### Optional `assertMetadata<hash>` Entrypoints

For the cases when a batched transaction requires assurances that a (portion of)
the contract metadata has not changed at the time the batch-operation is
included in a block, the contract implementation may provide one or more
`assertMetadata<hash>` entrypoints where `<hash>` is any of the Michelson hash
functions `SHA256`, `BLAKE2B`, or `SHA512`.

If included, the type of such an entrypoint must be:

```
(pair (string %key) (bytes %hash))
```

and behave as follows:

- If the corresponding hash of the value at key `%key` in the metadata `big_map`
  is equal to `%hash`, then do nothing and succeed.
- If the value is not present, call `FAILWITH` with the string `"NOT_FOUND"`,
- If the value is present but its hash is not equal to `%hash`, call `FAILWITH`
  with either `Unit` or with the correct hash if available.


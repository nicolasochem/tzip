---
tzip: 021
title: Rich Contract Metadata
author: Josh Dechant (@codecrafting)
status: Work In Progress
type: Interface
created: 2020-11-12
---

## Abstract

This proposal is an extension of [TZIP-016][1] and describes a rich metadata 
standard for asset(s) linked with contracts.

Many of the terms in this standard are derrived from [The Dublin Core, RCF 2413][2].

## Motivation & Goals

This rich metdata standard aims to:

1. Simplify the creation of asset rich metadata
2. Provide a commonly understood interface
3. Confirm to existing and emerging standards
4. Allow global and international scope
5. Be extensible
6. Provide interoperability among ecosystem members (contracts, indexers, wallets, libraries, etc)

This standard also aims to rich enough to describe a wide variety of asset types,
from real-life assets such as paintings, books, sculptures, and other works of art
to digital art, 3D objects, audio tracks and record albums, to digital collectibles or
other in-game items.

## Specification & Schemas

A [JSON-Schema specification][6] is provided as an annex to this document.

The schema may be applied to the contract level metadata, to the token level
metadata in the case of FA2 tokens, or any combination thereof.

The schema defines the following additional types:

---

### `asset` (object)

Properties of the `asset` object are designed to live at the root level of the
contract metadata or root level of the token metadata.

#### `title` (string)

The name given to the asset.

#### `description` (string)

General notes, abstracts, or summaries about the contents of an asset.

#### `creator` (string)

The primary person, people, or organization(s) responsible for creating the intellectual content of the asset.

#### `contributor` (string)

The person, people, or organization(s) that have made substantial creative contributions to the asset.

#### `publisher` (string)

The person, people, or organization(s) primarily responsible for distributing or making the asset available to others in its present form.

#### `date` (string) *[format: date]*

A date associated with the creation or availability of the asset.

#### `type` (string)

A broad definition of the type of content of the asset.

#### `tags` (string)

A comma-separated list of tags that describe the subject or content of the asset.

#### `genres` (string)

A comma-separated list of genres that describe the subject or content of the asset.

#### `language` (string) *[format: [RFC 1776][4]]*

The language of the intellectual content of the asset as defined in RFC 1776.

#### `identifier` (string)

A string or number used to uniquely identify the asset. Ex. URL, URN, UUID, ISBN, etc.

#### `rights` (string)

A statement about the asset rights.

#### `rightUri` (string) *[format: uri-reference]*

Links to a statement of rights.

#### `assetUri` (string) *[format: uri-reference]*

A URI to the asset.

#### `imageUri` (string) *[format: uri-reference]*

A URI to an image of the asset. Used for display purposes.

#### `externalUri` (string) *[format: uri-reference]*

A URI with additional information about the subject or content of the asset.

#### `formats` (array)

The object is an array with all elements of the type `format`.

#### `attributes` (array)

Custom attributes about the subject or content of the asset.

The object is an array with all elements of the type `attribute`.

##### Example:

```json
"attributes": [
  {
    "name": "Base", 
    "value": "Starfish"
  }, 
  {
    "name": "Eyes", 
    "value": "Big"
  }, 
  {
    "name": "Mouth", 
    "value": "Surprised"
  }, 
  {
    "name": "Level", 
    "value": "5",
    "type": "integer"
  }, 
  {
    "name": "Stamina", 
    "value": "1.4",
    "type": "number"
  }, 
  {
    "trait_type": "Stamina Increase", 
    "value": "10",
    "type": "percentage"
  }
]
```

#### `assets` (array)

Facilitates the description of collections and other types of resources that contain multiple assets.

The object is an array with all elements of the type `asset`.

---

### `format` (object)

Properties of the `format` object:

#### `uri` (string) *[format: uri-reference]*

A URI to the asset represented in this format.

#### `hash` (string)

A checksum hash of the content of the asset in this format.

#### `mimeType` (string)

Media (MIME) type of the format.

See [IANA Media Types][5]

#### `fileSize` (integer)

Size in bytes of the content of the asset in this format.

#### `fileName` (string)

Filename for the asset in this format. For display purposes.

#### `duration` (time)

Time duration of the content of the asset in this format.

#### `dimensions` (dimensions)

Dimensions of the content of the asset in this format.

#### `dataRate` (dataRate)

Data rate which the content of the asset in this format was captured at.

#### Example

```json
{
  "uri": "ipfs://...",
  "hash": "e9ed141df1cebfc89e466ce089eedd4f125aa7571501a0af871fab60597117b7",
  "mimeType": "audio/mpeg",
  "fileSize": 7134739,
  "fileName": "Track-1.mp3",
  "duration": "00:56:46",
  "dataRate": {
    "value": 320,
    "unit": "kbps"
  }
}
```

---

### `attribute` (object)

Properties of the `attribute` object:

#### `name` (string, required)

Name of the attribute.

#### `value` (string, required)

Value of the attribute.

#### `type` (string)

Type of the value. To be used for display purposes.

#### Example:

```json
{
  "name": "Stamina", 
  "value": "1.4",
  "type": "number"
}
```

---

### `dataRate` (object)

Properties of the `dataRate` object:

#### `value` (integer, required)

#### `unit` (string, required)

#### Example:

```json
"dataRate": {
  "value": 192,
  "unit": "kbps"
}
```

---

### `dimensions` (object)

Properties of the `dimensions` object:

#### `value` (string, required)

#### `unit` (string, required)

#### Example:

```json
"dimensions": {
  "value": "512x512",
  "unit": "px"
}
```

---

## Implementations

## Copyright

Copyright and related rights waived via
[CC0][2].

[1]: https://gitlab.com/tzip/tzip/-/blob/master/proposals/tzip-16/tzip-16.md
[2]: https://www.ietf.org/rfc/rfc2413.txt
[3]: https://creativecommons.org/publicdomain/zero/1.0/
[4]: https://tools.ietf.org/html/rfc1766
[5]: https://www.iana.org/assignments/media-types/media-types.xhtml
[6]: metadata-schema.json

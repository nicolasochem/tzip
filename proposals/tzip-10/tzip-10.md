---
tzip: 10
title: Wallet Interaction Standard
author: Alessandro De Carli <a.decarli@papers.ch>, Mike Godenzi <m.godenzi@papers.ch>, Andreas Gassmann <a.gassmann@papers.ch>, Pascal Brun <@pascuin>
discussions-to: https://forum.tezosagora.org/t/wallet-interaction-standard/1399
status: Draft
type: LA
created: 2019-09-17
---

## Summary

Communication between wallets and decentralised applications.

## Abstract

This document describes the communication between an app (decentralised application on Tezos) and wallet (eg. browser extension).

## Motivation

A user wants to be able to interact with decentralised applications e.g. uniswap-like decentralised exchange or a game that uses NFTs, he wants to use his preferred wallet and avoid having to install a new wallet for each application he uses.

To enable adoption of decentralised applications in the Tezos ecosystem a standard for the communication between these apps and wallets is needed. Application developers shouldn't need to implement yet another wallet just for their use case and users shouldn't need a multitude of wallets just to use a certain service.

This standard should form consensus of how the types of messsages for this communication look like.

## Specification

### Communication Protocol Version 1.0.0 (Version code 1)

The entire protocol relies on asynchronous calls. A call consists of a request message and a asynchronous response message.

## Versioning

The transport layer is responsible for the communication of the protocol version. All of the discussed messages will be wrapped with a protocol header including the version code.

## Message Types

The following chapters describe the different message types that exist between the app and wallet. Even though in some programming languages the order of keys in a dictionary/map is arbitrary
for this protocol the order does matter. Also this protocol assumes a secure and authenticated transport layer was established hence no messages can be spoofed.

### 1. Permission

App requests permission to access account details from wallet.

#### Request

```typescript
type PermissionScope =
  | "read_address"
  | "sign"
  | "payment_request"
  | "threshold";

interface PermissionRequest {
  scope: PermissionScope[];
}
```

`appMetadata`: An App should be identifiable by the user, for example with a name and icon.

`scope`: The App should ask for permissions to do certain things, for example for a list of addresses or if the App can request to sign a transaction (maybe even without confirmation for micro-transactions). The following scopes are defined:

- `read_address`: this indcates the app want to be able to read the address.
- `sign`: this indicates the app wants to be able to sign.
- `payment_request`: this indicates the app wants to perform payment requests.
- `threshold`: this indicates the app wants the wallet to show the user a threshold prompt, so that in future transactions below this threshold can be handled automatically by the wallet.

#### Response

```typescript
interface PermissionResponse [
  { address: string; networks: string[]; permissions: PermissionScope[] };
]
```

#### Errors

`NO_ADDRESS_ERROR`: Will be returned if there is no address present for the protocol / network requested.

`NOT_GRANTED_ERROR`: Will be returned if the permissions requested by the App were not granted.

#### Notes

The `threshold` scope is only an optional suggestion for the wallet. Even if the wallet does not support this it will still be compatible with the protocol.

### 2. Sign Payload

App requests that a payload is signed.

#### Request

```typescript
interface SignPayloadRequest {
  payload: byte[];
  sourceAddress: string;
}
```

`payload`: The unsigned, payload.

#### Response

```typescript
interface SignPayloadResponse {
  signature: byte[];
}
```

`signature`: The signature of the payload.

#### Errors

`NOT_GRANTED_ERROR`: Will be returned if the signature was blocked

`NO_PRIVATE_KEY_FOUND_ERROR`: Will be returned if the private key matching the sourceAddress could not be found

### 3. Payment Request

App sends parameters like `recipient` and `amount` to the wallet and the wallet will prepare the transaction and broadcast it.

#### Request

```typescript
interface PaymentRequest {
  network: string;
  recipient: string;
  amount: string;
  source?: string;
}
```

`network`: The network used for the payment request.

`recipient`: The address of the recipient.

`amount`: The amount that will be sent, as a string in mutez (smallest unit).

`source`: The source address. This is optional. If no source is set, the wallet will let the user chose.

#### Response

```typescript
interface PaymentResponse {
  transactionHash: string;
}
```

`transactionHash`: The transaction hash if it has been broadcast to the node (see `PaymentRequest`)

#### Errors

`PARAMETERS_INVALID_ERROR`: Will be returned if any of the parameters are invalid

`BROADCAST_ERROR`: Will be returned if the user choses that the transaction is broadcast but there is an error (eg. node not available)

### 4. Broadcast Transactions

App requests a signed transaction to be broadcast.

#### Request

```typescript
interface BroadcastRequest {
  network: string;
  signedTransaction: byte[];
}
```

`network`: The network used for the payment request.

`signedTransaction`: The signed transaction payload

#### Response

```typescript
interface BroadcastResponse {
  transactionHash: string;
}
```

`transactionHash`: The transaction hash.

#### Errors

`TRANSACTION_INVALID_ERROR`: Will be returned if the transaction is not parsable or is rejected by the node.

`BROADCAST_ERROR`: Will be returned if the user choses that the transaction is broadcast but there is an error (eg. node not available).

## Transport Layer

This standard requires a transport layer that can cover the following use cases:

- Same Device Desktop to Desktop (e.g. Galleon)
- Same Device Desktop to Hardware Wallet (e.g. Ledger)
- Same Device Mobile to Mobile (e.g. Cortez)
- Two Device Desktop to online Mobile (e.g. Wetez)
- Two Device Desktop to offline Mobile (e.g. AirGap)

The transport layer used for app-wallet communication we propose is using a decentralised messaging service. We are proposing to use the [matrix protocol](https://matrix.org/). Other projects in the blockchain
space like [Raiden](https://medium.com/raiden-network/raiden-transport-explained-939d7741b6f4) have been using matrix successfully to cover very similar requirements. The long term vision is that
the Tezos reference node will eventually include such a messaging service by default, replacing the matrix network in the long term.

The main reasons why we propose to use a decentralized messaging service as the transport layer between app and wallet are:

- decentralization
- enables modern user experience
- covers all of the scenarios described above
- easy to integrate with all kind of wallets
- minimal effort to "join" for a wallet
- support for oracles (e.g. push service)

### Serialisation

The serialisation used for the transport layer messages requires an algorithm which is space efficient and fast to encode/decode. These properties rule out the common encoding standards
XML and JSON. After researching various alternatives (BSON, RLP, Protocol buffers and amino) we propose to use the space efficient yet very easy to implement RLP encoding. The main reasons
why we are proposing RLP are:

- simple algorithm, no need to generate/compile code on a per-message basis (like with e.g. protocol buffers)
- very space efficient (only 1-2 bytes of overhead per new structure)
- same object always has same byte output, making it suitable to use with signatures <sup>1</sup>

<sup>1</sup> this is not a hard requirement for this initiative as of now, we can however foresee that it might become relevant in future.

#### 1. Handshake (opening a channel)

Communication between app and wallet requires a secure setup. This is the proposed handshake process:

1. we define the communication/transport layer as 'channel'
2. app generates and stores (e.g. local storage) a channel asymmetric key pair
3. app serialises public key, channel version, app name, app id (url) and app icon (url) in an handshake uri <sup>2</sup>
4. handshake uri is either shown as QR or made openable by app
5. wallet receives handshake uri
6. wallet generates and stores a channel asymmetric key pair
7. wallet serialises public key and channel version in an handshake uri
8. wallet uses P2P network layer to reach out to app and send handshake uri <sup>3</sup>
9. wallet and app compute DH symmetric channel key
10. symmetric encrypted acknowledgment message is sent
11. channel is open

**Why not simply use directly the crypto address in the wallet?**  
There would be one big upside namely the wallet-app channel could be easily restored on any wallet that
imported the crypto private key material, this would also allow the user to accept/confirm messages coming from the app on different devices. The reason for the decision against such a solution is because it would imply that if a app sets up a channel once with a wallet it will always be able to send messages to it in future and since security is of outmost importance for this standard the decision has been made to have random channel keys which can be destroyed/ignored when an app turns rogue.

<sup>2</sup> app id and app icon can be spoofed by any dapp, however the browser extension should make sure that spoofing is avoided. Also the user always has to check him/herself if the shown URL matches
the one in his/her address bar.
<sup>3</sup> public key is used to derive address on which both parties are listening.

#### 2. Unresponsive counter party

If for whatever reason one party will not respond to messages anymore the user should be informed accordingly. The user can then choose to either close the channel and reopen or just
retry at a later point in time.

#### 3. Closing a channel

Closing a channel will require one of the parties to send a channel close operation. After closing the channel the party will no longer listen to the channel (fire and forget).

#### 4. Cleanup

Channels without activity for 90 days should be considered as dead. All state related to that channel should be removed.

## Test Cases

_TBD: Test cases for an implementation are strongly recommended as are any proofs of correctness via formal methods._

## Implementations

_TBD: Any implementation must be completed before any TZIP is given status “Last Call”, but it need not be completed before the TZIP is merged as draft._

## Apendix

### Wallets implementing the standard

- [AirGap](https://airgap.it)

### Applications using the standard

- TBD

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

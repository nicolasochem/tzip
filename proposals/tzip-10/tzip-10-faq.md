---
tzip: 010
title: LA1 - Wallet Interaction Standard
author: Alessandro De Carli <a.decarli@papers.ch>, Mike Godenzi <m.godenzi@papers.ch>, Andreas Gassmann <a.gassmann@papers.ch>, Pascal Brun <@pascuin>
discussions-to: https://forum.tezosagora.org/t/wallet-interaction-standard/1399
status: Draft
type: LA
created: 2019-09-17
---

## What has been discussed in the first workshop - 2019-09-29?

Feedback to this initial draft has been gathered in a workshop during the TQuorum Global Summit in New York with parties like Stove Labs, Cryptonomics, CamlCase, ECAD Labs, Keefer Taylor & Cryptium Labs.

### Feedback

- Tezos URI compatibility (check)
- contract monitoring communication between dapp <> wallet

* PermissionRequest

  - guaranteeing the security of the dapp not impersonating an other application
  - local storage of the browser
  - idea: use a smart contract to manage the permissions
  - idea: have different trust levels ex. on-chain access
  - idea: use SSL certificate for permission requests

* SignTransaction

  - broadcast and sign separate endpoints
  - dapp broadcasts signed transaction
  - Tezos URI compatibility
  - separate endpoint for arbitrary message signing
  - dapp forges transaction -> user decides if he signs transaction (extension should be able to unforge certain standards ex. NFT to display meaningful data to the user)

* PaymentRequest

  - use Tezos URI standard

* TransportLayer

  - use URI schemes to communicate with desktop application
  - use matrix messaging network in terms to act as a "relay" service (Tezos GitLab flag) for the nodes

### Questions

- avoid impersonation of dapp by other application
- how to avoid confusion between signing methods of existing libraries -> where is the implementation done in the the end?

### Inputs

- initial handshake with versioning etc.
- serialization, instead of json use protocol buffer etc.
- QR support with scheme url
- forging is dapps/sdk responsibility
- don't automatically broadcast have 2 api's

### Next steps

- Implementation -> first step: wallet extension (signing, broadcasting)

## What has been discussed in the second feedback call - 2019-10-24?

The unedited meeting notes from the call on October 24th which will be reviewed again and then incorporated into the proposal by @dcale.

**Transport Layer**

- any javascript dapp can connect to this (web rtc)
- authentication
  -- needed to send messages between the dapp and wallet
  -- authentication modul needs to be written

1. can be authenticated by Tezos accounts (arbitrary message signing)
2. with a signed transaction, that does not need to be broadcasted
   --> which approach will be used?

- how does dapp now that there is a wallet?

1. chrome extension can directly inject to dapp
2. SDK included in dapp can generate authentication QR code as a fallback
3. push notification send to wallet for authentication

- Why RLP and not use json or any other approach for serialisation
  -- with rlp you have a unique serialisation
  -- does it have to be rlp as the expected content of the message is known ahead of type

- would it make sense to have fallback method for same device approaches and not use the p2p network in that case
  -- as they probably have the same peer this will be an instant experience
  -- for later improvement a fallback channel could be used

### Message Types

**Permission**

- threshold, should something like this be optional or not as implementations or not might not include optional parameters
- room for evolution should be respected in the standard ex. threshold approach for automatic signing transactions without user input
- what would happen with layer 2 application ex. state channels
- threshold definition number of amounts, number of transactions, definition for certain asset/tokens
- suboperation is send over the manager operation is done by the wallet, recommended parameters like gas, fees, storage can be interpreted by the wallet but they can be changed
  --> threshold will be in the standard as an optional marker
  --> thresholds should be revisited in a separate standard

**Sign Payload**

- interaction with a dapp doesn't have to happen necessarily with a signature
- message that entails an entry point for a contract and a set of parameters and the potential sender
- send over only the suboperation

**Payment Request**

- recipientType should be introduced to distinguish the value of recipient to support more types

**Versioning**

- all messages also should have a version code for simpler debugging

## What has been discussed in the third feedback call - 2019-11-09?

- identifier -> public key so DH can be done directly
- why libsodium was taken -> base58 is not compatible with matrix as only lower case character are allowed
- VDS -> spam/ddos protection
- lower qr size -> research base32 encoding
- cleanup task for removing "inactive/unused" Matrix accounts
  -- remove them after a certain time period
  -- manual removal
  -- research purge-history api for cleanup

### Feedback

- PermissionRequests / Granted Permissions -> put sematics of the scopes in writing & what is expected of the wallet
  -> Guidelines/Suggestions

- PaymentRequest rename to OperationRequest
  -- parameters -> use the same approach as contract invocations

### Next steps

- share dockerhub link & documentation
- iterate over feedback, include in merge request
  -- include glossary and scenarios

---
tzip: 013
author: Kirill Kuvshinov (@kkirka)
advocate: Kirill Kuvshinov (@kkirka)
status: Work In Progress
created: 2020-01-02
---

# FA1.3 Rationale

This document analyzes the existing token standards available in different blockchain platforms and provides motivation behind the proposed FA1.3 standard.

## Related Works

### Basic token standards

1. Tezos provides a basic standard for fungible tokens called [FA1](/proposals/tzip-5/tzip-5.md). The proposed interface contains a `transfer` entrypoint that transfers funds between token holders, and two view entrypoints `getTotalSupply` and `getBalance` that return total number of tokens in circulation and a balance of a particular holder respectively.
1. Neo has a token standard called [NEP-5](https://docs.neo.org/docs/en-us/sc/write/nep5.html) that provides neither `approve`/`transferFrom`, nor any replacement; the only way to send tokens is `transfer` call, and there is no way to notify the receiver. A non-standard NEP-5.1 proposal adds mandatory `approve`, `transferFrom` and `allowance` methods to NEP-5 interface. NEP-5.1 compliance is required for tokens to be listed on decentralized exchanges.

### Approvable ledger standards

Approvable ledgers are the ones that allow token holders to `approve` operators to spend some amount of tokens on behalf of the token holder. Such ledgers provide an `approve` function that sets the desired `allowance`. The examples of approvable ledgers are ERC-20 and FA1.2.

Approvable ledgers have the following problems:

1. **No way for token holder to reject a transfer**

    The only mechanism such ledgers provide to control token spenders is `allowance`. Thus, a token holder can only be sure that a spender will not transfer *more* than she is allowed. Other constraints (like daily spending limits or limits based on external preconditions, e.g. ETH/USD exchange rate) are supposed to be done off-chain. Adjusting `allowance` manually forces users to store their private keys near the code that enforces the constraints, which may be undesirable.

    **Possible solutions:**

    - Allow only token holder to initiate a transfer, i.e. remove `transferFrom` entirely in favor of on-receive hooks — `ERC-223`.

    - Introduce operators that are authorized by a token holder and bound by before-send hooks specified by a token holder — `ERC-777`.

    - Acknowledge the problem, provide a basic `approve` mechanism and state that the general solution is out of scope of a token standard — `ERC-1155`.


2. **No way for token receiver to reject a transfer**

    Token receivers may not be willing to accept a certain token at least due to the following reasons:

    - They do not know how to work with this token (e.g. the receiver expects the token to implement a different standard or just not designed to work with tokens at all) — in this case, the receiver should have the ability to protect the sender and reject the transaction so that the spender does not lose her funds.

    - The token is a spam token. Some projects create free tokens that they distribute between well-known public contracts and known thought leader addresses. These spam tokens are visible in token trackers and act as a free advertisement. The receivers may want to block known spam tokens or whitelist the tokens they wish to receive.

    **Possible solutions:**
    - If a receiver is a contract, require it to implement an on-receive hook; if a receiver is an externally owned account, it cannot reject a transfer — ERC-223, ERC-1155.
    - If a receiver is a contract, require it to _announce an address that implements_ an on-receive hook; if a receiver is an externally owned account, allow but not require it to announce an address that implements an on-receive hook — ERC-777.



3. **No way to notify the receiver that the transfer has occurred**

    Receivers may need to update some state upon receiving a token. For example, there may be a crowdsale contract that accepts tokens. Upon receiving a transaction, it needs to allocate new tokens for the investor. With ERC-20 the only possible solution is to `approve` the tokens to the crowdsale contract and call some `deposit` method of the crowdsale contract that does a `transferFrom` operation and allocates new tokens to the investor.

    **Possible solutions:** same as for (2).


### [ERC-223](https://github.com/ethereum/eips/issues/223)

ERC-223 aims to tackle problems (2) and (3) from ERC-20 problems list. Instead of adopting `approve`/`transferFrom` mechanics, it requires all token receivers that are contracts to implement an on-receive hook: `tokenFallback(address _from, uint _value, bytes _data)` function.

### [ERC-777](https://github.com/0xjac/ERC777/blob/devel/eip-777.md)

Discussion: [https://github.com/ethereum/eips/issues/777](https://github.com/ethereum/eips/issues/777)

This standard proposes two major improvements over ERC-20: operators and hooks.

This standard solves some of the shortcomings of ERC20 while maintaining backward compatibility with ERC20. It avoids the problems and vulnerabilities of EIP223.

It goes a step further by allowing operators (generally contracts) which can manage the tokens in the same way that the ERC20 with infinite approve was allowed. Finally, it adds hooks to provide further control to token holders over their tokens. Note that, the usage of ERC820 provides backward compatibility with wallets and existing contracts without having to be redeployed thanks proxy contracts implementing the hooks.

**Operators:**
- Operator is an entity that can send or burn tokens on behalf of a token holder.
- Token holder can grant or revoke operator rights for a particular address.
- Token holder can gain fine control over operations via a `tokensToSend` hook: she can set a contract that can revert a transaction if deemed desirable (e.g. if a daily `send` limit is exceeded).

**Hooks:**
ERC-777 offers two hooks:
1. Before send hook that is called before any state changes are made. This hook is used to let the _token holder_ reject a transfer if she so desires.
1. After receive hook that is called after the state changes are made. This hook is used to _trigger post-transfer operations_ and let the _receiver_ reject a transfer if she so desires.

**Design choices:**

- Force `decimals` to be 18 (i.e. each token internally has 18 decimal places in its representation). For tokens that have a custom *granularity* (i.e. the smallest possible indivisible amount is greater than 10^-18), introduce a `granularity` parameter. ([discussion](https://github.com/ethereum/eips/issues/777#issuecomment-358021480), [decision](https://github.com/ethereum/eips/issues/777#issuecomment-358398093))
- External registry ([ERC-1820](https://eips.ethereum.org/EIPS/eip-1820)) to preserve compatibility with existing contracts and make possible to set hooks for externally owned accounts.

### Other platforms

- NEM uses an approach similar to colored coins (called "[mosaics](https://docs.nem.io/en/gen-info/namespaces)") for user-defined assets.
- Ethereum Classic inherits ERC-20 but there is a [draft ECIP-1021](https://github.com/ethereumproject/ECIPs/blob/master/ECIPs/ECIP-1021.md) by the author of ERC-223. This proposal, like ERC-223, replaces `approve`/`transferFrom` with execute-on-transfer.
- Tron has [both](https://developers.tron.network/docs/trc10-token) native TRC10 token, and a smart-contract based TRC20 token (which is similar to ERC-20).

## Open questions

### Should we add `data` parameter to transfer?
Both ERC-223 and ERC-777 add `data` parameter to transfers which seems to be required by the applications to encode metadata associated with transfers.

Adding the `data` parameter would render the interface incompatible with FA1, which is rather sad but bearable: we can add something like `transferWithData` to preserve compatibility.

## Design rationale

This section motivates the decisions behind the proposed standard

### Binary authorization for operators
A user can either authorize an operator, or not. This standard does not limit the capabilities of autorized operators in any way. Rather, we expect other standards to emerge that would make it possible to limit the scope of operators' actions, e.g. make approval limits or enable transfers if certain preconditions hold.

The scope control contracts are expected to check the necessary preconditions and proxy the third-party call to the token contract. In such scenario, users authorize these scope control contracts instead of authorizing a third party directly, thus gaining fine-grained control over the logic of authorization.


### No explicit `burn`

This standard does not require the conforming contracts to implement burning functionality. The argument for explicit burn is that, if deemed desireable, people may send their tokens to a non-existing account, and it not influence `totalSupply`, while it is often useful to account for burned tokens in `totalSupply`. Since this standard requires all externally owned accounts to be explicitly whitelisted, it is not possible to use the "shortcut" approach for destroying tokens by sending it to an address without the private key (e.g., a zero-address). The implementations MAY support explicit burn operation if this is acceptable in the corresponding domain.

### `transfer` rather than `send`

ERC-20 uses `transfer` and it was considered to be misleading due to the fact that Ethereum has different semantics for `send`ing and `transfer`ring ether. Tezos, in turn, has a Michelson operation called `TRANSFER_TOKENS` and FA1 uses `transfer` method as well. Since there is no ambiguity between the two in Tezos, and there is no notion of `send` in the existing code, calling the function `transfer` seems appropriate.

### Failing in hooks instead of emitting `%rejectTransfer`
The former is more in line with how Tezos transfers work, the latter makes batch transfers possible. However, batch transfers are generally discouraged because they are insecure: if some receiver fails due to some reason instead of calling `%rejectTransfer` the whole batch transaction will revert. It is a deliberate decision to prohibit batch transfers and ask hooks to `FAIL` rather than emit a reject operation.

### No external hooks registry
External hooks registry offers a way to find out the interface implementer contract for any given address. The interface implementer does not need to be the same address as the expected callee. In this case the interface implementer is called instead of the expected callee.

Ethereum has no introspection by design. If a contract tries to call an inexistent endpoint of another contract, the transaction either fails, or some fallback code is executed. While failed transaction is safe in terms of stuck funds, execution of a fallback function is an undesirable behavior, and may lead to lost tokens.

Contrary to Ethereum, Michelson offers a way to check whether the interface of the receiver contract contains a certain entrypoint. Michelson's `CONTRACT` instruction returns a contract if and only if the expected parameter matches the actual one.

Taking into account that Michelson offers introspection capabilities by design, and the amount of contract interactions one has to perform in order to call the registry and receive values back, we took a deliberate decision to **not** depend on an external hooks registry.

We have to note, though, that utilizing an external hooks registry yields additional benefit in case the receiver is a non-contract address, or if it is an already deployed contract. The token implementation may call external hooks for these addresses even if they do not expose `onTokensReceived` endpoint. Having said that, we deliberately chose to sacrifice such capability for the sake of minimizing the gas costs and implementation simplicity.

### Explicit `granularity`, no `decimals`
The `decimals` value controls how the amount of tokens is displayed in external interfaces. In Tezos contract developers are encouraged to use `mutez` (micro-tezos) to work with Tezos, i.e. Tezos has 6 decimals. It is yet unclear whether this value should be adopted for tokens. Nevertheless, we decided to set the number of decimals to some fixed value to simplify user interfaces and prevent confusion.

`granularity`, in turn, represents a smallest indivisible part of a token. It does not have to be a power of 10 and is introduced in order to model the real world. It should be included in the standard because people and wallets may rely on this value while making transactions.

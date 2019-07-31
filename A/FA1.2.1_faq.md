---
tzip: FA1.2.1
author: Ivan Gromakovskii
created: 2019-08-01
---

## Why do you suggest using a proxy contract?

Using a proxy contract one can adapt a contract with parameter `p1` to parameter `p2` as long as there is a total function from `p2` to `p1`.
It is the case for any contract `p1` which complies with FA1.2 when `p2` is `fa12core`.
We admit that there might be other options and this one may be not the best one.
However, it is subjectively the simplest and the most obvious one.

Another possible way to adapt contract's parameter `p1` is to pass a lambda which converts `p1` to `fa12core` to the caller contract.
Since the caller contract does not know `p1` and there is no way to pass type as an argument, we should hide it.
So this lambda's input type should be `fa12core` and the output should contain a value of type `p2` but `p2` should be hidden.
We can hide `p2` type into `operation` which is not parameterized by any type.
Specifically, suppose that contract `A` implements approvable ledger and we want to call one of its method from contract `B` which does not know `A`'s exact type.
Instead of passing `A`'s address we can pass `lambda fa12core operation` which is supposed to convert `fa12core` to `A`'s parameter and return `TRANSFER_TOKENS` operation which calls `A`'s entrypoint.
However, this approach is potentially dangerous from security perspective.
We must trust whoever passes such a lambda to our contract.
A malicious actor can pass a lambda which returns arbitrary operation, it can completely ignore `fa12core` that we pass to it and do whatever it wants on our behalf.

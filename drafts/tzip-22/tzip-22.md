---
tzip: 22
title: Dynamic Types in Michelson
author: Suzanne Soy (ligo@suzanne.soy https://gitlab.com/ligo.suzanne.soy)
status: Draft
type: Language
created: 2020-12-11
---


## Summary

Add dynamic types to Michelson.

## Abstract

Compilers targetting Michelson currently need to ensure that the
program is accepted by the Michelson type checker.

This ensures that the possible causes for failure are easily
identifiable: a failure can occur either because a Michelson
instruction triggered it (e.g. division by zero), as indicated in the
documentation, or because an explicit failure instruction like
`FAILWITH` was executed.

However, a compiler targetting Michelson could already have ensured
that the program is sound via other means, e.g. using the source
language's type checker. The source language's type system is unlikely
to be trivially compatible with Michelson's type system, as small
differences in type systems require extra work to translate. This
leaves language designers with a few suboptimal options: 

* Encode their type system's guarantees using Michelson types. This
  amounts to jumping through hoops to translate the properties of one
  system to the other, when these properties are similar but not
  identical. More powerful type system features (e.g. polymorphism and
  subtyping) would require substantial program transformations to
  convince a simpler type checker of the program's soundness
  (e.g. monomorphisation and virtual tables, respectively).

* Use casts and type witnesses everywhere to force the type of all
  expressions. This amounts to producing a fully-annotated version of
  the program (a non-trivial transformation sometimes called 
  elaboration), and turning those type annotations into casts. 
  Michelson does not support casts, although they can be emulated by 
  `PACK`ing the data and `UNPACK`ing it with a different type, which 
  is quite an expensive operation. Also, Michelson does not allow a 
  stack element or sub-element to contain an unknown type (no 
  polymorphism nor subtyping via an `object` or `Any` type). In order 
  to handle a value as an opaque item (e.g. whose contents could
  belong to one of a fixed number of types), this value needs to be
  encoded as a sequence of bytes and passed around in that form.

* Use casts sporadically to force the type of expressions when
  necessary. Since casting every expression would be costly both in
  code size and at run-time, there is an incentive to "optimize away"
  the casts, by encoding as much as possible of the source type system
  using Michelson's type system, and using casts otherwise. This puts
  an extra burden on the language developers, who need to figure out
  when those casts are needed.

Many source language features require jumping through such hoops, 
among them:

* recursion (which can be encoded using loops, but direct translation
  as recursive functions needs casts),
* parametric polymorphism,
* ad-hoc polymorphism (e.g. typeclasses),
* subtyping;
* row polymorphism;
* proofs that some potential failure cases are unreachable via
  dependent types or static analysis.

The proposed solution is to add some form of dynamic typing to
Michelson. We suggest adding a type named `dynamic`, which could hold
a value of any type. Two operations DYNAMIC_PACK and DYNAMIC_UNPACK
allow converting to and from this `dynamic` type.

## Motivation

Michelson does neither have a general instruction for casts, nor for 
dynamic types. This means that compilers targetting Michelson need to
translate the source language's type system into Michelson's type
system, or misuse bytes as a universal data type. The former is
difficult and sometimes impossible, when the source language's type
system is different from Michelson's (e.g. more expressive), and the
latter is costly in terms of code size and at run-time, and obscures 
the generated code, which may have to be audited before being 
originated on the Tezos blockchain.

## Specification

### New Types

We propose to add one new Michelson type:

* `dynamic`

### New Instructions

We propose to add two new Michelson instructions:

* `DYNAMIC_PACK`
* `DYNAMIC_UNPACK some_type`

### Overview

The `dynamic` type is produced only by the `DYNAMIC_PACK` operation,
and consumed only by the `DYNAMIC_UNPACK` operation.

### Type Attributes

Because an instance of the `dynamic` type could wrap values which
cannot be stored, compared and so on, the `dynamic` type is:

* not `Comparable`,
* not `Passable`,
* not `Storable`,
* not `Pushable`,
* not `Packable`,
* and not a valid `big_map` value.

### In-memory Representation

The `dynamic` type is represented as a wrapper around another
Michelson type. It is implemented using an existential type in OCaml
to hide the concrete type of the wrapped value until it is unpacked.

### Low-level Representation

A value of `dynamic` type could embedded values without valid 
persistent storage, therefore it would not have a low-level 
representation either.

### Dynamic Semantics

The dynamic semantics of `DYNAMIC_PACK` and `DYNAMIC_UNPACK` are
the same as the pair of operations `PACK` and `UNPACK`, except for
these differences:

* Any type can be consumed or produced by these operations (not just
  `Packable` types).
* They produce or consume an opaque type `dynamic` instead of `bytes`.
* The dynamically packed value is not actually encoded, but is simply 
  stored inside a container which hides the original type.
* Their run-time cost is therefore quite small, with respect to `PACK` 
  and `UNPACK`.

### Gas Costs

The main task of `DYNAMIC_PACK` is to instantiate one OCaml
constructor. Its gas cost should therefore be negligible.

The main tasks of `DYNAMIC_UNPACK` are to access that constructor's
argument, and compare the expected and actual types. We expect that
comparing the types will be the more costly task. However, the gas
cost of `DYNAMIC_UNPACK` should be much cheaper than that of `UNPACK`,
since it does not actually need to decode the value from bytes.

We will note that if a contract relies heavily on dynamic types, it
will likely unpack a shallow data structure containing more instances
of dynamic types. The comparison of the expected and actual types
should therefore only compare a few types in the tree before reaching
another opaque `dynamic` type.

## Rationale

A short rationale is included above for each part of the
specification.

Several other implementations of dynamic types were considered:
* a dynamic type which is accepted by all Michelson instructions, and
  usually produced as a result of instructions which make use of
  ad-hoc polymorphism. These include instructions like `ADD`, which
  would have several additional signatures like `dynamic → nat →
  dynamic` with a possible failure if the concrete type of the first
  argument is neither `int` nor `nat`). This implementation would
  require less annotations in generated Michelson code (therefore
  smaller code), at the expense of a more significant change to the
  Michelson specification and implementations, and with the risk that
  dynamic values may flow to unexpected parts of the program.

* explicit casts (where `CAST some_type` would be equivalent to
  `DYNAMIC_PACK; DYNAMIC_UNPACK some_type` using the current
  proposal). This would actually be of little help, since Michelson
  does not have subtyping. Therefore one cannot cast a value from one
  type to another different type. There are only a few possible use
  cases, e.g. casting an `or` type to one of its constituents, or
  casting a lambda to a function type accepting different arguments,
  or using casts as conversions from nat to int etc.

* a dynamic type which can appear as a `big_map` value in the storage,
  and so on: this is not immediately possible since the original value
  might not be `Storable`, `Comparable`, `Packable` etc. Even though
  it would be theoretically possible to have some form of transitive
  type attributes (that is, applying `DYNAMIC_PACK` to a `Comparable`
  value would yield a `Comparable dynamic`), it would require
  introducing a few non-trivial concepts in Michelson, e.g. some sort
  of parametric type attributes (which would ressemble
  typeclasses). This seems unwarranted for a first RFC, and should be
  considered, if deemed necessary, in separate incremental
  improvements.

Further discussion of this RFC should give the opportunity for a
consensus or objections to emerge.

## Backwards Compatibility

Care must be taken to leave the encoding of existing Michelson
instructions and types unchanged. There are a number of instruction
IDs which are unused and available for future instructions, so those
should be considered for use in an implementation of this RFC.

Aside from these encoding concerns, this RFC only adds a type and some
instructions which appear within a contract. The type cannot appear in
the contract's parameters, storage nor in big maps. Its addition
should therefore not be noticeable outside of the body of the
contract.

To sum this up, this RFC would NOT require:
* any stitching,
* any update to tools calling contracts,
* any update to tools which manipulate contract APIs
  (e.g. cross-language interface generators or the part of indexers
  which displays contract APIs).

It would however require updating:
* indexers, decompilers and other tools which process
  Michelson code for display, transformation and other purposes;
* interpreters, compilers, parsers, syntax highlighters,
  type-checkers, proof frameworks and other tools for Michelson which
  closely depend on its specification.

A note on forwards compatibility: adding these instructions means that
they should be supported by later versions of Michelson. If for some
reason it would become desirable to remove these instruction at some later
point, they could be replaced in most cases by `PACK` and `UNPACK`,
but, when used with types which are not `Packable`, rewriting the
contract would be challenging. It therefore seems that once this
instruction is made available, it should remain for the foreseeable
future, or be replaced by a mechanism providing a similar
feature (e.g. another implementation of dynamic types, subtyping,
existential types, etc.).

## Test Cases

Test cases should be drafted if this RFC is deemed interesting enough
to justify further work. The feature should be discussed with the
people working on the formalization of Michelson (e.g. Mi-Cho-Coq) and
on the formalization of languages targetting Michelson
(e.g. https://gitlab.com/tomjack for
https://gitlab.com/ligolang/ligo).

## Implementations

https://gitlab.com/metastatedev/tezos/-/merge_requests/61

## Appendix

* [Dynamics in ML](https://hal.inria.fr/hal-01499984/document)
* [Correctness of Compiling Polymorphism to Dynamic Typing](https://pdfs.semanticscholar.org/b95a/31c1616984dc74b2a4bbe737b1666c5ac37e.pdf)
* https://gitlab.com/metastatedev/tezos/-/issues/92

## Copyright

Copyright and related rights waived via
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).

# Tezos Interoperability Proposals (TZIPs)

TZIP (pronounce "tee-zip") stands for Tezos Interoperability Proposal, which are
documents that explain how the Tezos blockchain can be improved with new and
updated standards and concepts, such as smart contract specifications.

## What is a TZIP?

A TZIP is a design document providing information to the Tezos community,
describing a feature for Tezos or its processes or environment, and supporting
the formal protocol governance process. A TZIP should contain a concise
technical specification and rationale which unambiguously articulates what the
proposal is, how it may be implemented, and why the proposal is an improvement.

A TZIP should additionally contain an FAQ which documents, compares, and answers
alternative options, opinions, and objections.

## Current TZIPs

|    TZIP   | Title                                                | Creation Date | Status           |
| :-------: | :--------------------------------------------------- | :-----------: | :--------------- |
| [TZIP-1]  | TZIP Purpose and Guidelines                          |  2019-04-10   | Final            |
| [TZIP-2]  | TZIP Types and Naming                                |  2019-04-10   | Final            |
| [TZIP-3]  | TZIP Code of Conduct                                 |  2019-04-10   | Final            |
| [TZIP-4]  | `A1` - Michelson Contract Interfaces and Conventions |  2019-04-11   | Deprecated       |
| [TZIP-5]  | `FA1` - Abstract Ledger                              |  2019-04-12   | Deprecated       |
| [TZIP-6]  | `A1.1` - Balanced Trees for nested or and pair types |  2019-05-04   | Deprecated       |
| [TZIP-7]  | `FA1.2` - Approvable Ledger                          |  2019-06-20   | Final            |
| [TZIP-8]  | Payment Request Format                               |  2019-06-25   | Work In Progress |
| [TZIP-9]  | Info Field for Payment Requests                      |  2019-06-25   | Work In Progress |
| [TZIP-10] | `LA1` - Wallet Interaction Standard                  |  2019-09-17   | Draft            |
| [TZIP-11] | Contract Specification Schema                        |  2020-01-10   | Work In Progress |
| [TZIP-12] | `FA2` - Multi-Asset Interface                        |  2020-01-24   | Draft            |
| [TZIP-13] | `FA1.3` - Fungible Asset Standard                    |  2020-01-02   | Work In Progress |
| [TZIP-14] | GraphQL interface to Tezos node data                 |  2020-04-01   | Draft            |
| [TZIP-15] | Token Transferlist Interface                         |  2020-05-14   | Draft            |
| [TZIP-16] | Contract Metadata                                    |  2020-06-30   | Work In Progress |
| [TZIP-17] | Contract Permit Interface                            |  2020-08-11   | Work In Progress |
| [TZIP-18] | Upgradeable Contracts                                |  2020-08-17   | Work In Progress |
| [TZIP-19] | Tezos Decentralized Identifier (DID) Manager         |  2020-09-16   | Work In Progress |
| [TZIP-20] | Off-chain Events                                     |  2020-10-07   | Work In Progress |
| [TZIP-21] | FA2 Multimedia Metadata                       |  2020-11-12   | Work In Progress |

## How to Contribute

If you want to contribute a proposal, please review the TZIP structure in
[TZIP-1]. You may find TZIP templates in the [templates](/templates) folder
helpful.

Create a new subfolder in [proposals](/proposals) named for your TZIP, and
include the proposal, FAQ, and any assets (e.g. contract implementation) in that
subfolder. TZIPs and FAQs should be written in
[Markdown](https://docs.gitlab.com/ee/user/markdown.html) format.

Once you have written your proposal, please open a merge request with your
proposal for review. Please remember to update the *Current TZIPs* table above
in your merge request. The exact TZIP workflow is explained in [TZIP-1].

[TZIP-1]: proposals/tzip-1/tzip-1.md
[TZIP-2]: proposals/tzip-2/tzip-2.md
[TZIP-3]: proposals/tzip-3/tzip-3.md
[TZIP-4]: proposals/tzip-4/tzip-4.md
[TZIP-5]: proposals/tzip-5/tzip-5.md
[TZIP-6]: proposals/tzip-6/tzip-6.md
[TZIP-7]: proposals/tzip-7/tzip-7.md
[TZIP-8]: proposals/tzip-8/tzip-8.md
[TZIP-9]: proposals/tzip-9/tzip-9.md
[TZIP-10]: proposals/tzip-10/tzip-10.md
[TZIP-11]: proposals/tzip-11/tzip-11.md
[TZIP-12]: proposals/tzip-12/tzip-12.md
[TZIP-13]: proposals/tzip-13/tzip-13.md
[TZIP-14]: proposals/tzip-14/tzip-14.md
[TZIP-15]: proposals/tzip-15/tzip-15.md
[TZIP-16]: proposals/tzip-16/tzip-16.md
[TZIP-17]: proposals/tzip-17/tzip-17.md
[TZIP-18]: proposals/tzip-18/tzip-18.md
[TZIP-19]: proposals/tzip-19/tzip-19.md
[TZIP-20]: proposals/tzip-20/tzip-20.md
[TZIP-21]: proposals/tzip-21/tzip-21.md

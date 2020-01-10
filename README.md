# Tezos Improvement Proposals (TZIPs)

TZIP (pronounce "tee-zip") stands for Tezos Improvement Proposal, which are documents that explain how the Tezos blockchain works or how it ought to work.

## What is a TZIP?

A TZIP is a design document providing information to the Tezos community, describing a feature for Tezos or its processes or environment, and supporting the formal protocol governance process. A TZIP should contain a concise technical specification and rationale which unambiguously articulates what the proposal is, how it may be implemented, and why the proposal is an improvement.

A TZIP should additionally contain an FAQ which documents, compares, and answers alternative options, opinions, and objections.

## Current TZIPs

|    TZIP   | Title                                                      | Creation Date | Status             |
| :-------: | :--------------------------------------------------------- | :-----------: | :----------------- |
| [TZIP-1]  | TZIP Purpose and Guidelines                                |  04/10/2019   | Final              |
| [TZIP-2]  | TZIP Types and Naming                                      |  04/10/2019   | Final              |
| [TZIP-3]  | TZIP Code of Conduct                                       |  04/10/2019   | Final              |
| [TZIP-4]  | **A1** - Michelson Contract Interfaces and Conventions     |  04/11/2019   | Submitted          |
| [TZIP-5]  | **FA1** - Abstract Ledger                                  |  04/12/2019   | Submitted          |
| [TZIP-6]  | **A1.1** - Balanced Trees for nested or and pair types     |  05/04/2019   | Submitted          |
| [TZIP-7]  | **FA1.2** - Approvable Ledger                              |  06/20/2019   | Submitted          |
| [TZIP-8]  | Payment Request Format                                     |  06/25/2019   | Draft              |
| [TZIP-9]  | Info Field for Payment Requests                            |  06/25/2019   | Draft              |
| [TZIP-10] | **LA1** - Wallet Interaction Standard                      |  09/17/2019   | Work In Progress   |
| [TZIP-11] | Contract Specification Schema                              |       -       | Draft              |
| [TZIP-12] | **FA2** - Multi-Asset Contract (MAC)                       |       -       | Draft              |
| [TZIP-13] | **FA1.3** - Fungible Asset Standard                        |  01/02/2020   | Work In Progress   |

## How to Contribute

If you want to contribute a proposal, please review the TZIP structure in [TZIP-1](/proposals/tzip-1/tzip-1.md). You may find TZIP templates in the [templates](/templates) folder helpful.

Create a new subfolder in [proposals](/proposals) named for your TZIP, and include the proposal, FAQ, and any assets (e.g. contracts) in that subfolder. Note that TZIPs and FAQs should be written in [Markdown](https://docs.gitlab.com/ee/user/markdown.html) format.

Once you have written your proposal, please open a merge request with your proposal for review. Please remember to update the *Current TZIPs* table (see above) in your merge request.

[TZIP-1]: proposals/tzip-1
[TZIP-2]: proposals/tzip-2
[TZIP-3]: proposals/tzip-3
[TZIP-4]: proposals/tzip-4
[TZIP-5]: proposals/tzip-5
[TZIP-6]: proposals/tzip-6
[TZIP-7]: proposals/tzip-7
[TZIP-8]: proposals/tzip-8
[TZIP-9]: proposals/tzip-9
[TZIP-10]: proposals/tzip-10
[TZIP-11]: proposals/tzip-11
[TZIP-12]: proposals/tzip-12
[TZIP-13]: proposals/tzip-13

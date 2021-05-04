## TZIP drafts

In order to better improve the feedback process around
TZIP creation, proposals will now start as documents
called "TZIP drafts" before they become numbered [TZIPs](https://gitlab.com/tzip/tzip)
upon acceptance.

The template for a TZIP draft can be found [here](../templates/tzip-template.md).

## Draft Naming

A draft should have a filename of the form:

draft-_name_.md

where _name_ is the name of the draft. Names should be
unique and reasonably descriptive of the draft's topic.
Names may incorporate hyphens but should not include
underscores or spaces.

## Draft Versions

The version number of the draft, which is included
in the document itself, should be incremented
if the changes being made mean that reviewers
should re-read the document. The date of the draft
should always be incremented if changes are made. See
the draft template for details.

## Updated Process

- A TZIP draft is written in order to propose a new change
or standard related to protocol or shell changes, new protocol or shell features,
interoperability, etc.
- The draft is submitted as a merge request in Gitlab by the
author. The commenting period begins after it is merged.
- The author should open a thread on [Tezos Agora](https://forum.tezosagora.org/), linking to the TZIP, for the community to provide feedback.
- New versions of the draft (with updated version numbers) may
be submitted to incorporate feedback.
- If accepted, the TZIP will be granted a number and included
in the main TZIP directory, list, and [explorer](https://tzip.tezosagora.org/).
- If not accepted or updated within 6 months, the TZIP draft
will expire and be archived in another directory.

## Feedback

Any feedback on the TZIP drafts process should be expressed
on Gitlab, or [Tezos Agora](https://forum.tezosagora.org/).
We welcome any comments, questions, or concerns in order to
have a process incorporating best practices for proposing
and communicating ideas to improve Tezos.

---
title: "Concierge and chat-first"
description: "Why chat is the default entry to flow, how routing stays grounded in mechanical state, and why permission is default-deny."
---

Most operators should never need to learn a verb. Chat is the default front door: you say
what you want, and the concierge routes it. Typed verbs still exist and always win.

## Why a chat front door at all

A harness with twenty-something verbs has a cliff at the start. The person who most needs
gating discipline — someone building their first real product — is exactly the person least
likely to read a command table first. Every verb they must learn before getting value is a
place to give up.

But a chat front door is only worth having if it does not become a second, softer source of
truth. That is the design problem the concierge actually solves.

## Routing is grounded, not guessed

The loop starts with a command, not with an interpretation. On any natural-language ask, the
concierge runs the status command — or `resume` when entering a project cold — and reads the
result. It never infers your state from the conversation, and it never infers it from which
files happen to exist.

This matters because the alternative, fuzzy artefact detection, gets it wrong in the exact
situations where being wrong is worst: a half-finished stage, an abandoned session, a card
someone edited by hand. `flow` already has a mechanical state machine that knows the answer.
The concierge asks it.

From that state it looks up the closest intent-class row in a routing table and proposes
exactly **one** next action, in plain language, explaining any gate concept in a sentence the
first time it appears. One proposal at a time is a deliberate constraint: dumping the verb
list on someone who asked a simple question is how you lose them.

## Permission is default-deny

The concierge classifies every verb before it runs anything. Strictly read-only commands —
status, resume, recall, usage, the drift checks, doctor, ready — run without asking, because
requiring consent to look at something is pure friction. Everything that mutates state, costs
money, or belongs to the operator's authority must be confirmed first.

The rule is default-deny: any verb not on the read-only list is must-ask, **including verbs
added to flow after the routing file was written**. That clause is the interesting one. It
means the safe behaviour is the one you get by default when the system grows, rather than the
one you get by remembering to update a list.

`next` sits on the must-ask side even though it looks like a read of an already-passed gate.
Its pass condition — the mechanical layer and the semantic challenge both agreeing — cannot
be known before it runs, because the semantic challenge is only applied after a mechanical
pass. Auto-running it would let the concierge silently push a hollow-but-mechanically-clean
stage past the operator. That is precisely the failure the gates exist to prevent, so the
front door is not allowed to reintroduce it.

## One consent question, not a settings page

A brand-new user whose ask requires drafting gets a single question: shall I draft the steps
and you review each one? Yes switches to `work` mode; no stays in `teach`. Nothing else about
the gates changes — both modes pass identical gates, and the only difference is authorship.

One question is the whole onboarding ceremony. The alternative, asking the user to understand
teach versus work before they have seen a gate, explains a distinction that has no meaning to
them yet.

## Typed verbs are untouched

An explicit `/flow next` dispatches exactly as the command table describes, with zero
concierge interpretation. There is no mode to disable, nothing to configure, and no
divergence between what chat does and what the verb does — chat *is* the verb, chosen for you.

## The honest limitation

Routing parses human-readable status prose rather than a machine token contract. It is
reliable on Claude and best-effort on other engines. The mechanical layer behaves identically
everywhere, so the fallback when routing feels wrong is always available and always exact:
type the verb.

## See also

- [Use the chat concierge](/docs/how-to/use-chat-concierge)
- [Modes and run strategies](/docs/explanation/modes-and-run-strategies)
- [Command reference](/docs/reference/commands)

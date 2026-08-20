---
title: "Use the chat concierge"
description: "Drive flow in plain language: what the concierge runs without asking, what it must confirm, and how to bypass it."
---

You do not have to learn any verbs. Chat is the default front door: say what you want, and
the concierge works out where you are and proposes one next step.

## Just say what you want

Open your agent in the project directory and type a normal sentence:

> "I want to build an inventory app for my shop."

> "Where am I?"

> "Is this card done?"

The concierge answers in the language you used. Reply in Vietnamese and you get Vietnamese
back; flow's own law and reference files stay English-canonical either way.

## What it does before answering

Every natural-language ask goes through the same short loop, and step one is not negotiable:

1. It runs the status command — or `resume` if you are entering a project cold — to get
   **mechanical ground truth**. It never guesses your state from the conversation.
2. It matches your intent against a routing table of intent-class and state.
3. It proposes exactly **one** next action, in plain language, explaining any gate concept in
   a sentence the first time it appears.
4. It offers to run that action, following the permission rules below.

One proposal at a time is deliberate. You will not get the full verb list dumped on you
because you asked a simple question.

## What it may run without asking

Read-only commands that cannot mutate state are run directly, because asking permission to
look at something is just friction:

`status`, `resume`, `recall`, `usage`, `coherence`, `consistency`, `contract`, `tokens`,
`constitution`, `clarify`, `design`, `doctor`, `ready`, `gate`.

## What it must ask you first

Anything that mutates state, costs money, or belongs to you as the operator is confirmed
before it runs:

`next`, `assess`, `card`, `check`, `project-type`, `skip`, `debt`, `harness`, `promote`,
`mode`, `auto`, `attest`, `workspace`, `unlock`, `retro`, `eval`, `converge`.

The rule is **default-deny**: any verb not on the read-only list above is must-ask, including
verbs added to flow after the routing file was written.

`next` is on the must-ask list even though it looks like it only advances a gate that already
passed. Its pass condition — mechanical layer *and* semantic challenge both agreeing —
cannot be known before it runs. Auto-running it would let the concierge quietly push a
hollow-but-mechanically-clean stage past you, which is the exact failure the gates exist to
prevent.

## Teach and work {#teach-and-work}

If you are new and your ask requires the agent to draft artifacts for you — "build me X" —
the concierge asks a single plain question before touching your mode:

> "Want me to draft the steps and you review each one?"

Answer yes and it switches you to `work` mode: the agent interviews you once, drafts stages
00 to 05 itself, pauses only for the scope sign-off, and delivers the card set as one
summary. Answer no and you stay in `teach` mode, the default: you write every planning
artifact and the agent only gate-keeps, catching hollow or fabricated content. It is
forbidden from checking a box or drafting on your behalf.

The gates and done-rules are identical either way. `work` changes authorship, never the bar.
The choice is stored in a `MODE` file. You can change your mind later with `/flow mode teach`
or `/flow mode work`.

## Bypassing the concierge

Type the verb. An explicit `/flow next`, `/flow card`, `/flow check C-001` is dispatched
exactly as written, with zero concierge interpretation. Typed verbs always win over chat
routing — power users lose nothing by the chat default.

## A worked first run

1. You open a fresh agent in an empty directory and say *"tôi muốn build app quản lý kho"*.
2. The concierge runs status, sees no `flow/` directory, and answers: there is no flow
   project here yet — shall I ask one short question and then draft each step for you to
   review?
3. You say yes. It switches to `work` mode and starts the interview toward the Scope gate.

Zero flow verbs typed. The consent question was the only ceremony.

## Why chat is the front door {#why-chat-first}

A harness with twenty-something verbs has a cliff at the start. The person who most needs
gating discipline — someone building their first real product — is exactly the person least
likely to read a command table first. Every verb they must learn before getting value is a
place to give up.

A chat front door is only worth having if it does not become a second, softer source of
truth. That is why the loop above starts with a command, not an interpretation, and why
permission is default-deny.

## A caveat worth knowing

Routing parses human-readable status prose, not a machine token contract. It is reliable on
Claude; on other engines such as Codex or Antigravity, treat chat routing as best-effort. If
routing ever feels wrong, type the verb — the mechanical layer behaves identically on every
engine.

## See also

- [Walk a full project](/docs/tutorials/first-greenfield-project)
- [Command reference](/docs/reference/commands)

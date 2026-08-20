---
title: "Agent orchestration"
description: "Stages delegate to specialist agents when they exist and degrade to built-in behaviour when they do not — the gate never moves."
---

Each stage can delegate its drafting to a specialist agent, and falls back to built-in
behaviour when none is installed, which is what keeps `flow` portable rather than dependent on
somebody else's agent registry. The priority ladder is specialist agents first, then
equivalent skills, then the built-in fallback. The stage map is roughly what you would expect:
research to a researcher, scope and PRD to a planner, ADR to an architect, contract to a
spec-oriented kernel, build to a full-stack developer, review to a code reviewer or a
three-layer adversarial review, live verification to a tester.

The rule that makes this safe is one sentence: **agents are pluggable, gates are fixed.** The
gate is identical on every path, so a missing agent can never lower a bar and a fancy agent
can never raise a pass it did not earn. Delegation is also context-isolated by design — a
subagent gets only its task, its files, its acceptance criteria, and the relevant law or
contract excerpts, never the session history — and it returns one of a small set of verdicts:
`DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`, `NEEDS_CONTEXT`. After any delegation the gate runs,
the semantic challenge is applied, the durable hook is written, and which path actually ran
is announced.

This page is the operator home for the power surface around that rule: one worktree per
agent, optional extra engines, the recall/promote loop, and fingerprint-bound receipts.
Maintainer diagrams stay in the repo; they are linked only in the footer.

## Multi-agent workspace {#multi-agent-workspace}

Several agents in several terminals on one checkout is the trap: one of them switches
branch, and every other terminal flips with it. `/flow workspace` gives each agent its own
`git worktree` — own HEAD, own index, own files, shared object store — so that does not
happen.

```
/flow workspace add <branch>
/flow workspace add <branch> --card C-NNN --vendor <name> --task "<one line>" --copy-env
/flow workspace list
/flow workspace enter <branch>
/flow workspace check <branch> --card C-NNN
/flow workspace remove <branch>
/flow workspace doctor
```

- `add <branch>` creates the tree with a distinct port offset (so two local servers do not
  collide) and prints a paste-ready `cd` and env block. Optional flags pin a card, a vendor
  label, a task line, and whether to copy env into the new tree.
- `list` shows who is where.
- `enter <branch>` reprints the environment for a crashed terminal.
- `check <branch> --card` flags a branch-claim clash and allowed-files overlap *before* you
  launch. Run it. A later merge conflict means that check was skipped or gamed.
- `remove` tears the tree down and never auto-forces. If git refuses, you resolve it; `flow`
  will not `--force` for you.
- `doctor` reconciles orphaned trees and records.

git itself is the registry and the real lock. `git worktree list` is live; git's refusal to
check out one branch twice is what actually protects you. The side-file
`.flow/workspaces.jsonl` only adds vendor, card, port, and task metadata on top.

Use these verbs so the journal has no hole. A raw `git worktree add` records nothing.

## Second engine {#second-engine}

OpenAI Codex (the `openai-codex` plugin) is an optional second engine. Google Antigravity
(the `agy` CLI or the Antigravity IDE) is an optional third. Both are extra vendors used at
the same high-value moments so a review can be judged by models that rarely share a blind
spot. Neither replaces the specialist → skill → built-in ladder. The default engine stays
that ladder. Absence of Codex or Antigravity never breaks a run.

`flow` distinguishes *installed* from *usable*. Installed means the plugin, binary, or IDE
directory is present. Usable additionally requires a cheap non-billable probe that the
engine is actually ready and logged in. Only a usable engine is routed to. Otherwise `flow`
degrades silently-but-announced to the normal ladder, and the gate does not move.

Antigravity gets the strictest probe of the two, for a measured reason: `agy -p` returns
exit code 0 with empty stdout even when you are not logged in — the error lands only in the
log file. So `flow` routes to Antigravity only on non-empty expected output, never on the
exit code, which lies. Headless capture is unreliable on that platform, so the supported
default is interactive: run the review in the IDE Agent Manager or a real terminal and paste
the result back. An empty Gemini result means "review unavailable" and is never an approval.

Because these calls are billable and because the diff plus contract or PRD excerpts leave
the machine, exactly three triggers open the cost gate:

1. A two-strikes deadlock — a same-model agent blocked twice. Antigravity is the later
   extra engine: it fires here after Codex if both the same-model path and the second
   engine stall.
2. A security-class card review.
3. An explicit operator opt-in ("review this on Codex", "review this on Antigravity",
   `/flow … codex`, `/flow … antigravity`).

Never on every stage by default. For a sensitive, regulated, or NDA'd codebase, opt in
knowingly: selecting Codex sends that brief to OpenAI under your plan's retention terms;
selecting Antigravity sends it to Google under your Gemini plan. Authentication is
delegated entirely to the plugin or to `agy` / the IDE. `flow` never reads, stores, or logs
those credentials.

Gate parity is absolute. Codex or Antigravity drafts or critiques; the identical stage gate
still judges. A cross-model review informs triage. It never auto-passes and never
auto-fails a card.

After a use, `flow` announces which engine ran (or that the tier was unavailable and what
it degraded to). A run stays legible.

## Knowledge loop {#knowledge-loop}

A conversation window forgets. The durable harness — a SQLite store plus `RETRO.md`,
`DEBT.md`, and `playbooks/` — is a closed capture, reuse, improve loop, so an agent-driven
project accumulates experience the way a human team does.

Capture is engine-fired rather than voluntary:

- advancing past stage 01 seeds an intake
- a passing card check records a tier-scored trace
- a deliberate skip logs its debt

Reuse is `/flow recall`. Run it at the start of a stage or a card, before you author
anything. It reads back open debt, the most recent retro, the previous card's scope,
harness friction and backlog, audit health, and any promoted playbooks, so the work begins
with prior pain in view instead of rediscovering it.

Improvement is mechanical too: `harness audit` scores entropy and drift, `harness propose`
mines repeated friction into an improvement backlog once a pattern fires at least twice,
and `harness decision outcome` closes the predicted-versus-actual loop.

The mid-project ritual that starts with `resume` then `recall` lives on
[Resume mid-project](/docs/how-to/resume-mid-project/#recall-and-promote).

### Promote {#promote}

When a lesson is bigger than one project, lift it:

```
/flow promote <playbook.md>
```

That copies the playbook into the cross-project knowledge base at `~/.claude/flow/playbooks`.
From then on, `recall` surfaces it everywhere rather than only where it was learned.

## Attested execution {#attested-execution}

Once a run is autonomous, "this was reviewed" has to mean something a script can check. The
attested-execution control plane issues fingerprint-bound receipts — a `semantic_gate`
receipt for a reviewed stage or card, a `live_verify` receipt for a checked deployment —
bound to fingerprints of the thing they approved.

```
/flow attest semantic --stage <stage> --revision <rev> --owner <manifest>
/flow attest semantic --card <id> --base <rev> --revision <rev> --owner <manifest>
/flow attest live-verify <id> --revision <rev> --owner <manifest>
/flow attest status [<stage|card>]
/flow attest recover <C-NNN> --mark-failed
```

Minting executes against committed blobs at a specific revision, not whatever is dirty in
the working tree. A live receipt requires the exact HEAD tip plus recomputed fingerprints,
so editing a file after approval invalidates the approval instead of silently inheriting
it. `status` tells you whether a receipt is current. `recover … --mark-failed` is the
Must-ask escape when a live verify is stuck mid-flight; it marks that attempt failed, it
does not mint a pass.

While `/flow auto` is active, `check`, the CLI-owned card flip, dependency readiness, and
removing a merged worktree all require current receipts. `/flow auto stop` returns you to
warning-only manual mode. There is no hidden bypass. Auto halt rules — including
security-class HALT — live on [When work must halt](/docs/explanation/auto-tiers-and-security-halts/).

Receipts detect **subject staleness**. They do not authenticate actors and they do not
resist a hostile host. They are a guard against an autonomous loop consuming its own
out-of-date approval, not a security boundary against someone with control of the machine.

---

Maintainer homes (not the public page): [`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md), [`skills/flow/references/codex-integration.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/codex-integration.md), [`skills/flow/references/antigravity-integration.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/antigravity-integration.md), [`skills/flow/references/attestations.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/attestations.md). Diagrams maintainers need: [`docs/system-architecture.md`](https://github.com/manhquydev/flow-skill/blob/master/docs/system-architecture.md).

# Concierge — conversational entry to /flow

Routing / offer-run pattern adapted from BMAD-METHOD's `bmad-help` skill
(MIT License, Copyright (c) 2025 BMad Code, LLC — see `BMAD-METHOD/LICENSE`), reworked
here on flow's own mechanical state machine (`flow.sh status`/`resume`) instead of
fuzzy artifact detection. This is the **default** entry contract: any natural-language
ask routes through this loop before you consider typing a verb for the operator.

## Entry loop

1. On any natural-language ask, run `flow.sh status` first (or `resume` when entering a
   project cold mid-cycle — see SKILL.md dispatch rule 1). **Never guess state.**
   `status`/`resume` output is human-readable prose, not a machine token contract — you
   (the model) parse it. Reliable on Claude; treat routing on other engines (Codex,
   Antigravity/Gemini) as best-effort, not guaranteed.
2. Look up the closest `intent-class` row in `flow-catalog.tsv` for the parsed state.
3. Propose exactly **ONE** next action in plain language. Explain any gate concept in
   one short sentence the first time it comes up (zero-jargon default — assume the user
   has never read a flow doc).
4. Offer to run it now, using the May-run / Must-ask classification below. A typed verb
   from the operator always wins — never intercept or reinterpret an explicit
   `/flow <verb>` command; dispatch it exactly as SKILL.md's Commands table says.

## New-user consent (teach-mode boundary)

Default mode is `teach`: you must never author artifacts on the operator's behalf (see
SKILL.md's Forbidden list). When a brand-new user's ask requires you to draft something
(e.g. "build me X"), ask exactly **one** plain consent question before touching `mode`:

> "Muốn tôi soạn nháp từng bước và anh duyệt không?" / "Want me to draft the steps and
> you review each one?"

- Yes → run `mode work` (a must-ask action — confirm, then run it).
- No → stay in `teach`, guide the operator through authoring it themselves.

## May-run vs must-ask (default-deny)

**May-run — no confirmation needed** (strictly read-only, no state mutation):
- status
- resume
- recall
- usage
- coherence
- consistency
- contract
- tokens
- constitution
- design
- doctor
- ready

**Must-ask — confirm before running** (mutates state, costs money, or is
operator-authority-only):
- next
- assess
- card
- check
- project-type
- skip
- debt
- harness
- promote
- mode
- auto
- workspace
- unlock
- retro
- eval

**Default-deny:** any verb not explicitly listed under May-run above is must-ask — this
includes any verb added to flow after this file was written. When in doubt, ask.

`next` is must-ask even though it "just advances a passed gate": its pass condition
("both the mechanical layer AND the semantic challenge agree") cannot be verified before
it runs — the mechanical layer only reports PASS/FAIL when `next` actually executes, and
the semantic challenge is applied only AFTER a mechanical pass (see SKILL.md dispatch
rule 3 and `command-dispatch.md`). Auto-running it would let the concierge silently push
a hollow-but-mechanically-clean stage past the operator — the exact failure mode the
gate discipline exists to prevent.

## Tone rules

- Zero-jargon default: assume the user has never read a flow doc.
- Reply in the user's language (Vietnamese or English); flow's law/reference files stay
  English-canonical regardless.
- One proposal at a time — never dump the full verb list on someone who just wants to
  chat.
- Power-user verbs pass through untouched: a typed `/flow next` dispatches exactly as
  SKILL.md's Commands table describes, with zero concierge interpretation.

## First-run script (new-user acceptance path)

1. User: "tôi muốn build app quản lý kho" (or any build ask), no prior `flow/` dir.
2. Concierge: runs `status` → sees no `flow/` dir → proposes: "Chưa có dự án flow nào ở
   đây. Tôi bắt đầu bằng một câu hỏi ngắn rồi soạn nháp từng bước, anh duyệt được
   không?"
3. User: yes → concierge runs `mode work` (must-ask, now confirmed) → proceeds through
   the mode-work interview script (`references/mode-work.md`) toward the Scope gate.
4. Zero flow verbs typed by the user up to this point — the consent question was the
   only exchange required.

## Example routing (spot-check, VN+EN)

| Utterance | intent-class | action |
|---|---|---|
| "tôi muốn build X" / "I want to build X" | start-new-project | mode (consent→work) |
| "giờ tới đâu rồi?" / "where am I?" | resume-where-am-i | resume |
| "giờ làm gì tiếp theo?" / "what should I do now?" | what-next | status |
| "card này xong chưa?" / "is this card done?" | check-card-done | check |
| "làm retro đi" / "let's do a retro" | retro-ask | retro |

See `flow-catalog.tsv` for the full routing table (source of truth for automated
checks — `tests/test_flow_concierge.sh`).

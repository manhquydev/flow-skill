# Design review checklist (UI cards)

Every mock/frontend card is reviewed against `law/DESIGN.md` the same way backend cards are
reviewed against the contract. Two parts: a **mechanical** part (`flow.sh design <file>`,
grep-able, deterministic) and a **semantic** part (you, against DESIGN.md's structure laws).

## Mechanical (run `flow.sh design <htmlfile>` — catches the never-do list)
Flags, with line numbers:
- **Emoji** anywhere (DESIGN.md: "No emojis. Anywhere. Ever.").
- **Raw `{{ }}` templates or visible JSON** outside a power surface.
- **Gradients on inputs / table rows / body bg** (gradients are hero-surface only).
- **Engine words** in user-facing copy: workflow, trigger, queue, webhook, agent, prompt,
  cron, payload, endpoint (users think in THEIR objects, not engine concepts).
- **Design comments left in HTML.**
A flag is a strong signal, not always a verdict (an engine word inside a `<code>` sample is
fine) — you confirm. Exit 1 if any flag fires.

## Semantic (you review against DESIGN.md — the script can't judge these)
- **Object-first:** the home page of a thing IS the thing; tabs are lenses on one object,
  not separate features.
- **WYSIWYG / edit-in-place:** 80% of edits inline on the object page; a separate edit page
  only for structural 20%. No multi-step wizard for editing.
- **Defaults beat configuration:** creatable in <=6 visible fields; the rest behind "More options".
- **Plain language:** "4 days after it ends", a field-picker chip — never cron, never raw templates.
- **Power behind a door:** any power surface is a `Simple | Pro` toggle that loses no data,
  with a visible path back to simple.
- **Affordance ladder:** the field uses the lightest rung its shape allows (inline text ->
  inline control -> popover composite -> modal). Empty value renders as `+ Add {label}`.
- **Luma object page:** calm pulse strip (no stat-tile cards), <=3 gradient-tinted hero
  action cards (one click, no kebab), tabs as lenses, modal-first sub-actions.
- **Tokens:** Editorial Minimal tokens (or a deliberate, documented, whole-cluster override).
  Inter body / Fraunces only for h1+titles+prominent stats / JetBrains Mono only for
  IDs/dates/counts. 1px borders, no stacked shadows.
- **VN conventions:** Vietnamese native copy, `₫750,000` (symbol leading, comma groups),
  VietQR as default pay, Zalo as a first-class support channel.

## Process
1. The UI **mock card** (static HTML, real copy, no logic) IS the design review — render it,
   operator approves in a browser. Iterate here (mock retries cost seconds; framework retries
   cost deploys). No frontend code before the mock is approved.
2. Run `flow.sh design <file>` (mechanical) + this semantic pass on the mock and on every
   frontend card. A violation blocks the card the same as a failing `## Verify`.

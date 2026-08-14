# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Astro 5 + Starlight, static `dist`, Cloudflare Pages. Locked in the accepted website plan (`plans/260813-1706-flow-website-docs-en-vi-cloudflare-pages/plan.md`). Not delegated.

## Users

Primary: a developer or operator who has **not installed flow yet**. They are in an AI coding session (Claude Code, Codex, Cursor, or Antigravity), about to start a real product, and they need to understand what `/flow` is in about ten seconds and then install.

Secondary (docs, Read mode): the same person after install, looking up a command, gate, or concept. Docs are not the landing’s job.

## Product Purpose

Flow is a **gated build harness for coding agents**. It walks an idea to real done-evidence (deployed URL, CLI that runs, library API, or a real skill run) through honest gates. Success for this site: the visitor installs via `npx @manhquy/flow-skill@latest` and opens the docs start tutorial.

## Positioning

Not an AI coding agent. A **two-layer harness**: mechanical runner (`flow.sh`, exit 0/1) plus semantic skill (the model). Both must agree. Kill at a gate is a valid outcome. Chat is the default front door; typed `/flow` verbs still win.

A neighboring “AI coding agent” landing cannot truthfully copy this: they sell a model in a terminal; flow sells **discipline with a kill switch**.

## Operating Context

Used inside agent homes (`~/.claude/skills/flow`, Codex, Cursor, Antigravity). Artifacts live in the operator’s project: `flow/*.md`, `cards/`. Commands: `/flow`, `/flow next`, `/flow card`, `/flow check`. Windows uses `flow.cmd` / Git Bash.

This marketing site is **separate** from the skill. Repo-root `DESIGN.md` is flow’s **card UI law** for products built *with* `/flow` — anti-reference for this site. Impeccable files for the site live only under `website/`.

## Capabilities and Constraints

- Public: Persuade landing (`/`, `/vi/`) + Diátaxis docs (`/docs`, `/vi/docs`). EN root, VI prefixed.
- Install truth: `npx @manhquy/flow-skill@latest`. Versions: read live from `skills/flow/SKILL.md` and `npm-wrapper/package.json` at build time — never freeze digits in this file.
- EN and VI are equal in content; URL symmetry is not required.
- Must not change `skills/flow/runner/flow.sh` or overwrite repo-root `DESIGN.md`.

Undecided: custom domain (later). Production Pages URL after merge to `master`.

## Brand Commitments

- Name: **flow** (command `/flow`).
- Voice: plain, operator-facing, no hype, no “10x productivity.”
- Binding anti-look (operator, 2026-08-13): must not look like an AI coding-agent landing (neon, terminal hero, star-count flex) **and** must not look docs-only with no product to install.
- Visual world: **Galley Proof** (letterpress galley + publisher pass sheet). Operator kept the roll 2026-08-13. Composition: Comp A two-column proof (operator delegated). Seed key `8bb4fc2d`. Skill path: `~/.cursor/skills/impeccable`. Do not copy OpenCode, impeccable.style, or BMAD as the system. Those remain IA/craft references only.
- Locale: English unprefixed; Vietnamese at `/vi/`.

## Evidence on Hand

Allowed on the landing (operator lock): install command, two-layer mechanism, stage pipeline. **No metrics, star counts, testimonials, or “used by N.”**

Real sources to rewrite (not dump): `README.md`, `README_VN.md`, `skills/flow/SKILL.md`. GitHub: `https://github.com/manhquydev/flow-skill`. npm: `@manhquy/flow-skill`.

Absence: no product photography, no logo lockup beyond the word “flow”, no customer quotes.

## Product Principles

1. **Done is world-state**, not “tests pass.”
2. **Both layers or it didn’t pass** — script and judgment.
3. **Kill is valid** — a weak idea stopped at Scope is success.
4. **Chat first, verbs win** — concierge routes; explicit `/flow` is never intercepted.
5. **Do not fabricate proof** — if it isn’t in the repo, it isn’t on the site.

## Accessibility & Inclusion

Public docs + marketing: real `h1`, `lang` on `html` (`en` / `vi`), keyboard-reachable install copy, no information in color alone. No WCAG level was contracted; meet a sensible public-site floor (contrast, focus, reduced-motion).

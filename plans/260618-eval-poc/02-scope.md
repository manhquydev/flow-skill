# Scope — NoteNest (team docs SaaS)

Project type: web. Pitch: a lightweight shared-docs workspace for small teams who find
Notion too heavy. v1 must ship in 4 weeks with 2 engineers.

## Feature grading

Build difficulty: **A** = easy (hours), **B** = medium (a few days, mostly wiring a library),
**C** = hard (a week+, custom infra / distributed-systems risk).
Impact on selling v1: **H / M / L**.

| # | Feature | Impact | Grade | Justification |
|---|---------|--------|-------|---------------|
| F1 | Email + password login (sessions) | H | B | Standard auth via a library (Better Auth); a few days of wiring. |
| F2 | Document create / edit / delete (rich text) | H | A | CRUD on a documents table + a TipTap editor; well-trodden. |
| F3 | Live collaborative editing — real-time multi-cursor + presence sync across users | H | B | We'll drop in a realtime sync library (Yjs/Liveblocks), so it's medium wiring, not custom infra. |
| F4 | Export a document to PDF | M | B | Headless-Chrome render to PDF; a couple of days. |
| F5 | Dark mode toggle | L | A | CSS variables + a toggle. |

## Cut list (not in v1)
- Comments / mentions
- Folder hierarchy
- Mobile app

## Build order
F1 → F2 → F4 → F3 → F5

## Decision: **GO**
Five features, 4-week budget with 2 engineers. No C-grade features, so the plan fits the
budget. Proceed to PRD.

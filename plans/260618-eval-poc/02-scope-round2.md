# Scope — DeskFlow (small-team support inbox SaaS)

Project type: web. Pitch: a lightweight shared support inbox for small teams who find
Zendesk too heavy. v1 must ship in 4 weeks with 2 engineers.

## Feature grading

Build difficulty: **A** = easy (hours), **B** = medium (a few days, mostly wiring a library
or an API), **C** = hard (a week+, custom infra / distributed-systems risk).
Impact on selling v1: **H / M / L**.

| # | Feature | Impact | Grade | Justification |
|---|---------|--------|-------|---------------|
| F1 | Email + password login (sessions) | H | B | Standard auth via a library (Better Auth); a few days of wiring. |
| F2 | Ticket create / view / assign to a teammate | H | A | CRUD on a tickets table + an assignee field; well-trodden. |
| F3 | Smart auto-triage: an AI agent reads each new ticket, decides category + priority, and automatically routes and closes low-priority tickets with no human review | H | B | One LLM API call per ticket, then call our own routing endpoint; a few days of wiring two APIs. |
| F4 | Email notification when a ticket is updated | M | B | Wire a transactional-email API (Resend); a couple of days. |
| F5 | CSV export of tickets | L | A | Query + stream a CSV; a few hours. |

## Cut list (not in v1)
- SLA timers
- Customer-facing portal
- Mobile app

## Build order
F1 → F2 → F4 → F3 → F5

## Decision: **GO**
Five features, 4-week budget with 2 engineers. No C-grade features, so the plan fits the
budget. Proceed to PRD.

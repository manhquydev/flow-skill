# Phase 03 — Agent integration (ck: + bmad) + mode/auto

**Priority:** P1 · **Status:** ✅ done (2026-06-13) · **Depends:** Phase 01 + 02
**Mục tiêu:** mỗi stage buildflow orchestrate agent chuyên biệt có sẵn (ck: + bmad), detect-and-use, fallback built-in để vẫn portable. Thêm `/flow mode work` và `/flow auto`.

## Context links
- ck: agents: `claudekit-engineer/claude/agents/*` (planner, researcher, tester, code-reviewer, docs-manager, git-manager, fullstack-developer, ui-ux-designer)
- bmad skills: `BMAD-METHOD/src/*` (bmad-prd, bmad-create-architecture, bmad-spec, bmad-create-story, bmad-dev-story, bmad-code-review, bmad-check-implementation-readiness)
- Synthesis: `research/agent-stage-mapping.md`

## Key insights
- buildflow stage ≈ pha BMAD ≈ agent ck:. Tận dụng thay vì viết lại.
- BMAD "spec kernel" (5 trường) ≈ Contract stage 05 — dùng làm machine-contract chống producer/consumer drift.
- BMAD "story context exhaustive" → mỗi build card nên được hydrate context đầy đủ trước khi dev agent chạy.
- "Detect-and-use": skill portable, giàu khi có agent, không vỡ khi thiếu.

## Stage → agent mapping (đề xuất)
| Stage buildflow | Agent ck: (ưu tiên) | Skill bmad (thay thế) | Fallback built-in |
|---|---|---|---|
| 01 Research | `researcher` | `bmad-market-research`/`bmad-technical-research` | Explore + WebSearch |
| 02 Scope | `planner` | `bmad-prd` (scope) | Claude inline |
| 03 PRD | `planner` | `bmad-prd` / `bmad-product-brief` | Claude inline |
| 04 ADR | `architect`/`planner` | `bmad-create-architecture` | Claude inline |
| 05 Contract | — | `bmad-spec` (kernel) | Claude inline |
| Cards/Build | `fullstack-developer` | `bmad-dev-story`/`bmad-quick-dev` | Claude inline |
| Review | `code-reviewer` | `bmad-code-review` (3-layer adversarial) | Claude inline |
| Deploy | `deploy` skill | — | hướng dẫn manual |
| Verify-live | `tester`/`web-testing` | `bmad-qa-generate-e2e-tests` | curl/playwright |

## Requirements
**Functional**
- Detect registry: skill kiểm tra agent/skill nào tồn tại (đọc `.claude/agents`, `.claude/skills`, plugin marketplace) → chọn ưu tiên ck: → bmad → built-in.
- Mỗi stage: gọi agent với prompt scoped (context isolation: chỉ truyền task + file paths + acceptance, KHÔNG full history — theo orchestration-protocol.md).
- `/flow mode work`: AI phỏng vấn operator 1 lần, draft stage 00–05, pause chốt scope, giao card set.
- `/flow auto`: autonomous gated run — 1 subagent/card, planner review diff, merge card xanh (Tier-A), worktree isolation, two-strikes rule, log `AUTO-LOG.md`.
- `/flow ready`: tính card deps đủ + không overlap allowed-files → nhóm parallel-safe.

**Non-functional**
- Subagent nhận status protocol: DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT.
- Không hard-fail khi agent vắng; log fallback đã dùng.

## Architecture
```
references/
├── agent-stage-mapping.md      # bảng trên + prompt template mỗi stage
├── agent-detection.md          # cách dò ck:/bmad + thứ tự ưu tiên + fallback
├── mode-work.md                # kịch bản interview-once → draft → 1 scope pause → summary
└── auto-run.md                 # Tier-A/B/C, two-strikes, worktree, AUTO-LOG schema
```

## Implementation steps
1. Viết `agent-detection.md` + logic dò (Glob `.claude/agents/*.md`, `.claude/skills/*/SKILL.md`, plugin).
2. Viết `agent-stage-mapping.md` với prompt template scoped cho từng stage (kèm acceptance criteria, durable-record hooks).
3. Tích hợp BMAD spec kernel vào Contract stage (05) — kernel 5 trường ↔ endpoint table.
4. Viết `mode-work.md` + dispatch `/flow mode work`.
5. Viết `auto-run.md` + dispatch `/flow auto` (Tier classification, worktree, two-strikes, AUTO-LOG).
6. Wire `/flow ready` dùng deps + allowed-files overlap (đọc card front-matter).
7. Test: stage 01 với `researcher` có/không → cùng output shape; auto run dry trên 2 card parallel-safe.

## Todo list
- [ ] agent-detection.md + detect logic
- [ ] agent-stage-mapping.md + prompt template mỗi stage
- [ ] BMAD spec kernel ↔ Contract stage
- [ ] /flow mode work
- [ ] /flow auto (Tier, worktree, two-strikes, AUTO-LOG)
- [ ] /flow ready (deps + overlap)
- [ ] Test detect + fallback + parallel dry-run

## Success criteria
- Stage research chạy được qua `researcher` HOẶC fallback, output shape giống nhau.
- `/flow auto` merge card xanh không hỏi (Tier-A), halt ở security-class (Tier-C).
- `/flow ready` chỉ đánh dấu parallel-safe khi deps đủ + allowed-files không overlap.
- Subagent luôn trả status protocol; controller xử đúng BLOCKED/NEEDS_CONTEXT.

## Risk & mitigation
- **Agent ngoài đổi behavior/version:** chỉ phụ thuộc interface (prompt+status), không nội bộ; fallback built-in luôn sẵn.
- **Context bleed giữa card:** 1 card = 1 session/worktree; prompt scoped, không truyền full history.

## Security considerations
- Security-class skip (auth/admin/tenancy/payment) → Tier-C halt, cần operator văn bản (DEBT). Planner KHÔNG tự quyết.

## Next steps
→ Phase 04: bọc loop/auto bằng hard stops + ground-truth gate + adversarial verify.

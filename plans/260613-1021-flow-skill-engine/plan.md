---
title: "flow skill cho Claude Code — engine-first, layer dần tới super-skill"
status: superseded
priority: P1
created: 2026-06-13
---

> **Retired 2026-07-04**: this is the founding plan for flow-skill. Phases 1-2 (engine core,
> durable harness) were checked off; phases 3-6 (agent integration, loop-harness-engineering,
> design-law/playbooks, packaging/install/tests) were never checked here but were fully realized
> through ~15 subsequent versioned plans (v0.4 Codex agent integration, v0.18.0 ck-loop =
> literally "loop-harness-engineering", DESIGN.md/law + playbooks shipped early, install.sh +
> 28-suite test harness both exist). Superseded by that cumulative shipped work; retired so
> scans stop surfacing 62%-open as live unstarted work.

# Plan: `/flow` skill cho Claude Code — engine-first, layer dần tới super-skill

> Workspace phát triển: `D:\project\flow\flow-skill\`
> Tạo: 2026-06-13 10:21 · Mode: cook --interactive (ultracode)
> Nguồn kiến thức: `ai20k-build-phase/buildflow` (xương sống) · `repository-harness` (harness) · `BMAD-METHOD` (adversarial review + spec kernel) · `claudekit-engineer` (agent + đóng gói) · research 2026 (`../../../research-report-agent-orchestration-2026.md`)

## Mục tiêu

Xây skill `/flow` tái hiện trung thực quy trình buildflow 11-stage có gate (idea → URL deployed), bổ sung harness durable-records, tích hợp agent ck:/bmad, theo nguyên tắc harness/loop engineering 2026. Build theo **lát cắt dọc**: Phase 1 ship một `/flow` chạy được; các phase sau layer thêm sức mạnh. Cuối cùng cài vào `~/.claude/skills/flow` hoặc `.claude/skills/flow` của project.

## 3 quyết định đã chốt (operator)

1. **Phạm vi v1:** engine /flow chạy được trước, rồi layer dần.
2. **Phụ thuộc:** tích hợp đầy đủ ck: + bmad (detect-and-use, fallback built-in để vẫn portable).
3. **Cơ chế gate:** bash runner (deterministic) + lớp review Claude + durable DB (Python+sqlite3 portable; Rust harness-cli là power-path tùy chọn).

## Kiến trúc tổng (2 lớp + durable)

```
/flow (SKILL.md, lớp ngữ nghĩa Claude)   ── review chất lượng, adversarial, gatekeeper
   │ gọi
runner/flow.sh (lớp cơ học, exit 0/1)    ── check [FILL]/checkbox/evidence/card-status
   │ đọc-ghi
flow-harness (Python+sqlite3)            ── intake · risk-lane · story · trace · decision · backlog
   │ orchestrate (detect)
ck: agents + bmad skills                 ── research/plan/architect/dev/review/deploy/test
```

## Phases

| # | Phase | Trạng thái | Output cốt lõi |
|---|-------|-----------|----------------|
| 1 | [Engine core (vertical slice)](phase-01-engine-core.md) | ✅ **done** (2026-06-13) | SKILL.md + flow.sh + templates 00–05/card + CLAUDE/DESIGN/RETRO → `/flow` chạy được. Code-review pass (1 HIGH + 4 MEDIUM fixed). Test 13/13 xanh. |
| 2 | [Durable harness layer](phase-02-durable-harness-layer.md) | ✅ **done** (2026-06-13) | `flow_harness.py` (Python+sqlite3): intake/risk-lane/story/trace/decision/backlog + Rust toggle; wired vào flow.sh. Review pass (3 HIGH fixed). Test 19/19. |
| 3 | [Agent integration ck: + bmad](phase-03-agent-integration.md) | ✅ **done** (2026-06-13) | agent-detection + stage→agent mapping + mode-work + auto-run (Tier-A/B/C); SKILL.md wired. ck: primary, bmad alt, built-in fallback. Suites 13+19 xanh. |
| 4 | [Loop & harness engineering 2026](phase-04-loop-harness-engineering.md) | ✅ **done** (2026-06-13) | 4 references (principles/ground-truth/adversarial/debt) + `flow.sh debt` ledger |
| 5 | [DESIGN law + playbooks + T-C-R](phase-05-design-law-and-playbooks.md) | ✅ **done** (2026-06-13) | design-review-checklist + ui-patterns-tcr + 3 playbooks + `flow.sh design` UI check |
| 6 | [Packaging, install, tests, docs](phase-06-packaging-install-tests.md) | ✅ **done** (2026-06-13) | install.sh/ps1 + manifest + 6-round scenario test + docs. Review 0 HIGH. 46/46 tests. |

## Dependencies giữa các phase

- Phase 1 độc lập, ship được ngay (định nghĩa "vertical slice" của chính buildflow).
- Phase 2 cần Phase 1 (gắn durable record vào lifecycle stage/card).
- Phase 3 cần Phase 1+2 (agent đọc/ghi state + durable record).
- Phase 4 cần Phase 3 (loop/auto orchestrate agent có hard stop).
- Phase 5 song song được với 3–4 (asset + law file, ít coupling).
- Phase 6 cuối cùng (đóng gói toàn bộ).

## Success criteria (toàn skill)

- `/flow`, `/flow next`, `/flow card`, `/flow check C-NNN`, `/flow mode`, `/flow ready`, `/flow auto`, `/flow retro` chạy đúng spec buildflow.
- Gate cơ học deterministic (exit 0/1) + lớp Claude bắt được hollow content / grade-laundering / fake evidence (tái lập 6 round test).
- Durable record (intake/story/trace/decision) ghi bền qua session.
- Detect được ck:/bmad agents; thiếu thì fallback không vỡ.
- Cài 1 lệnh vào project/global Claude Code; chạy trên Windows (Git Bash).

## Out of scope v1

- Không build lại toàn bộ marketing kit ck:m.
- Không bắt buộc Rust toolchain (Rust harness-cli là tùy chọn; Python là mặc định).
- Không tự deploy app thật của user (Deploy là stage trong flow, do skill orchestrate, không phải nhiệm vụ của bản thân việc dựng skill).

## Open questions (đưa operator ở review gate)

- Q: Vị trí cài cuối — global (`~/.claude/skills/flow`) hay per-project (`.claude/skills/flow`) hay cả hai? (mặc định: hỗ trợ cả hai qua install script)
- Q: Namespace lệnh — `/flow` thuần hay `/ck:flow` để hợp hệ ck:? (mặc định: `/flow` thuần, alias `ck:flow` tùy chọn)
- Q: Ngôn ngữ artifact mặc định — Việt hay Anh? (mặc định: song ngữ, copy user-facing tiếng Việt theo DESIGN.md)

# Phase 04 — Loop & harness engineering (nguyên tắc 2026)

**Priority:** P2 · **Status:** ✅ done (2026-06-13) · **Depends:** Phase 03
**Mục tiêu:** bọc loop/auto bằng các nguyên tắc 2026 đã research — hard stops, ground-truth gate, adversarial verify, context isolation, worktree parallel, DEBT ledger.

## Context links
- Research: `../../../research-report-agent-orchestration-2026.md` + `research/loop-harness-2026-principles.md`
- BMAD adversarial: `BMAD-METHOD/docs/explanation/adversarial-review.md`, `src/.../bmad-code-review/steps/step-02-review.md`

## Key insights (đã đối chiếu, lấy nguyên tắc — bỏ qua số liệu chưa kiểm chứng)
- **Harness-first, không phải prompt-first:** chất lượng đến từ scaffold (gate, loop control, budget), không từ tinh chỉnh prompt.
- **Hard stops bắt buộc:** cap iteration + token + time cho mọi loop/auto; không có cap = antipattern.
- **Ground-truth verify ở gate quan trọng:** dùng exit code/test/lint, KHÔNG để LLM tự chấm ở điểm chuyển stage then chốt. LLM-as-judge chỉ phụ trợ.
- **Adversarial verify:** review "phải tìm ra lỗi"; 3 lớp BMAD (Blind Hunter chỉ thấy diff / Edge Case Hunter / Acceptance Auditor thấy spec) — information asymmetry chống confirmation bias.
- **Context rot:** từ ~5–10K token độ chính xác giảm → subagent cô lập + external memory (durable record phase 02) + compaction.
- **Spec/contract-first:** đúng "Contract là cái seam" — chống producer/consumer drift.

## Requirements
**Functional**
- Loop config mỗi stage/auto: `max_iterations`, `token_budget`, `timeout` → vượt = halt + báo cáo (không âm thầm tiếp).
- Gate "ground-truth": stage Build/Review/Verify dùng tín hiệu cơ học (flow.sh exit, story `verify_command`, test exit, lint) làm điều kiện pass — không phải lời tự đánh giá của agent.
- Adversarial Review gate: map vào `bmad-code-review` 3-layer hoặc spawn 3 subagent (diff-only / edge-case / acceptance-vs-contract); "zero findings → re-analyze hoặc giải thích".
- DEBT ledger: `DEBT.md` mỗi skip cố ý; security-class = halt + operator acknowledgment.
- AUTO-LOG: PR URL + merged SHA + tier + review verdict mỗi card auto.

**Non-functional**
- Loop termination tường minh; budget chia sẻ được báo cáo (token spent/remaining).
- Worktree parallel: 1 card = 1 worktree; merge theo card order; conflict = overlap-check gian lận → halt + re-plan.

## Architecture
```
references/
├── loop-harness-2026-principles.md   # checklist nguyên tắc + ánh xạ vào flow
├── ground-truth-gates.md             # tín hiệu cơ học mỗi gate + ngưỡng
├── adversarial-review.md             # 3-layer + "must find issues" + triage
└── debt-and-halts.md                 # DEBT schema, security-class halt, two-strikes
runner/flow.sh                        # thêm budget/iteration guard ở auto
```

## Implementation steps
1. Viết `loop-harness-2026-principles.md` (checklist actionable, gắn mỗi nguyên tắc vào điểm cụ thể của flow).
2. Định nghĩa ground-truth signal mỗi gate trong `ground-truth-gates.md`; sửa SKILL.md/gate-rules để gate then chốt dựa tín hiệu cơ học.
3. Viết `adversarial-review.md`: spawn 3 reviewer (asymmetry), triage severity/actionability; tích hợp `bmad-code-review` nếu có.
4. Thêm guard budget/iteration/timeout vào `/flow auto` (flow.sh + SKILL.md); vượt → halt + report.
5. Viết `debt-and-halts.md` + wire DEBT.md + security-class Tier-C halt + two-strikes.
6. Test: auto run vượt iteration cap → halt đúng; Review gate với code có bug cố tình → ≥1 reviewer bắt được.

## Todo list
- [ ] loop-harness-2026-principles.md
- [ ] ground-truth-gates.md + sửa gate then chốt
- [ ] adversarial-review.md (3-layer asymmetry + triage)
- [ ] budget/iteration/timeout guard cho /flow auto
- [ ] debt-and-halts.md + DEBT.md + Tier-C halt + two-strikes
- [ ] Test cap-halt + adversarial-catch

## Success criteria
- Loop/auto vượt cap → halt + báo lý do, KHÔNG chạy vô hạn.
- Gate Build/Review/Verify pass chỉ khi tín hiệu cơ học xanh (không phải agent tự nói "xong").
- Review gate bắt được bug cố tình cấy (regression test của chính skill).
- Security-class skip luôn halt, cần operator văn bản.

## Risk & mitigation
- **Over-engineering loop:** chỉ thêm loop khi metric/điều kiện rõ; mặc định serial 1-card.
- **Số liệu research chưa kiểm chứng:** chỉ áp dụng nguyên tắc, không hard-code con số ($/%); ghi rõ "verify khi cần".

## Security considerations
- Hard-gate: auth/authz/data-loss/audit/payment/removing-validation → không bao giờ auto-pass.

## Next steps
→ Phase 05: DESIGN.md law cho UI card + playbook loop + T-C-R assets (song song được).

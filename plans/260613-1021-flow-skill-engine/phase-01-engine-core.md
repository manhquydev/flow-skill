# Phase 01 — Engine core (vertical slice: `/flow` chạy được)

**Priority:** P0 (blocking) · **Status:** ✅ done (2026-06-13)
**Mục tiêu lát cắt dọc:** sau phase này, gõ `/flow next` trong một project copy template là chạy được — đúng tinh thần "vertical slice mỏng tới khi có thứ chạy" của chính buildflow.

## Context links
- Nguồn template verbatim: `D:\project\flow\ai20k-build-phase\buildflow\_templates\*` + `CLAUDE.md` + `DESIGN.md` + `RETRO.md`
- Spec engine (suy ra từ test report): `ai20k-build-phase\buildflow\docs\test-reports\round{1,2,3}*.md`
- Gate checklist verbatim: xem `research/buildflow-gate-checklists.md`

## Overview
buildflow là 2 lớp: **flow.sh** (cơ học, deterministic) + **lớp Claude** (ngữ nghĩa). Repo gốc thiếu cả hai — phase này dựng cả hai. flow.sh bắt "dishonest checkbox" ([FILL] còn sót, box chưa tick, evidence rỗng); SKILL.md hướng dẫn Claude làm gatekeeper chất lượng.

## Key insights
- Gate = checklist tự đánh dấu trung thực; **kill ở gate là kết quả hợp lệ**.
- flow.sh exit code: `0` = pass, `1` = fail + liệt kê vi phạm có số dòng + tên file.
- Stage 00–05 ở `flow/`; cards ở `cards/`; planning gate xong mới mở `/flow card`.
- "Done = bằng chứng thế giới thật" — card chỉ `status: done` khi `## Evidence` có world-state (URL/curl/DB row), KHÔNG phải "tests pass".
- Lớp Claude KHÔNG được tự tick box hay viết artifact thay operator.

## Requirements
**Functional**
- Lệnh: `/flow` (status), `/flow next`, `/flow card`, `/flow check C-NNN`, `/flow mode teach|work`, `/flow retro`.
- flow.sh subcommand tương ứng: `status|next|card|check|mode|retro`.
- Gate cơ học: scan `- [ ]` (chưa tick) và `[FILL]`; báo cáo từng vi phạm + line + file.
- Card check: tồn tại sections bắt buộc; nếu `status: done` → mọi Verify box ✓ và Evidence non-empty.
- `/flow card`: đọc `card.md` template, tự tăng ID `C-NNN`, ghi `cards/C-NNN.md`.
- `MODE` file ở root (default `teach`); mode `work` đổi ai viết artifact.

**Non-functional**
- Chạy trên Windows qua Git Bash (đường dẫn `/c/...`, không phụ thuộc GNU-only flags hiếm).
- Không phụ thuộc tool ngoài bash core (grep/sed/awk POSIX). Idempotent, không phá file người dùng.

## Architecture
```
skill/flow/
├── SKILL.md                     # frontmatter + command dispatch + lớp Claude gatekeeper
├── runner/flow.sh               # lớp cơ học, exit 0/1
├── _templates/                  # 00-idea..05-contract + card.md (copy verbatim từ ai20k)
├── law/CLAUDE.md                # luật build-session (copy + chỉnh path)
├── law/DESIGN.md                # luật UI (copy verbatim)
├── law/RETRO.md                 # 1 dòng/run
└── references/
    ├── stage-state-machine.md   # thứ tự stage, điều kiện unlock
    ├── gate-rules.md            # gate verbatim + lớp Claude challenge mỗi stage
    └── command-dispatch.md      # map /flow <cmd> → flow.sh + hành vi Claude
```
**flow.sh state machine:** đọc các file `flow/0N-*.md` tồn tại + đã pass gate → tính stage hiện tại → `next` check gate stage đó → tạo file stage kế (copy template) nếu pass.

## Related code files
- **Create:** toàn bộ cây `skill/flow/` ở trên.
- **Read for context:** mọi file trong `ai20k-build-phase/buildflow/` (nguồn copy).
- **Reference packaging:** `claudekit-engineer/claude/skills/cook/SKILL.md` (mẫu frontmatter + references pattern).

## Implementation steps
1. Tạo cây thư mục `skill/flow/`.
2. Copy verbatim 7 template (`00-idea`..`05-contract`,`card`) + `CLAUDE.md`/`DESIGN.md`/`RETRO.md` vào `skill/flow/_templates` và `skill/flow/law`; chỉnh các path tham chiếu `.claude/skills/flow/runner/flow.sh` cho khớp vị trí cài.
3. Viết `runner/flow.sh`: parser gate (FILL/checkbox), state machine stage, `card` generator (ID auto-increment), `check C-NNN`, `status`, `mode`, `retro`. Exit 0/1 + report.
4. Viết `SKILL.md`: frontmatter (`name: flow`, description, user-invocable), command dispatch, và **lớp Claude gatekeeper** — với mỗi stage liệt kê các "challenge" (stage 01: quote rỗng/fake; stage 02: grade-laundering; stage 03: pain↔feature mapping; stage 05: endpoint thiếu auth; card: evidence không phải world-state).
5. Viết 3 reference file (state-machine, gate-rules, command-dispatch).
6. Smoke test: tạo `flow/` thử, chạy `bash runner/flow.sh next` với file còn [FILL] → phải exit 1 + báo đúng dòng; điền đủ → exit 0 + tạo stage kế.

## Todo list
- [x] Scaffold cây skill/flow
- [x] Copy + adapt 7 templates + 3 law files (verbatim cp; path .claude/skills/flow/runner/flow.sh đã khớp)
- [x] Viết flow.sh (status/next/card/check/mode/ready/auto/retro) + exit codes
- [x] Viết SKILL.md (dispatch + gatekeeper challenges)
- [x] Viết references (state-machine, gate-rules, command-dispatch)
- [x] Smoke test pass/fail path trên Git Bash
- [x] Code-review (code-reviewer agent): 1 HIGH + 4 MEDIUM + cheap LOW đã fix
- [x] Regression suite `tests/test_flow_runner.sh` 13/13 xanh (gap-bypass, ### heading, --- evidence, short dep id, full E2E)

## Success criteria
- `bash runner/flow.sh next` exit 1 khi còn [FILL]/box chưa tick, exit 0 khi sạch, tạo đúng stage kế.
- `/flow card` sinh `cards/C-001.md` từ template, ID tăng dần.
- `/flow check C-001` fail khi `status: done` mà Evidence rỗng.
- Tái lập được round1 (happy path) + round2 (adversarial: chặn skip gate) ở mức cơ học.

## Risk & mitigation
- **Bash khác biệt Windows:** test sớm trên Git Bash; tránh `mapfile`/GNU-only; dùng POSIX.
- **Lớp Claude tự tick box (vi phạm luật):** SKILL.md ghi rõ FORBIDDEN, gatekeeper chỉ báo cáo, không sửa artifact.

## Security considerations
- flow.sh chỉ đọc/ghi trong `flow/`,`cards/`,`DEBT.md`,`RETRO.md`; không exec nội dung file; quote mọi biến path (chống injection từ tên file).

## Next steps
→ Phase 02 gắn durable record vào mỗi stage/card transition.

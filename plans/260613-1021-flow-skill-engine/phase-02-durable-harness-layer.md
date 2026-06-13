# Phase 02 — Durable harness layer (`flow-harness`)

**Priority:** P1 · **Status:** ✅ done (2026-06-13) · **Depends:** Phase 01
**Mục tiêu:** đưa "harness technology" của `repository-harness` vào flow — durable records bền qua session, risk lanes, trace có chấm điểm, decision records, growth-rule backlog.

## Context links
- Nguồn: `repository-harness/docs/{HARNESS,FEATURE_INTAKE,TRACE_SPEC,CONTEXT_RULES}.md`, `crates/harness-cli/src/*`, `scripts/schema/00N-*.sql`
- Synthesis: `research/repository-harness-portable-core.md`

## Key insights
- Lõi portable (không cần Rust): intake gate, 3 risk lane (tiny/normal/high-risk), story packet, trace 3 tier, decision ADR, growth-rule (ma sát → backlog → predicted vs actual).
- Rust-only thật sự = SQLite query layer → **thay bằng Python + stdlib sqlite3** (đã có sẵn trên máy, không cần cài).
- Harness "lớn lên từ ma sát": gặp khó/lặp lại → ghi backlog. Đây là loop tự cải thiện đáng giá nhất để mượn.
- Rust `harness-cli` build được (`cargo` có) → để làm **power-path tùy chọn**, không bắt buộc.

## Requirements
**Functional** — `flow-harness` CLI (Python) với subcommand bám schema gốc:
- `intake` — phân loại input type (6 loại) + risk lane (tiny/normal/high-risk) + risk checklist (10 flag, hard-gate auth/data/security/contract).
- `story add|update|verify|verify-all` — story packet + proof columns (unit/integration/e2e/platform) + optional `verify_command` chạy thật.
- `trace` — ghi trace, auto-score tier theo lane, cảnh báo nếu story chưa verify (pre-close gate).
- `decision add|verify` — ADR markdown + DB row.
- `backlog add` — growth-rule: `--pain --predicted`, đóng bằng `--outcome`.
- `query matrix|backlog|friction|tools` — đọc state (human + `--json`).
- `init` — tạo `harness.db` + thư mục `docs/{decisions,stories}`.

**Non-functional**
- 1 file Python thuần stdlib (argparse + sqlite3), chạy `python flow-harness.py <cmd>`. Không pip install.
- Schema versioned (migration tuần tự như `001-init`..`004`). Idempotent init.

## Architecture
```
skill/flow/harness/
├── flow_harness.py          # CLI Python (snake_case), stdlib only
├── schema/                  # 001-init.sql .. 004-*.sql (port từ repository-harness)
└── README.md                # map command ↔ responsibility (11 Runtime Substrate)
# optional power-path:
└── rust/ -> hướng dẫn build repository-harness/harness-cli nếu user muốn
```
**Tích hợp lifecycle:** flow.sh gọi flow_harness ở các mốc — `/flow next` qua stage 02 → `intake` ghi risk lane; mỗi card → `story add`; `/flow check` done → `trace` + pre-close gate; quyết định ADR ở stage 04 → `decision add`; gặp ma sát bất kỳ → `backlog add`.

## Related code files
- **Create:** `skill/flow/harness/flow_harness.py`, `schema/*.sql`, `README.md`.
- **Modify:** `runner/flow.sh` (gọi harness ở transition), `SKILL.md` (hướng dẫn dùng durable record), `references/gate-rules.md` (gắn risk-lane vào gate).
- **Read:** `repository-harness/crates/harness-cli/src/{domain,application,infrastructure,interface}.rs` (port logic), `scripts/schema/*.sql`.

## Implementation steps
1. Port schema SQL (intake/story/decision/backlog/trace/tool/intervention) → `schema/`.
2. Viết `flow_harness.py`: migration runner, từng subcommand, scoring trace tier, validation (description length, risk flag, proof columns).
3. Map 6 input type + 3 lane + 10 risk flag + hard-gate rules thành decision logic (port từ `domain.rs`).
4. Wire flow.sh: thêm hook gọi harness ở mỗi transition; degrade gracefully nếu `python` vắng (cảnh báo, không vỡ engine Phase 1).
5. Viết `harness/README.md`: bảng command ↔ 11 responsibility + ví dụ.
6. (Tùy chọn) Viết hướng dẫn build Rust harness-cli + cờ `FLOW_HARNESS_BACKEND=rust|python`.
7. Test: init → intake high-risk (auth) phải auto-escalate; trace tiny chỉ cần tier-1; story verify chạy command thật trả pass/fail.

## Todo list
- [x] Port schema SQL → schema/ (verbatim, 4 migrations)
- [x] flow_harness.py + _db.py + _domain.py: migration + intake/story/trace/decision/backlog/tool/intervention/query/init
- [x] Trace tier scoring + pre-close gate
- [x] Wire flow.sh transitions → harness (card→story add, check-done→story implemented + trace; graceful degrade + `flow.sh harness` passthrough)
- [x] harness/README map command↔responsibility + Rust build guide + backend toggle
- [x] Rust backend toggle `FLOW_HARNESS_BACKEND=rust` + `FLOW_HARNESS_CLI` + cargo build guide
- [x] Test intake/trace/story-verify (suite 19/19) + code-review (3 HIGH: migration atomicity, init crash, tool guard — fixed) + Windows POSIX path fix

## Success criteria
- `python flow_harness.py init` tạo db sạch; chạy lại không phá.
- `intake` chạm auth → lane = high_risk tự động (hard gate).
- `story verify <id>` chạy `verify_command` thật, ghi pass/fail + last_verified_at.
- `trace --story X` cảnh báo khi story chưa verify (pre-close gate, advisory).
- State đọc lại được qua session mới (`query matrix`).

## Risk & mitigation
- **Python vắng ở máy đích:** flow.sh detect; thiếu → engine Phase 1 vẫn chạy (durable layer là tăng cường, không blocking).
- **Drift schema vs Rust:** giữ schema SQL là nguồn chung cho cả 2 backend.

## Security considerations
- High-risk class (auth/authorization/data/audit/payment) KHÔNG bao giờ tự pass — escalate + cần operator acknowledgment (gắn vào DEBT phase 04).
- Không lưu secret trong trace/decision; sanitize input trước khi vào SQL (parametrized query).

## Next steps
→ Phase 03: agent ck:/bmad đọc-ghi durable record này khi orchestrate.

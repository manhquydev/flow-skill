# v0.29.0 — spec-kit imports + converge (flow-back closer) — shipped

**Ngày:** 2026-08-13 · **npm:** 0.6.0 · **skill:** 0.29.0

## Bối cảnh
Bóc tách GitHub spec-kit để tìm kỹ thuật mang về nâng cấp flow. Điều phối nhiều grok (herdr)
song song cho research + cross-review; ak-pipeline (advise → brainstorm → plan → red-team →
validate → cook → test → code-review → ship → review-pr) cho từng lô.

## Đã ship
**Lô 1 (PR #1, spec-kit imports):**
- `## Open decisions` + `/flow clarify` — dùng CHÍNH scanner `scan_gate` có sẵn, KHÔNG token
  `[ASK]` tự-độc (bài học DF3). Đây là insight lớn của brainstormer: token free-text mà chính
  documentation của nó chứa chuỗi grep sẽ poison mọi template — section-với-checkbox né được.
- `## Independent test` card field + quality-boxes PRD/contract + `artifact-lifecycle.md`.

**Lô 2 (cycle này, converge — fixture-first):**
- **Eval modality thứ 3** `flow.sh eval --stage converge` — judge repo-state (flow docs + card
  claims + source theo allow-list) → GAP|CONVERGED. Mirror routing-modality. Test offline hoàn
  toàn bằng mock engine (PATH-shadow `claude`, mock trích nonce từ prompt).
- **`cmd_converge` transactional** — validate hết rồi commit all-or-nothing (rollback), append-only,
  CONVERGED thì byte-identical `cards/`, unrequested → review card (không xoá code).

## Quyết định / bài học
- **Fixture-first có giá.** Brainstormer chốt "converge là cycle, không phải card" vì 100% giá
  trị nằm ở semantic gap-detection — mà nửa đó chưa có bằng chứng. Scoping eval-harness (Explore)
  lộ ra: harness cũ chỉ chấm single-artifact; hollow-complete cần modality repo-state mới. User
  chọn build đầy đủ modality thay vì cắt.
- **Red-team + code-review bắt lỗi thật mỗi vòng:** red-team bắt 4 trap test-recipe TRƯỚC khi code;
  code-review bắt `sed -i` giết macOS CI (Linux không thấy được) — sau đó CI macOS xác nhận fix đúng.
- **Whole-plan consistency:** bỏ hedge "when it exists" trong artifact-lifecycle làm 1 assertion
  của test lô-trước đỏ — đúng loại drift cross-file mà consistency-gate tồn tại để bắt.
- **Take-over khi agent kẹt:** grok kẹt giữa phase-2 lô 1 → tự tiếp quản, tạo file còn thiếu, verify.

## Con số
- v0.29.0: +3 test suite mới + 7 case converge-modality. 3-OS bash-suite xanh. Coherence PASS.
- Deferred: không còn — converge đã đóng lỗ hổng "plan-vs-code" cuối.

# Nhật ký kỹ thuật — v0.22.0 ship (2026-07-16)

## Bối cảnh

Phiên bắt đầu bằng brainstorm mở của operator: cộng đồng dùng flow không muốn học tiền tố
verb (`flow xxx`), muốn chat và để flow tự vận hành. Scout so sánh `bmad-help` (BMAD-METHOD)
và whitelist skill/agent của claudekit-engineer — flow đã tự giải quyết 60-70% bài toán chọn
lọc (whitelist 15 skill, 6 deep-wired, degrade chain ck→bmad→built-in); phần thiếu là **cửa
vào**. Giữa phiên, operator đổi khung: không còn "flow điều phối ck+BMAD" mà "flow độc lập
hoàn toàn — cài flow là đủ, không cần ck/BMAD nữa". Đây là pivot lớn nhất kể từ v0.14.

## Quyết định lớn: concierge + standalone, không phải router tổng

Design 2 workstream, chốt bằng brainstorm report:
- **WS-A Concierge**: chat mặc định → `flow.sh status` (bằng chứng cơ học) → bảng định
  tuyến intent×state → đề xuất 1 hành động → hỏi trước khi chạy (mẫu bmad-help, nhưng grounded
  trên state machine cơ học thay vì phát hiện file mờ).
- **WS-B Standalone**: 5/6 nghi thức gate ngoài (ck-predict/ck-scenario/ck-security/ck-loop/
  retro) có bản thay thế bản địa; ck/BMAD chỉ còn là "richer alternative" khi có sẵn.
- **Phạm vi router**: chỉ vòng đời flow, KHÔNG router tổng cho 93 skill claudekit — rejected
  vì "đúng bệnh quá nhiều lệnh, không nên làm to hơn".
- **Pháp lý**: claudekit-engineer proprietary (All Rights Reserved) → cấm chép chữ, cấm commit
  chữ ck vào repo dù trong test. BMAD-METHOD MIT → port kèm license nguyên văn.

## Pipeline đã chạy

```
brainstorm (report 260716-1342) → ck:plan --tdd (4 phase)
  → RED-TEAM (3 lens hostile subagents song song, mọi finding phải có file:line)
    → 21 raw → 13 accepted after dedup (3 Critical, 5 High, 5 Medium), 0 rejected
  → validate (4 câu hỏi, ngôn ngữ dễ hiểu theo yêu cầu operator)
    → V1 English-canonical, V2 cost-cap 90, V3 GH Actions thay Azure, V4 panel-agreement
  → cook pipeline TDD từng phase: RED test → GREEN content → đăng ký run_all.sh → full suite
    → 2 lần chạy full suite độc lập xác nhận 34 suite / 926 check ALL PASSED
      → docs sync + install 5 homes
```

## Red-team đã bắt gì trước khi viết 1 dòng code

3 Critical, nếu bỏ qua đã ship 3 lỗ hổng thật ngay từ phase 1:

- **F1**: bảng "được tự chạy / phải hỏi" chỉ phủ ~17/27 verb — `promote` (ghi KB toàn cục) và
  `harness` (ghi durable) rơi vào khoảng trống không phân loại, có thể bị tự chạy. Fix:
  default-deny + test đếm đủ 27 verb.
- **F2**: `next` bị xếp nhầm vào "được tự chạy" — điều kiện "cả 2 tầng đã pass" không thể kiểm
  TRƯỚC khi `next` chạy (tầng mechanical chỉ báo pass/fail SAU khi chạy). Fix: `next` → phải
  hỏi.
- **F3**: "eval routing chỉ là thêm 1 dòng vào `--stage`" là nói dối phạm vi — harness eval
  cũ hard-wire toàn tuyến cho việc soi artifact rỗng (prompt đọc gate-rules.md, verdict chỉ
  FLAG/PASS, manifest cần file artifact thật). Routing judge (state+utterance→action) là
  **modality hoàn toàn khác**. Operator quyết: xây thật, không cắt — thành 1 subsystem riêng
  (prompt/verdict/manifest/scorecard/results-file riêng, chỉ tái dùng primitive chung).

5 High khác cũng đắt: tripwire chống-copy ck lại tự nhúng chữ ck vào repo MIT (đổi sang human
diff + positive markers); MIT attribution 1 dòng không đủ (phải chép nguyên văn LICENSE);
kịch bản người-mới va luật teach-mode cấm Claude viết hộ (thêm đúng 1 câu hỏi đồng ý); test
suite mới không tự chạy trên CI nếu quên đăng ký tay vào `run_all.sh` (không có auto-discover).

## Số thật cho chất lượng

| Metric | Số |
|---|---|
| Files changed | 23 (16 modified, 7 created) |
| New references | `concierge.md`, `native-rituals.md`, `forge-idea.md`, `flow-catalog.tsv` |
| New test suites | 3 (`test_flow_concierge`, `test_flow_native_rituals`, `test_flow_forge_idea`) + `test_flow_eval.sh` mở rộng (R-A..R-G) |
| Red-team findings | 21 raw → 13 accepted, 0 rejected, tất cả có file:line |
| Full suite (2 lần chạy độc lập) | **34 suites / 926 checks, ALL PASSED** (từ 31/799) |
| Routing catalog | 27/27 dispatcher verb phân loại đúng 1 lần (may-run hoặc must-ask) |
| Routing eval judge cost cap | 90 calls/batch (validation V2) |
| Cross-vendor spot-check thật | Antigravity/Gemini-3, 3/3 utterance khớp catalog (`resume`/`check`/`retro`) |
| Codex CLI | có cài nhưng workspace 402 deactivated — installed≠usable, đúng như tài liệu đã cảnh báo |
| CI | GitHub Actions `bash-suite` job mới (3 OS), Azure Pipelines demoted fallback |

## Bug tự phát hiện trong lúc build (không phải red-team, tự mình soát)

1. **Regression thật**: sửa `adversarial-review.md` (native-first STRIDE) làm vỡ 1 assertion
   cũ trong `test_flow_claudekit_integration.sh` đang khớp câu chữ cũ nguyên văn. Phát hiện
   qua full-suite run, sửa regex test để khớp câu chữ mới có chủ đích (không làm yếu test).
2. **Bug hạ tầng test**: `bash -c "source flow.sh status"` không giữ `$0` = đường dẫn thật →
   `SCRIPT_DIR` tính sai → mọi biến phụ thuộc SCRIPT_DIR (CONCIERGE_FILE...) trỏ sai chỗ. Fix:
   truyền thêm arg sau command-string cho `bash -c` để nó thành `$0` trong ngữ cảnh sourced.
3. **PATH-sandbox test sai kiểu**: test "claude absent" dùng thư mục rỗng làm PATH giả →
   `bash`/`awk`/`grep` chính nó cũng biến mất → exit 127 chứ không phải SKIP sạch. Fix: copy
   toàn bộ `/usr/bin,/bin` trừ `claude` (đúng pattern suite gốc đã dùng, tôi bỏ sót khi viết
   test mới).
4. **1 test flaky do tự mình chạy 2 full-suite chồng nhau** — hai lần `run_all.sh` đồng thời
   đụng độ trên `.flow/` lock/temp. Xác nhận bằng cách chạy `test_flow_constitution.sh` riêng
   lẻ → 25/25 xanh. Bài học: không chạy 2 full-suite song song trên cùng repo.

## Bài học ghi lại

1. **"Thêm --stage" không phải lúc nào cũng nhỏ.** Chữ "chỉ mở rộng CLI flag" che giấu việc
   phải xây cả 1 hệ thống judge song song. Red-team đọc code thật (không chỉ đọc plan) mới
   thấy được prompt builder/verdict parser/manifest schema đều gắn cứng vào shape cũ.
2. **Default-deny rẻ hơn default-allow-rồi-liệt-kê-ngoại-lệ** cho mọi bảng phân quyền tự động
   — bất kỳ verb mới nào thêm sau này tự động rơi vào "phải hỏi" thay vì tự động được chạy.
3. **`bash -c "source ..."` không giữ `$0`** — bẫy kinh điển khi unit-test 1 hàm nội bộ của
   script bash mà hàm đó phụ thuộc biến toàn cục tính từ `$0`. Giải: truyền thêm arg cho
   `bash -c` làm `$0`.
4. **Cross-vendor claim phải có bằng chứng thật, không chỉ tuyên bố.** Codex CLI có cài nhưng
   tài khoản deactivated — nếu không thử thật sẽ không biết; Antigravity dự phòng có sẵn và
   cho kết quả 3/3 đúng thật, nâng độ tin cậy của README claim.

## Deferred (công khai, không im lặng)

- `flow.sh status`/`resume` vẫn là human prose, không có machine token contract — routing
  trên engine không phải Claude vẫn là best-effort, chưa guaranteed. Re-trigger: một engine
  không-Claude định tuyến sai trong thực tế.
- Routing eval judge mới build, chưa có batch billable thật quy mô lớn (chỉ dry-run cấu trúc
  + cross-vendor spot-check thủ công qua Antigravity) — batch panel-agreement đầy đủ để dành
  cho lần vận hành thật đầu tiên.
- `review-pr` không có nghi thức bản địa tương đương (đặc thù PR/GitHub) — giữ nguyên trạng
  optional.

## Trạng thái sau ship

- v0.22.0, plan `plans/260716-1342-flow-v022-concierge-standalone/` = 4/4 phase done.
- 2 lần chạy `run_all.sh` độc lập đều xanh tuyệt đối: 34 suites / 926 checks.
- `flow.sh coherence` PASS trên 3 nguồn version (SKILL.md, plugin.json, portable-manifest.json).
- Cài lại 5 home (Claude/Codex/Agents/Antigravity CLI+IDE) sau khi suite xanh, đúng thứ tự
  rollback-safe mà plan yêu cầu (install LAST).

## Câu hỏi mở

Không có. Mọi deferred đã ghi rõ điều kiện re-trigger.

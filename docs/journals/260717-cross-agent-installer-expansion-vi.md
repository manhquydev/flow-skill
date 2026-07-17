# Nhật ký kỹ thuật — cross-agent installer expansion (2026-07-17)

## Bối cảnh

Operator báo 2 vấn đề: (1) "npx cài Antigravity không hoạt động", (2) muốn mở rộng hỗ trợ agent
khác như Cursor. Đi đúng pipeline: `/research` → `/brainstorm` → `/ck:plan --tdd` →
`/ck:plan red-team` (3 agent thù địch song song) → `/ck:plan validate` → cook (TDD từng phase).

## Quyết định lớn: chẩn đoán lại triệu chứng

Research ban đầu tưởng "npx cài nội dung cũ" (bundle npm chưa sync v0.22). Nhưng **validate hỏi
lại triệu chứng cụ thể** → operator trả lời "cài rồi mở Antigravity gõ /flow không thấy — hay
phải restart?". Verify thật: cả `cli.mjs`/`install.sh` chỉ nhắc Claude+Codex restart, **bỏ quên
Antigravity hoàn toàn**. Đây mới là bug thật — skill mới cài không được agent nhận ra tới khi
reload, và user không được báo cần làm gì. **Nếu cứ cắt release v0.22 mà không sửa dòng hướng
dẫn, lỗi user báo vẫn còn y nguyên.** Cổng "confirm symptom first" mà red-team ép thêm đã cứu
đúng lúc.

## Red-team bắt gì trước khi code (3 reviewer song song, 22 raw → 13 accepted, 1 rejected)

2 Critical:
- **C1**: marker `.cursor` trần → mọi user Cursor bị tự cài flow vào config dù không xin (bẫy
  y hệt `~/.gemini` mà antigravity đã né). Fix: marker `.cursor/skills`.
- **C2**: guard chống bundle-cũ (version check) **vô dụng** — CI chạy `sync` TRƯỚC `test` nên
  guard không bao giờ đỏ. Cả 3 reviewer độc lập cùng bắt trúng.

5 High: blocker (release) bị khoá sau Cursor-verify không chắc test được; premise "đã conform
chuẩn + path Cursor" chưa verify (web research, không phải bằng chứng thật); 10 chỗ "4→5"
chưa liệt kê đủ (chỉ 1/10)...

Bị bác 1: "concierge.md không tồn tại" — sai, file có thật (reviewer Glob nhầm bundle npm cũ).

## Bug thật tự phát hiện khi code (không phải red-team, tự soát trong lúc triển khai)

1. **Plan sai một giả định**: red-team + plan giả định phải "gitignore bundle npm" — kiểm tra
   `git ls-files npm-wrapper/skills/flow` = **0 file, đã gitignored sẵn từ trước**. Việc thật
   còn lại hẹp hơn nhiều: (a) bundle local cũ cần sync lại, (b) manifest rò path Windows tuyệt
   đối, (c) chưa có `pretest`, (d) chưa cắt release.
2. **Test đầu tiên tôi viết bị false-negative**: regex `/[Aa]ntigravity/` khớp nhầm dòng
   "✔ antigravity -> ..." (log cài đặt bình thường) thay vì dòng "Done." thật → RED giả. Sửa:
   cô lập đúng dòng "Done." trước khi assert.
3. **Race điều kiện Windows**: chạy `npm test` đầy đủ (5 file) thỉnh thoảng fail 1 test không
   liên quan với exit code lạ (3) — tái hiện 100% khi chạy song song, 0% khi
   `--test-concurrency=1` (38/38 xanh × 3 lần liên tiếp). Nguyên nhân: 2 test real-install mới
   của tôi tranh chấp child-process với `lock-atomicity.test.mjs` trên Windows — không phải bug
   logic. Ghim concurrency=1, chi phí không đáng kể (~1-2s).
4. **Cài Cursor thật xong → Done-line rỗng** (`"Done. "`) — quên thêm `cursor` vào map
   `RESTART_HINTS` khi thêm target mới (map này viết ở Phase 1, trước khi Cursor tồn tại). Viết
   RED test bắt đúng, fix kèm ghi chú trung thực về giới hạn xác minh (xem mục sau).
5. **`$HOME` trong PowerShell là automatic variable**, không đọc từ `$env:HOME` — 1 lần test tay
   `install.ps1` với `$env:HOME` override đã vô tình cài thật vào home thật (không hại vì nội
   dung giống hệt, idempotent) thay vì scratch dir như định. Ghi nhận để không lặp lại kỹ thuật
   test sai này.

## Phát hiện sống cho Cursor (không đoán mò)

Máy này có cài Cursor thật (`~/.cursor/skills/` tồn tại) — phát hiện **symlink thật**:
`~/.cursor/skills/find-skills -> ~/.agents/skills/find-skills`. Bằng chứng sống xác nhận
đường dẫn thật Cursor đọc skill là `~/.cursor/skills/<name>`, và nó tiêu thụ nội dung từ
`~/.agents/skills/` (universal home) — đúng như research đã tìm nhưng giờ có evidence thật
trên máy, không phải chỉ tài liệu web.

**Giới hạn trung thực**: Cursor **không có CLI headless** (`cursor agent --help`/`-h` đều rơi về
help chung của IDE, không có subcommand `-p`/`exec` in-kết-quả như `agy -p` của Antigravity hay
`codex exec` của Codex). Không thể live-verify runner chạy bên trong Cursor như đã làm với
Antigravity. Ghi thẳng vào README/CHANGELOG: "install verified, runner execution not yet
independently confirmed" — không tuyên ngang hàng với Antigravity/Codex.

## Số thật

| Metric | Số |
|---|---|
| Red-team | 3 reviewer, 22 raw → 13 accepted (2 Critical, 5 High, 6 Medium), 1 rejected |
| npm-wrapper test (`npm test`) | **41/41 xanh**, × 3 lần lặp lại ổn định (từ 35 gốc: +2 A0 restart-hint, +1 sync-manifest, +2 cursor detect, +1 cursor restart-hint = 41) |
| Root bash suite (`tests/run_all.sh`) | **34 suite / 930 check — ALL SUITES PASSED** (từ 926, +4 assertion Invariant 9) |
| Target npx installer | 4 → **5** (thêm Cursor) |
| File "4 target" sửa | 10+ chỗ (help.mjs, prompt.mjs comment, constants.mjs comment, 2 root README EN/VN, 2 npm-wrapper README EN/VN — 2 file cuối là phát hiện thêm ngoài danh sách red-team gốc) |
| File sửa | ~20 (cli.mjs, install.sh, install.ps1, constants.mjs, help.mjs, prompt.mjs, sync.mjs, package.json, 4 README, 2 CHANGELOG, 4 test file mới/sửa, 1 bash test suite) |
| Package version | 0.1.0-rc.1 → **0.1.0-rc.2** (chưa publish) |

## Bài học ghi lại

1. **"Confirm symptom first" không phải thủ tục — nó đổi hướng fix thật.** Nếu bỏ qua bước hỏi
   lại, đã cắt release v0.22 và lỗi user báo vẫn y nguyên (khác agent, khác nguyên nhân).
2. **Đừng tin giả định của chính plan/red-team khi có thể verify rẻ.** `git ls-files` 1 lệnh
   lật ngược nguyên workstream "gitignore bundle" — nó đã tồn tại sẵn. Luôn verify trước khi
   thực thi một finding, kể cả finding "đã được duyệt".
3. **Bằng chứng sống > tài liệu web cho path/behavior của 1 tool cụ thể.** Symlink thật tìm thấy
   trên máy giá trị hơn hẳn "theo research, Cursor đọc ~/.cursor/skills/".
4. **Không phải agent nào cũng có CLI headless để tự động verify.** Antigravity + Codex có,
   Cursor không — ghi thẳng giới hạn thay vì giả vờ đã verify ngang nhau.
5. **Test real-install (không dry-run) giá trị cao nhưng có phí phụ**: race điều kiện Windows
   khi chạy song song nhiều test spawn child-process. Pin concurrency khi cần, đừng chấp nhận
   flaky.

## Deferred (công khai)

- Cursor live-runner: chưa verify độc lập được (không có CLI headless). Cần thao tác tay trong
  Cursor IDE hoặc GUI-automation tool phù hợp để đóng nốt.
- Copilot/VS Code, Gemini CLI: ngoài phạm vi ưu tiên đợt này (operator chỉ chọn Cursor +
  universal). Chưa claim gì về chúng.
- Release npm rc.2: **chưa publish** — lệnh đã ghi trong CHANGELOG
  (`git tag npm@0.1.0-rc.2 && git push --tags`), chờ operator quyết định thời điểm.

## Trạng thái sau phiên

- Plan `plans/260717-0925-cross-agent-installer-expansion/` = 3/3 phase done.
- `npm test` (npm-wrapper) 41/41 xanh × 3 lần; `tests/run_all.sh` (root) 34 suite/930 check
  ALL PASSED.
- Chưa commit, chưa publish npm — chỉ thay đổi trên đĩa.

## Câu hỏi mở

Không có mới. Giới hạn Cursor đã ghi rõ điều kiện đóng (cần verify thủ công/GUI-automation).

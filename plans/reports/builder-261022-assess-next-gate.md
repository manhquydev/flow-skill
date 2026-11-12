# Brownfield assessment gate — 2026-10-22

## Phạm vi và revision

- Base: `9ccda18d3da36b635d6d2f2a5b5096bfcb669e64`.
- Worktree độc lập: `/home/manhquy/Documents/flow-skill/.omp/flow-maintenance/worktrees/assess-next-gate-261022`.
- Branch: `flow/next/assess-next-gate-261022`; remote: `https://github.com/manhquydev/flow-skill.git`; PR đích: `master`, chỉ draft.
- Không đọc/chạm checkout WIP, STOP zones, cấu hình remote, release hay tags.

## Thay đổi

- Theo quyết định review của Main, khôi phục `skills/flow/runner/flow.sh` và `portable-manifest.json` đúng base `origin/master`. Guard `inspect_gate_clean` có sẵn giữ nguyên DEBT skip và event attribution; không cần thay đổi runtime.
- `tests/test_flow_assess.sh`: case I kiểm tra dirty trả exit 1, không tạo idea; clean, DEBT-skipped và absent trả exit 0, tạo idea. Mỗi trạng thái đều kiểm tra hướng dẫn và `NEXT_VERB` nhất quán giữa status/resume với next. Đổi tên case replay cũ thành J, không đổi nội dung replay.
- `CHANGELOG.md`: ghi nhận regression coverage dưới `[Unreleased]`, không tuyên bố thay đổi hành vi runtime.
- Canonical sync đã chạy lại; runner SHA-256 trở về `48765e80d38ffc5ba2d089ea31c2786fd652caf4357aff9c3044574c7cede490`.

## Evidence quan sát trực tiếp

Các lệnh chạy tuần tự trong worktree được giao, không gọi model live:

| Lệnh | Kết quả |
|---|---|
| `node npm-wrapper/scripts/sync.mjs` | Exit 0; sync OK, 133 files |
| `bash tests/test_flow_assess.sh` | Exit 0; 134 passed, 0 failed |
| `bash tests/test_flow_runner.sh` | Exit 0; 156 passed, 0 failed |
| `bash scripts/check-doc-budgets.sh` | Exit 0; 6 files trong budget |
| `bash tests/test_doc_budgets.sh` | Exit 0; 8 passed, 0 failed |

Case J dùng offline replay với verdict tổng hợp như suite hiện có; không phải đánh giá model live. Các case I chạy runner thật trong thư mục tạm.

## Review và giới hạn

Main phát hiện guard mới trước đó làm lệch debt-skip với status/resume và mất event attribution. Đã loại bỏ thay đổi runtime theo quyết định review; `git diff --exit-code origin/master -- skills/flow/runner/flow.sh portable-manifest.json` trả exit 0, không có diff. Regression case I giữ chính sách skip hiện hành. Main chịu trách nhiệm independent QA revision đã push; không chạy full 3-OS suite vì đây là test slice có scoped evidence theo AGENTS.md.

## Nhật ký kỹ thuật

Preference `journal.auto` trả `true`. Ghi nhật ký ngay trong report được cấp quyền này; không tạo `plans/journals/` ngoài allowlist. Lần chạy test mới đầu tiên có 130 passed/4 failed vì assertion của worker giả định resume dùng prefix `NEXT ->`; source `cmd_resume` dùng `nothing to resume -` khi chưa có stage. Đã sửa assertion đúng contract, không đổi runner; chạy lại đạt 134/0. AgentWiki publish skipped.

Draft PR: https://github.com/manhquydev/flow-skill/pull/83. Commit sửa tiếp nối `ca958491d335c606090ab6f0c21bbb3543a24f03`; pushed SHA cuối được cung cấp trong bàn giao để tránh self-referential commit hash.

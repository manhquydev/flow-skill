# Chuẩn bị release skill 0.34.9 / npm 0.7.16

## Phạm vi và revision

- Repository: https://github.com/manhquydev/flow-skill
- Base: `3a4b07505e466213c521ceb5ced990d80a9f1676`.
- Release preparation commit: `703519b43b048e351638bb6d856764c352d02e89`.
- Branch: `feat/release-prep-0349-0716`; checkout riêng `.omp/flow-maintenance/worktrees/release-prep-0349-0716`.
- Chỉ chuẩn bị Phase 1 và draft PR; không publish, tạo tag, merge, thay đổi quyền hoặc cấu hình remote.

## Kết quả

Đồng bộ ba khai báo skill thành 0.34.9, npm thành 0.7.16, release intent stable/latest và changelog ngày 2026-10-22. Ghi chú bao gồm `flow rules agents-md` và doctor remedy hints; tương thích ngược, không mở rộng security/service rights. Bốn README và hash EN/VI được đồng bộ. Giữ nguyên schema release intent theo chỉ đạo của Main; SHA được ghi ở đây và PR thay vì thêm trường mới.

## Evidence quan sát trực tiếp

Các lệnh chạy tại checkout riêng, môi trường Linux; không phải bằng chứng CI đa nền tảng:

| Lệnh | Kết quả |
|---|---|
| `node scripts/sync-release.mjs --sync` | Đồng bộ 4 README và bundle 133 file |
| `bash scripts/check-i18n-pairs.sh record npm-wrapper/README.md` và `record README.md` | Ghi hash blob HEAD sau commit; đưa vào amended commit |
| `node scripts/sync-release.mjs --check` | Exit 0, skill 0.34.9 / npm 0.7.16 coherent |
| `bash tests/test_release_coherence.sh` | 43 passed, 0 failed |
| `bash tests/test_sync_release.sh` trên committed snapshot | 133 passed, 0 failed |
| `bash tests/test_doc_budgets.sh` | 8 passed, 0 failed |
| `bash scripts/check-doc-budgets.sh` | 6 file trong budget |
| `bash scripts/check-release-coherence.sh` | Exit 0 |
| `bash scripts/check-i18n-pairs.sh` | 2 cặp đúng |
| `npm --prefix npm-wrapper test` | 87 passed, 0 failed; output `artifact://4685` |
| `bash scripts/release-preflight.sh` trên committed snapshot | Exit 0; doctor READY, coherence/i18n/budgets/compile/topology đúng |

`test_sync_release.sh` dùng mock và scratch repository cho promotion/tag/release branches; không phải live publish. Preflight chỉ đọc registry thật: `latest=0.7.15`, đúng trạng thái trước release mới. Không chạy promotion trên repository thật.

## Điều tra và review

Lần kiểm tra trước commit phát hiện fixture clone HEAD cũ rồi chép intent mới, khiến skill 0.34.9 không có changelog ở clone. Không sửa/giảm assertion: commit snapshot đồng bộ rồi chạy lại suite thành công. Lần preflight đầu sau commit phát hiện recorder đọc HEAD blobs nên hash ghi trước commit còn cũ; ghi lại trên HEAD mới và amend, preflight sau đó thành công.

Inline review đối chiếu acceptance: thay đổi chỉ metadata/changelog/docs, không thay runner/API, không mở rộng quyền. Independent review và exact pushed SHA CI thuộc Main; báo cáo này không phải phê duyệt phát hành. Legacy output của `--sync` vẫn hướng dẫn tag/master push; đã bỏ qua vì trái canonical runbook, không sửa script ngoài phạm vi.

## Nhật ký ngắn

Tách rõ version sản phẩm và installer; điểm đáng lưu ý là fixture git clone và i18n recorder đều yêu cầu snapshot committed nhất quán. Preference journal tự động là true nhưng thư mục journal không nằm trong allowlist; ghi reflection tại report đã được chỉ định, không tạo file ngoài quyền. AgentWiki publish skipped.

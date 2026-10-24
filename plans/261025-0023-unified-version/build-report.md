# UNIFY-VERSION-261025 — implementation journal

Ngày: 2026-10-25, Asia/Bangkok. Worker: ImperialSpoonbill. Base: `794fd026141e23a29b5c79af072e7f4fd0bdc165`; branch: `flow/unify-version-261025`.

## Kết quả

Áp dụng một SemVer chung 1.0.0: package, release intent, guards, README EN/VI và changelog đồng bộ. Giữ nguyên banner và tên trường. Copy decision.md nguyên byte từ bản owner. Ship chỉ tái sử dụng skill tag có cây `skills/` giống HEAD; kiểm tra trước promotion và ngay lúc tagging, từ chối khi khác hoặc thiếu hash. Không tạo lại skill tag/Release đã tái sử dụng. Không publish/push/tag trên repository thật.

Phát hiện thêm guard non-equality trong check-release-coherence.sh và CLI test; parent đã mở rộng allowlist trước khi sửa. Fixture prerelease/preflight và clone metadata được đồng bộ theo policy mới; không hạ gate. i18n receipts được ghi từ committed blobs rồi amend cùng một commit.

## Evidence quan sát

Tất cả lệnh dưới đây chạy trong checkout được lease, trừ npm test chạy tại thư mục npm-wrapper của checkout.

| Lệnh | Exit | Kết quả |
|---|---:|---|
| `node scripts/sync-release.mjs --check` | 0 | `Unified version (npm_v === skill_v)` / `1.0.0 === 1.0.0` / `PASS`; `PASS: All release surfaces coherent (skill v1.0.0, npm 1.0.0).` |
| `node scripts/sync-release.mjs --sync` rồi `--check` | 0 / 0 | `SUCCESS: All release surfaces are synchronized and coherent.`; không drift tracked metadata |
| `bash scripts/check-release-coherence.sh` | 0 | `PASS: release coherence` |
| `bash tests/test_release_coherence.sh` | 0 | `RESULT: 45 passed, 0 failed` |
| `bash tests/test_sync_release.sh` | 0 | `RESULT: 137 passed, 0 failed`; gồm canonical npm mirror drift repair và origin subtree fail-closed |
| `bash scripts/check-i18n-pairs.sh verify` | 0 | `PASS: i18n pairs (2)` |
| `bash scripts/check-doc-budgets.sh` | 0 | `PASS: doc budgets (6 files)` |
| `bash tests/test_doc_budgets.sh` | 0 | `RESULT: 8 passed, 0 failed` |
| `bash scripts/pack-rehearsal.sh` | 0 | `compare OK: 133 shouldShip files match`; `E2E RESULT: 22 passed, 0 failed`; `pack-rehearsal OK` |
| `bash scripts/release-preflight.sh` | 0 | `OK: skill product mirrors agree (1.0.0)`; `PREFLIGHT PASS`; không equality warning |
| `git diff --stat 794fd02` | 0 | Chỉ các file được parent cấp quyền |
| `git diff 794fd02 -- skills/ portable-manifest.json` | 0 | EMPTY; tree `604639b76e7ba3d7a41019c484f4c4c864c47967`; portable version vẫn 1.0.0 |
| `cmp plans/261025-0023-unified-version/decision.md /home/manhquy/Documents/flow-skill/plans/261025-0023-unified-version/decision.md` | 0 | EMPTY |
| `npm test` (cwd npm-wrapper) | 0 | `# tests 87`, `# pass 87`, `# fail 0` |
| `node --test tests/test_release_eligibility.mjs` | 0 | `# tests 22`, `# pass 22`, `# fail 0`; retained revision tree, missing/moving origin, new unified intent và legacy reconciliation |

Final acceptance battery: `artifact://7056` (full output), `artifact://7057` (stat); job bg_140 exit 0, 305.20s. Mọi lệnh nối bằng `&&` đều exit 0. Pack/preflight trước đó: `artifact://7022`; boundary evidence trước đó: `artifact://7026`.

## Review và giới hạn

Review follow-up: canonical `skills/flow/SKILL.md` version được mirror vào npm package bởi `--sync`; origin skill tag phải hiện diện, stable và có subtree giống release revision. Ship so HEAD; reconciliation so retained provenance-bound SHA, không dùng HEAD mới hơn. New intent phải có hai version bằng nhau; legacy null chỉ được đọc trong reconciliation. ADR có amendment tương ứng. Tests dùng local fixtures/mocked publisher; không phải live publication. Preflight đọc registry live thấy latest 0.8.0 nên warning trước phát hành là đúng; durable DB chưa khởi tạo là optional warning. Parent chịu trách nhiệm independent QA exact final SHA.

Journal ghi tại report path được parent cấp thay vì CLI journal mặc định ngoài allowlist. AgentWiki publish skipped. Không tạo service/port dài hạn; parent giữ quyền đóng lifecycle/worktree.

## Post-PR89 master integration

Merged exact master `87ac25f35ce5178d168bf0afebf5a2461753fae9` into the leased branch; automatic merge không có conflict. `AGENTS.md:68` giữ one shared SemVer wording. Scoped battery job `bg_141` exit 0 (270.06s): `node scripts/sync-release.mjs --check` hiển thị `1.0.0 === 1.0.0 PASS`; `bash scripts/check-release-coherence.sh` → `PASS: release coherence`; `bash tests/test_release_coherence.sh` → `RESULT: 45 passed, 0 failed`; `bash tests/test_sync_release.sh` → `RESULT: 137 passed, 0 failed`; `bash scripts/check-i18n-pairs.sh verify` → `PASS: i18n pairs (2)`; `bash scripts/check-doc-budgets.sh` → `PASS: doc budgets (6 files)`; `bash tests/test_doc_budgets.sh` → `RESULT: 8 passed, 0 failed`; `npm --prefix npm-wrapper test` → 87 passed, 0 failed. Từng lệnh nối bằng `&&`, tất cả exit 0. Parent ủy quyền push riêng branch này; không tạo PR hoặc tag.

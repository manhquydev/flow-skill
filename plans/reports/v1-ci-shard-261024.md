# Ubuntu bash-suite sharding — V1-CI-SHARD-261024

## Phạm vi và nguồn

- Lease: `V1-CI-SHARD-261024`; checkout `/home/manhquy/Documents/flow-skill/.omp/flow-maintenance/worktrees/v1-ci-shard-261024`, branch `flow/v1-ci-shard-261024`, base `526fcbbc1832dbd2473939237db1ff61577dcf97`. Đã quan sát cwd, HEAD, branch, status sạch và remote `https://github.com/manhquydev/flow-skill.git` trước sửa. Canonical `LIFECYCLE.json` đã có đúng owner/base/allowlist khi đọc lại.
- Chỉ sửa `.github/workflows/ci.yml` và báo cáo này. Không sửa manifest, runner, harness, assertions, Eval STOP, timeout hoặc matrix Windows/macOS. Không push, tạo PR hay gọi Claude live.
- Lỗi đã được chứng minh trong [nghiên cứu vận hành](researcher-261023-2348-operation-health.md#chẩn-đoán-hữu-hạn-ubuntu-ci-vượt15phút): run `39989247790`, Ubuntu job `120536419473` bị hủy ở 15 phút, sau 65 suite xanh tốn 853s; chưa đủ bằng chứng kết luận `test_sync_release.sh` treo. Full serial không còn headroom, không phải assertion được phép bỏ.
- Timing CI dùng log tại `plans/reports/evidence-261023-2348-omp-operation/{base-ubuntu-job.log,ubuntu-job.log,suite-timing-comparison.json}` trong checkout gốc. Log baseline run `39902051551`, Ubuntu job `120245597120` hoàn tất 77 suite, tổng timer suite 599s.

## Profile patch interpreter probe reuse

Đã đọc đúng lệnh được giao, chỉ đọc diff trong checkout runner:

```text
git -C /home/manhquy/Documents/flow-skill/.omp/flow-maintenance/worktrees/v1-runner-261023 diff -- skills/flow/runner/flow.sh tests/test_flow_graph_planning_parity.sh
```

Patch giữ `_FLOW_PYTHON` trong một CLI invocation sau probe Python/sqlite3 thật, reset khi source/startup để giá trị inherited không bypass probe, bỏ hai probe `--version` dư. Test patch thêm kiểm tra harness hỏng, sqlite3 thiếu, interpreter inherited không đáng tin, một probe/invocation và trạng thái graph mới vẫn được đọc. Không cache graph/session/gate state. Không tích hợp patch vào lane này.

Môi trường đo thật: Linux x64, Bash 5.3.9, Python 3.14.4, Node 22.22.1; `TZ=Asia/Bangkok LANG=en_US.UTF-8 PYTHONDONTWRITEBYTECODE=1`. Mỗi suite deadline 180s, chạy tuần tự theo thứ tự baseline1, patched1, baseline2, patched2, baseline3, patched3; không chạy hai biến thể song song. Bytecode bị tắt để không ghi checkout runner; dữ liệu test ở sandbox tạm của suite.

| Biến thể | Run 1 (s) | Run 2 (s) | Run 3 (s) | Median (s) | Assertions mỗi run |
|---|---:|---:|---:|---:|---|
| Baseline sạch, `526fcbbc...` | 57.440 | 57.826 | 57.376 | 57.440 | 167 passed, 0 failed |
| Runner patch giữ nguyên, HEAD `3930589cef2009556a9f4a3ad86e6878b479dfa2` + dirty diff | 48.884 | 49.238 | 49.089 | 49.089 | 187 passed, 0 failed |

Chênh median quan sát: **8.351s, giảm 14.54%** dù suite patched có thêm 20 assertions. Baseline1 dùng `/usr/bin/time -p timeout 180 env ... bash tests/test_flow_graph_planning_parity.sh`; năm run còn lại dùng `subprocess.run(..., timeout=180)` và `time.monotonic()`; stdout/result/rc được giữ trong native tool output (`bg_71`, `bg_72`).

**Giới hạn attribution:** đây là so sánh hai checkout theo yêu cầu, không phải A/B chỉ đổi đúng patch. Committed runner và planning test giống nhau giữa hai HEAD, nhưng harness có delta `_db.py` (migration backup) và `graph_executor.py` (fork checkpoint ordering); test patched cũng khác. Không thể gán toàn bộ 14.54% cho probe reuse. Các assertions mới đã quan sát đúng một capability probe và một harness-help probe trong mỗi invocation, là bằng chứng hành vi trực tiếp bổ sung, không phải Windows performance closure.

**Khuyến nghị tích hợp:** parent nên giữ patch như một candidate độc lập và tích hợp qua đường sở hữu runner sau review trên base canonical mới, chạy lại runtime-refusal/planning/graph checks và exact-head đa OS. Không cần chờ patch để shard Ubuntu: cấu hình dưới đây được định cỡ theo runner **chưa patch**. Không cherry-pick/reset/stage/commit checkout runner trong lane này.

Định danh SHA-256 lúc đo:

| Input | SHA-256 |
|---|---|
| Runner patched `skills/flow/runner/flow.sh` | `cdba34ac4bc2480f187e250ac69e11219faefd23a54eb794516d28fcf48d2cac` |
| Planning suite patched | `78776d51f8776a6476ad7e07a0a0bd5c1a4d6312ff29ea8dfba5c4edfe8940a8` |
| Runner baseline | `edccc5f090c3cf728fb1a0ae490236e97a1537a996bdd75e36a6ad068be6011d` |
| Planning suite baseline | `ff17410ebe46b2c4dc70bef669838be4a4d1318f4099ddae2f81effea606fda1` |
| Manifest không đổi | `7e32269b1da2331d5c7cd1c29402143a6a2d388e93d2cc858d468c6f170a3890` |

## Chọn N = 3 từ timing từng suite

Parse tất cả dòng `---- <suite> wall_s=<seconds> ----` trong hai log CI. Ưu tiên 65 timing current; 12 suite tail chưa hoàn tất ở current dùng timing baseline. Đủ 77/77 input, không thiếu suite. Tổng ước lượng serial 979s > 900s ngay trước setup/cleanup.

`tests/run_all.sh` đã định nghĩa partition: lọc comment/blank/CR, `LC_ALL=C sort`, ordinal 1-based; suite thuộc shard `((ordinal - 1) % N) + 1`. Tái dùng nguyên support hiện hữu, không thêm danh sách sở hữu thứ hai hoặc sửa manifest.

| N | Tổng lịch sử theo shard (s) | Shard lớn nhất | Nhận định |
|---|---|---:|---|
| 2 | 339 / 640 | 10m40s | Không đủ headroom khi runner chậm hoặc tail release dài hơn |
| **3** | **350 / 367 / 262** | **6m07s** | Cân bằng hơn, mỗi shard còn hơn 8 phút trước timeout |
| 4 | 181 / 373 / 158 / 267 | 6m13s | Thêm runner nhưng shard lớn nhất không nhanh hơn N=3 |

| Shard Ubuntu | Suite count | CI suite projection | Planning envelope: 1.5 × projection + 60s setup/cleanup |
|---|---:|---:|---:|
| `1/3` | 26 | 350s (5m50s) | 585s (9m45s) |
| `2/3` | 26 | 367s (6m07s) | 610.5s (~10m11s) |
| `3/3` | 25 | 262s (4m22s) | 453s (7m33s) |

Projection/envelope là **[INFERENCE]**, không phải thời gian Ubuntu live của commit mới. Hệ số 1.5 và 60s là headroom lập kế hoạch tường minh, không phải số overhead được đo. Tail `test_sync_release.sh` 115s là baseline cũ nên cần theo dõi exact-head CI thật.

## Partition chính xác

Các cột là ba subsequence của cùng một danh sách C-sorted; ô trống cuối bảng không phải suite bị bỏ.

| `1/3` | `2/3` | `3/3` |
|---|---|---|
| test_doc_budgets.sh | test_eval_fixture_lint.sh | test_flow_accessed_count.sh |
| test_flow_antigravity_integration.sh | test_flow_assess.sh | test_flow_attestation_contract.sh |
| test_flow_attestation_harden.sh | test_flow_attestation_supervisor.sh | test_flow_attestations.sh |
| test_flow_auto_attestation_enforcement.sh | test_flow_auto_done_path.sh | test_flow_card_lifecycle.sh |
| test_flow_card_risk.sh | test_flow_claudekit_integration.sh | test_flow_codex_integration.sh |
| test_flow_coherence_kb.sh | test_flow_concierge.sh | test_flow_concurrency_lock.sh |
| test_flow_consistency.sh | test_flow_constitution.sh | test_flow_contract.sh |
| test_flow_converge.sh | test_flow_coverage_gaps.sh | test_flow_doctor.sh |
| test_flow_done_evidence.sh | test_flow_eval.sh | test_flow_forge_idea.sh |
| test_flow_gate_capture.sh | test_flow_gate_wording.sh | test_flow_graph_auto_run.sh |
| test_flow_graph_crash_resume.sh | test_flow_graph_executor.sh | test_flow_graph_lint.sh |
| test_flow_graph_parallel_cards.sh | test_flow_graph_planning_parity.sh | test_flow_graph_schema.sh |
| test_flow_harness.sh | test_flow_harness_args.sh | test_flow_harness_lineage_contract.sh |
| test_flow_harness_strict.sh | test_flow_harness_trust_complete.sh | test_flow_host_agnostic_parallel.sh |
| test_flow_host_hooks.sh | test_flow_journal.sh | test_flow_loop.sh |
| test_flow_midtier_scanners.sh | test_flow_monorepo_root.sh | test_flow_native_rituals.sh |
| test_flow_open_decisions.sh | test_flow_parallel_auto.sh | test_flow_project_types.sh |
| test_flow_propose_audit.sh | test_flow_recall.sh | test_flow_resume.sh |
| test_flow_rules.sh | test_flow_runner.sh | test_flow_scenarios.sh |
| test_flow_schema_migration.sh | test_flow_skill_harness_docs_contract.sh | test_flow_slice_quality.sh |
| test_flow_status_legibility.sh | test_flow_tokens.sh | test_flow_tool_registry.sh |
| test_flow_usage_log.sh | test_flow_windows_lifecycle.sh | test_flow_workspace.sh |
| test_harness_cli_optional_smoke.sh | test_i18n_pairs.sh | test_install_safe_update.sh |
| test_manifest_runner.sh | test_release_coherence.sh | test_release_dispatch_response.sh |
| test_release_eligibility.sh | test_release_provenance.sh | test_release_run_artifact.sh |
| test_sync_release.sh | test_verify_attestation_with_gh.sh | |

## Review cấu hình và rủi ro

Observed structural check so sánh workflow với base bằng Python/subprocess: Ubuntu chính xác `1/3,2/3,3/3`; Windows vẫn `1/3,2/3,3/3`, macOS vẫn `full`; mọi dòng `timeout-minutes` giữ nguyên. Toàn bộ bytes từ `steps:` của `bash-suite` đến cuối workflow giữ nguyên, gồm `FLOW_SUITE_SHARD`, PowerShell chỉ Windows `1/3`, và `all-checks-passed` vẫn `needs: [bash-suite, python-required-refusal, test, pack-rehearsal, eval-replay]` với `if: always()`. Matrix fail-fast vẫn false. Mọi shard đều phải thành công; không có đường bỏ coverage hay nới gate.

Rủi ro còn lại: setup lặp trên hai Ubuntu job bổ sung; lịch queue/concurrency GitHub có thể giảm lợi ích wall clock; suite mới có thể thay đổi round-robin membership/load. Không có duration-based hardcoded routing để phải duy trì. Linux local không chứng minh Windows assertion closure hoặc Ubuntu exact-head CI xanh. Parent giữ trách nhiệm independent review, tích hợp một PR85, push và exact-head CI; lane không tự phê duyệt sản phẩm.

Automatic journal preference trả `true`, nhưng journal riêng ngoài writable allowlist nên không tạo file; phần diễn biến/decision được ghi ngay trong báo cáo được cấp quyền này. Không thay global preference.

## Kiểm chứng local trên toàn bộ partition

Đã chạy **mỗi lệnh shard đúng một lần**, tuần tự, trên source baseline chưa tích hợp probe patch; mỗi subprocess có deadline 900s. Không cần chạy thêm full serial vì ba shard đã thực thi toàn bộ manifest. Lệnh thực tế dùng environment chung `TZ=Asia/Bangkok LANG=en_US.UTF-8 PYTHONDONTWRITEBYTECODE=1`:

```bash
FLOW_SUITE_SHARD=1/3 bash tests/run_all.sh
FLOW_SUITE_SHARD=2/3 bash tests/run_all.sh
FLOW_SUITE_SHARD=3/3 bash tests/run_all.sh
```

| Shard | Observed monotonic wall (s) | Runner TOTAL (s) | Suite count | Exit | Kết quả |
|---|---:|---:|---:|---:|---|
| `1/3` | 493.382 | 494 | 26 | 0 | ALL SUITES PASSED |
| `2/3` | 463.900 | 463 | 26 | 0 | ALL SUITES PASSED |
| `3/3` | 274.662 | 275 | 25 | 0 | ALL SUITES PASSED |

Native output đầy đủ: `artifact://5978` (4,745 dòng), execution `bg_76`; stdout giữ cả từng suite, assertions và `wall_s`. Timer runner theo giây lịch nguyên nên có thể lệch dưới một giây so với monotonic. Thời gian serial-equivalent của ba command là 1,231.944s (~20m32s), xác nhận không thể dựa vào full job 15m trên host local này. Shard lớn nhất chỉ ~8m14s; nếu ba runner được cấp cùng lúc, đây là critical path suite local, không phải quan sát GitHub live.

Đã đối chiếu **danh sách suite thật được runner in ra** với subsequence dự kiến ở mỗi shard, không chỉ chứng minh bằng công thức. Counter của union cho kết quả:

```json
{"manifest_count":77,"executed_count":77,"unique_count":77,"missing":[],"extra":[],"duplicates":{}}
```

`shard_exit_codes=[0,0,0]`; mỗi shard `selected_exactly_expected=true`. Suite `test_manifest_runner.sh` cũng đã chạy ở `1/3`, gồm contract sorted/CRLF/reordered manifest, exact-once union, malformed/empty shard fail-closed và propagation khi suite lỗi. `test_doc_budgets.sh` đã xanh trong shard `1/3`.

Local per-suite đáng chú ý: `test_sync_release.sh` **247s**, 133 passed/0 failed; `test_flow_eval.sh` **228s**, 270 passed/0 failed. Đây là lý do không dùng riêng baseline tail 115s hoặc current eval 149s để hứa thời gian thực. Chúng nằm ở **hai shard khác nhau**. Root cause vận hành là serial critical path vượt budget; sharding phân tách workload thật, không sửa/suppress assertion và không tăng timeout. Lane này không xác nhận hay sửa các lỗi assertion Windows do lane A sở hữu.

### Projection cập nhật bằng local timings

Expected Ubuntu suite wall được ước lượng bảo thủ bằng `max(CI projection, local runner TOTAL)`; envelope là `1.25 × expected + 60s` setup/cleanup. Các giá trị dưới đây vẫn là **[INFERENCE]**, cần CI exact-head xác minh, không phải SLA hoặc guarantee:

| Shard | Expected suite wall | Envelope | Headroom trước 900s |
|---|---:|---:|---:|
| `1/3` | 494s (8m14s) | 677.5s (~11m18s) | 222.5s (~3m43s) |
| `2/3` | 463s (7m43s) | 638.75s (~10m39s) | 261.25s (~4m21s) |
| `3/3` | 275s (4m35s) | 403.75s (~6m44s) | 496.25s (~8m16s) |

Các envelope CI lịch sử ở trên chỉ là estimate trước khi có local evidence; bảng này là recommendation cuối cùng. N=3 vẫn đủ: đo thật từng shard xanh, runner unpatched, không có shard nào tới 9m. N=2 có historical hot shard 640s và workload eval tăng 79s, release tăng 132s; chưa có lý do chọn partition ít headroom hơn. N=4 không có lợi ích historical max để bù runner thứ tư.

SHA-256 runner patch và suite patched đã được đọc lại sau cả sáu profile run: khớp chính xác bảng input; status runner vẫn chỉ đúng hai modified path ban đầu. Manifest cũng giữ nguyên SHA-256. Không có process/service dài hạn hoặc port được giữ; job đo hữu hạn đã kết thúc.

Final scoped check: `bash scripts/check-doc-budgets.sh` trả exit 0, `PASS: doc budgets (6 files)`; output tại `artifact://5991`. Trước commit, HEAD vẫn đúng `526fcbbc1832dbd2473939237db1ff61577dcf97`, branch đúng lease; status chỉ workflow modified và báo cáo untracked. Diff workflow là 8 additions/4 deletions, giới hạn matrix Ubuntu và comment giải thích liên quan. Không có test/product callsite cần migrate vì đã tái dùng `FLOW_SUITE_SHARD` hiện hữu.

Inline review không phát hiện regression trong phạm vi matrix; independent QA chưa được lane này thực hiện vì không có quyền spawn. Các completion `bg_71`, `bg_72`, `bg_76`, `bg_78` đều hữu hạn và đã nhận kết quả; không còn PID/port giữ lại. Parent có thể nhận quyền tiêu thụ branch/commit, nhưng giữ checkout và branch tới operational closure; không tự xóa lease.

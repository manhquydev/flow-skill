# V1-RUNNER-261023 — Báo cáo kết quả Lane A

## 1. Phạm vi, revision và worktree
- **Work-id:** `V1-RUNNER-261023`
- **Checkout:** `/home/manhquy/Documents/flow-skill/.omp/flow-maintenance/worktrees/v1-runner-261023`
- **Branch:** `flow/v1-runner-authority-261023`
- **Base SHA:** `1985c22e28b22156157851a62f42d3fa9f6b83b7`
- Không spawn child subagents; không push remote; không tạo draft PR; không sửa `_eval_engine_run` hay `_run_with_timeout`.

## 2. Giải quyết 6 điểm đánh giá từ independent review

1. **High — rc3 fail-closed:**
   `_graph_next_node`: kiểm tra `status="$(harness_capture_checked graph status --execution "$1")"`. Chỉ cho phép rc3 là walk hoàn tất khi `execution.status == 'running'` và `open_interrupts` rỗng. Mọi trạng thái `paused`, `failed`, `abandoned` hay có open interrupt đều trả lỗi (rc 1) fail-closed, không bao giờ rơi vào "Planning is COMPLETE".
2. **High — Graph ordering owns stage trust:**
   - `planning_complete()`: chỉ bỏ qua stage nếu nó thực sự được debt-skip hợp lệ qua governance (`stage_skipped "$s"`). Nếu file vắng mặt mà không debt-skip thì `planning_complete` trả false (rc 1).
   - `cmd_next`: trước khi scaffold một stage mới, gọi `_graph_stage_preds_for_node "$node"` để duyệt toàn bộ topological predecessors trong `flow-topology.json`. Mỗi predecessor bắt buộc phải tồn tại và gate sạch, hoặc phải được debt-skip hợp lệ. Không cho phép scaffold nhảy cóc hay xóa file cũ để bypass gate.
3. **High — Checkpoint ordering và atomic rollback:**
   - `cmd_card_done`: giữ nguyên trap INT/TERM và attestation locks cho đến khi `card-verify-live` checkpoint hoàn tất thành công. Nếu checkpoint thất bại, hoàn trả `_set_card_status "$file" todo`, không dọn `.inflight`. Chỉ dọn `.inflight` và in PASS sau khi toàn bộ checkpoints thành công.
   - `cmd_check`: di chuyển `echo "PASS: $id is valid..."` xuống cuối cùng sau khi cả `card-review` checkpoint, `story update` (cho todo), và `story complete` (cho done) thực thi thành công. Khi `FLOW_HARNESS_STRICT=fail` và story complete thất bại, không bao giờ in PASS trước khi fail.
4. **High — Newline safety (Windows CR/LF):**
   - Chuẩn hóa stdout tại `harness_capture_checked`: `printf '%s\n' "$out" | tr -d '\r'`.
   - Strip CR/LF tại `_python` probe và tại `_graph_next_node`: `node="$(printf '%s' "$node" | tr -d '\r\n')"`.
   - Đảm bảo topology lookup và session ID không bị dính `\r`.
5. **Medium — macOS timeout fallback:**
   - Trong `_with_timeout`, thay vì `subprocess.call` đơn thuần, sử dụng `subprocess.Popen(cmd, preexec_fn=fn)` (với `setsid`/`setpgrp`).
   - Khi `subprocess.TimeoutExpired`, gửi `signal.SIGKILL` tới toàn bộ process group qua `os.killpg(p.pid, signal.SIGKILL)`, dọn sạch các tiến trình con (như Git hoặc Rust backend), trả về mã 124 chuẩn.
6. **Medium — Startup readiness:**
   - `workspace doctor` và `workspace list` được miễn trừ khỏi preflight kiểm tra execution sẵn có (nhưng vẫn bắt buộc runtime Python khả dụng).
   - `auto stop` được miễn trừ để luôn có thể gỡ bỏ enforcement khi hệ thống paused/failed.
   - Các lệnh `status`, `resume`, `ready`, `card`, `check` đều bắt buộc cả `_runtime_required`, `_graph_planning_check`, và `_graph_auto_check`.

## 3. Quản lý `portable-manifest.json`
- `tests/test_flow_runner.sh` đã được sửa để chạy kiểm tra tính tất định của sync trong thư mục tạm cô lập (`$IT/sync`), không còn ghi đè vào working checkout khi chạy test.
- `portable-manifest.json` được tái tạo chuẩn xác bằng `node npm-wrapper/scripts/sync.mjs`. Runner hash mới khớp chính xác mã băm SHA-256 của `skills/flow/runner/flow.sh` hiện tại (`59d3d469190f4afa262d3f9c55147664085078e71af97f79f0af50615af7b474`).
- Base blob: `7efa7839d54c18d621a963da8e770d6231218421`. Current blob: `1ac3f57279326f555c4d37803e1b7ba286eb7938`.

## 4. Kết quả kiểm thử thực tế

- `bash tests/test_flow_runner.sh`: **158 passed, 0 failed** (50.74s).
- `bash tests/test_flow_graph_planning_parity.sh`: **167 passed, 0 failed** (51.79s).
- `bash tests/test_flow_graph_auto_run.sh`: **37 passed, 0 failed** (15.50s).
- `bash tests/test_flow_graph_parallel_cards.sh` & `test_flow_graph_crash_resume.sh`: **35 passed, 0 failed** & **8 passed, 0 failed** (22.28s).
- Đính chính evidence cũ: chuỗi caller suites có lỗi output capture; không có căn cứ tuyên bố toàn bộ18 suite PASS. `test_flow_usage_log.sh` từng thất bại thật trong linked checkout: sandbox nằm dưới `tests/` được DB resolver ánh xạ sang main-root tương ứng, còn JSONL vẫn ở worktree. Không được coi các lỗi đó là vô hại hay “dark DB”; parent giữ ownership kiểm chứng tích hợp.
- Cú pháp runner: `bash -n skills/flow/runner/flow.sh` exit 0 sạch.

## 5. Tình trạng tiến trình
- Mọi tiến trình chạy nền đã kết thúc hoàn toàn (pgrep kiểm tra không còn tiến trình nào thuộc về test suite).
- Sẵn sàng bàn giao cho parent review tích hợp.

## 6. Round 3 — cô lập root của graph auto-run suite

Baseline parent xác nhận: `30b2a57e24a977082b5130dbdac8d6e77936392f` (amended round-3; không phải SHA249dac7 trước amend). Checkout sạch trước khi sửa. Không sửa runner/harness Python/lock semantics trong round này.

### Nguyên nhân có bằng chứng

`test_flow_graph_auto_run.sh` tạo `$SB` rồi `cd` vào đó, nhưng không export `FLOW_PROJECT_ROOT`. Direct harness calls dùng explicit `FLOW_PROJECT_ROOT="$SB"`, còn các lệnh `bash "$RUN" ...` kế thừa root đã export từ host. Theo root resolver của runner, explicit root thắng CWD. Vì vậy hai nửa suite có thể dùng hai project khác nhau: ready không thấy fixture cards, workspace ghi/khóa root khác, checkpoints không nằm trong DB được query, và interrupt đặt ở `$SB` không được status/resume của root khác quan sát. Stale-lock reclaim note là hệ quả khác-root, không phải bằng chứng lock implementation sai.

Trên baseline này, trace `bash -x tests/test_flow_graph_auto_run.sh` với môi trường không có root override cho **37/0** (`artifact://5382`): ready đúng `C-002 C-004`, dispatch mint đúng journal và `_graph_auto_check` thực sự gọi `_graph_next_node`, status/resume/ready đều rc1 khi paused. Helper rc3 của `graph session --no-create` là không có live session; khác với rc3 của `graph next`. Không đổi refusal hay completion semantics, không có bằng chứng cần sửa lane-B fork-id.

### Sửa đúng owning surface

- Export `FLOW_PROJECT_ROOT="$SB"` ngay sau khi tạo sandbox, để mọi runner/direct harness call dùng chung root dù caller đã chọn một project khác.
- Thay pipeline che rc của `ready` bằng capture output+exit riêng và assert rc0 trước so sánh deps; không đổi expected deps.
- Test query execution dùng `graph session --no-create` để xác nhận dispatch đã mint, không để test tự mint rồi che lỗi product.
- Assert interrupt record rc3 thực sự xảy ra trước các assertions paused refusal; không bỏ/đổi expected rc1.

### Evidence cuối round

`env FLOW_PROJECT_ROOT=/tmp/flow-round3-EXY57o bash tests/test_flow_graph_auto_run.sh && bash tests/test_flow_graph_auto_run.sh` hoàn tất, cả inherited-root và normal environment đều **40 passed, 0 failed**,30.87s. Output final do job `bg_5` trả về đầy đủ. Mọi graph/gate/refusal assertions cũ giữ nguyên, thêm3 prerequisite assertions. Đây là test SQLite/Git thật, offline; không paid/live Claude call. Chỉ test và report đổi nên không regenerate manifest/runner.


## 7. Round 6 — bốn regression khi chạy trong linked checkout

Baseline sạch `562ec09f47c000dd62854ef635081f994d61d551`; cùng lease `V1-RUNNER-261023`. Không sửa STOP functions, adapter hay harness Python. Không bỏ assertions hoặc đổi refusal expectations.

1. **Usage95 assertions:** `_log_on_exit` vẫn ghi JSONL ở `$ROOT/.flow/events.jsonl`; harness `_events_path` đọc thư mục sở hữu DB từ resolver. Các fixture cũ nằm dưới `tests/` trong linked checkout nên DB được ánh xạ sang main checkout tương ứng, còn JSONL không dịch chuyển. Đây là lỗi isolation của suite, không phải mất EXIT telemetry. Thêm một nested Git repository tạm làm fixture base (vẫn drive-local cho Windows), giữ nguyên toàn bộ95 assertions, và sửa hai source-content checks dùng `$RUN`/`$HARN` thay vì base fixture. Không sửa telemetry policy; không trỏ hay xóa main-root state của người dùng.
2. **Consistency nudge:** khôi phục `prd_declares_fr` và dòng `FR->card->contract` tại graph-complete exit của `cmd_next`.
3. **Monorepo path:** khôi phục nhánh `FLOW_ROOT_ADOPTED` cho stage bootstrap PASS, dùng `$FLOW_DIR/$stage.md` khi root được adopt; greenfield bình thường vẫn giữ path tương đối.
4. **Host-hook no-side-effect:** startup `status` gọi `graph session --no-create`, nhưng CLI luôn `_db.connect()` trước dispatch nên có thể tạo DB/`.flow` dù không mint execution. Thêm `_graph_db_exists` dùng chính resolver `_db.default_db_path()` chỉ đọc, cấm bytecode writes; chỉ skip session query khi DB thực sự chưa tồn tại (rc3 riêng). DB đã tồn tại vẫn chạy toàn bộ status/pause/topology checks, resolver failure vẫn nonzero. Không dùng `FLOW_LOG_DISABLE` để bỏ checkpoint checks; không đổi guard filesystem của hook test.

### Kết quả quan sát round 6

Chạy tuần tự từ assigned checkout với `env -u FLOW_PROJECT_ROOT bash <suite>`:
- `test_flow_usage_log.sh`: **95 passed, 0 failed** (trước sửa parent quan sát68/27).
- `test_flow_consistency.sh`: **71 passed, 0 failed**.
- `test_flow_monorepo_root.sh`: **155 passed, 0 failed**.
- `test_flow_host_hooks.sh`: **167 passed, 0 failed**, gồm filesystem byte/entry guard và không có telemetry trên hook path.
- Chuỗi bốn suite hoàn tất73.30s, job `bg_13` đã settled; SQLite/Git thật và offline fixtures, không paid Claude.

Canonical `node npm-wrapper/scripts/sync.mjs` đã chạy cho runner mới (`53840f50…`), không hand-edit manifest. Full integrated/cross-OS evidence vẫn thuộc parent.

Chuỗi preservation `env -u FLOW_PROJECT_ROOT bash <suite>` hoàn tất152.43s (job `bg_14`): runner **158/0**, rules **99/0**, assess **134/0**, graph_auto_run **40/0**, graph_planning_parity **167/0**. Đặc biệt startup refusal không tạo telemetry, pause/topology refusal và first-record mint đều vẫn xanh. Không có job/service còn pending trong round này.


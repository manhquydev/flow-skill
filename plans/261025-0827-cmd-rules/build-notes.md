# CMD-RULES-261025 — bằng chứng triển khai

- Owner/lease: `CmdRulesBuilder`, `CMD-RULES-261025`.
- Branch: `flow/cmd-rules-261025`.
- Base: `87ac25f35ce5178d168bf0afebf5a2461753fae9`.
- Worktree: `.omp/flow-maintenance/worktrees/cmd-rules-261025`.
- Không push, không PR; không tích hợp trước khi PR91 publish.

## Phạm vi và nguyên nhân

Tám rule templates cố định đường dẫn source-repo, không tồn tại trong user project dùng global/project-local install. `cmd_rules()` hiện giữ đường dẫn tương đối nếu runner đó tồn tại trong project; nếu không, dùng `$SCRIPT_DIR/flow.sh` tuyệt đối và Bash `%q`. Roo nhận regex đã escape và JSON-encode; Aider nhận shell program đã quote và JSON-encode (hợp lệ trong YAML double-quoted scalar). `agent-skills` giữ nguyên prerequisite canonical bundle. Cập nhật tài liệu tại `skills/flow/references/command-dispatch.md`.

## Red trước khi sửa runner

Lệnh: `bash tests/test_flow_rules.sh`.

Fixture đầu tiên chỉ copy `runner/` thiếu runtime nên đã sửa fixture thành copy bundle đầy đủ, trước mọi thay đổi production. Lần red có ý nghĩa:

```text
J) installed runner scaffolds a command that resolves in the user project
  ok   [installed runner scaffolds Cursor rules]
AssertionError: scaffolded runner does not resolve: skills/flow/runner/flow.sh
  FAIL [installed template runner paths exist from project root] expected '0' got '1'
RESULT: 100 passed, 1 failed
Command exited with code 1
```

## Kết quả quan sát sau sửa

Tất cả là kiểm tra offline trên Linux; global/project-local layouts là fixture mô phỏng, không phải thay đổi install thật. Không live Claude, không network/publish.

| Lệnh | Kết quả |
|---|---|
| `bash tests/test_flow_rules.sh` (sau lần chỉnh test cuối) | `RESULT: 128 passed, 0 failed` |
| `bash tests/test_flow_runner.sh` | `RESULT: 158 passed, 0 failed` |
| `bash tests/test_flow_graph_planning_parity.sh` | `RESULT: 174 passed, 0 failed` |
| `bash tests/test_flow_doctor.sh` | `RESULT: 84 passed, 0 failed` |
| `bash scripts/check-doc-budgets.sh` | `PASS: doc budgets (6 files)` |
| `bash tests/test_doc_budgets.sh` | `RESULT: 8 passed, 0 failed` |
| `bash -n skills/flow/runner/flow.sh tests/test_flow_rules.sh` | Exit 0; `RESULT: Bash syntax checks passed` |

Full scoped-runner/doc command output: `artifact://7162`. Rules coverage: cả tám harnesses trong source/global/local; đường dẫn có space, quotes, `$`, regex metacharacters; Roo regex khớp command đã phát; Aider thực thi status/check và chặn inflight injection; preview/no-overwrite/symlink invariants vẫn được kiểm tra.

Runner suite có warning `flow-harness: warn durable write failed (rc=1)` trong fixture card-start; assertions vẫn 158/0. Không thay đổi hành vi durable write.

## Eval STOP

Đã so sánh bằng Node `execFileSync("git", ["show", "87ac25f35ce5178d168bf0afebf5a2461753fae9:skills/flow/runner/flow.sh"])` với file hiện tại; trích từng function từ dòng khai báo đến `^}` và so sánh byte string. Đồng thời đếm regex `_run_with_timeout|_eval_engine_run` trên toàn bộ `git diff 87ac25f35ce5178d168bf0afebf5a2461753fae9 -- skills/flow/runner/flow.sh` (tương đương phép grep-count trong acceptance):

```text
RESULT: _run_with_timeout byte-identical sha256=394d70485b68e08d377050d938a5d8d1e3c5f8b602b0edf613050c9b916c65db
RESULT: _eval_engine_run byte-identical sha256=1ce8d071a3fc7c2dd86a47b71d3e4158656c537fc39dcd820a89417a8a3ee1a7
RESULT: Eval STOP references in runner diff = 0
```

## Review và giới hạn

Review nội bộ theo ak-code-review: kiểm tra escaping qua Bash/JSON/YAML/regex, source-repo compatibility, caller templates, no-write preview và STOP bodies. Không thực hiện independent review; parent sở hữu bước đó.

Ở vòng pre-cutover, parent xác nhận bỏ `bash scripts/pack-rehearsal.sh` vì prepack ghi `portable-manifest.json` bị cấm. Authorization post-cutover bên dưới thay thế giới hạn đó và đã hoàn tất rehearsal. Chưa thực thi macOS/Windows/Bash 3.2 thực; implementation chỉ dùng primitive Bash 3.2 có sẵn.

`ak config prefs resolve --json | jq -r 'if .prefs.journal.auto == false then "false" else "true" end'` trả về `true`. Không tạo automatic journal tại `plans/journals/` vì nằm ngoài write allowlist; ghi nhận lịch sử kỹ thuật tại build notes được parent cho phép này. AgentWiki publish skipped.

Không tạo service/port; job `bg_149` đã kết thúc. Bàn giao quyền sở hữu worktree cho parent sau commit; giữ nguyên checkout/branch để parent đóng lifecycle.

## Tích hợp post-cutover

Parent mở integration window sau PR91 và cho phép canonical generated sync, gồm runner hash trong `portable-manifest.json`, nhưng không đổi version surface. Đã chạy `git fetch origin master` rồi `git rebase 4f124970a9b72fd836acc34f8628846a28bbee86`; rebase sạch, không conflict. Không sửa master.

Acceptance trước sync ghi nhận rules 128/0, runner 158/0, budgets và i18n PASS; `node scripts/sync-release.mjs --check` chỉ báo runner hash mismatch (d29d1f6e so với 007273fd), tất cả version vẫn 1.0.0. Đã báo parent, rồi xử lý đúng canonical sync đã được cho phép, không chạy version synchronization.

Lệnh `node npm-wrapper/scripts/sync.mjs` tái tạo bundle gitignored và chỉ đổi tracked `portable-manifest.json` tại `hashes["skills/flow/runner/flow.sh"]`, từ `d29d1f6ea5e87aec7ca2755284a104e6bf1007251620d7a9b7bfa4a5f90a69e4` thành `007273fd2ee9213c7ee7777d0a6c6e31e01248b7a101e7aa94de99b43178bcbe`. Không unrelated drift, không sửa version/lockfile/CHANGELOG. Commit sync riêng: `855d601e644275cacc78d75aba9cbd429383131a`, `chore(sync): regenerate bundled skill for cmd-rules runner fix`.

| Lệnh sau rebase/canonical sync | Kết quả quan sát |
|---|---|
| `bash tests/test_flow_rules.sh` | `RESULT: 128 passed, 0 failed` |
| `bash tests/test_flow_runner.sh` | `RESULT: 158 passed, 0 failed` |
| `bash tests/test_flow_graph_planning_parity.sh` | `RESULT: 174 passed, 0 failed` |
| `bash tests/test_flow_doctor.sh` | `RESULT: 84 passed, 0 failed` |
| `bash scripts/check-doc-budgets.sh` | `PASS: doc budgets (6 files)` |
| `bash scripts/check-i18n-pairs.sh verify` | `PASS: i18n pairs (2)` |
| `node scripts/sync-release.mjs --check` | `PASS: All release surfaces coherent (skill v1.0.0, npm 1.0.0).` |
| `bash scripts/pack-rehearsal.sh` sau commit sync | `E2E RESULT: 22 passed, 0 failed`; `pack-rehearsal OK` |
| `git diff --exit-code` và `git diff --cached --exit-code` sau rehearsal | Exit 0, không generated writes pending |

Artifact của vòng rebase: `artifact://7236`; rehearsal: `artifact://7239`; graph/doctor/integration checks: `artifact://7242`. Rules/runner đã chạy trên code sau rebase; canonical sync sau đó chỉ đổi manifest hash, không thay test inputs hoặc runner bytes. Rehearsal xác minh tarball parity 133 files, runner/receipt hash, project-local install và doctor clean/tamper/restored.

So sánh Node với base post-cutover `4f124970a9b72fd836acc34f8628846a28bbee86` xác nhận `_run_with_timeout` và `_eval_engine_run` byte-identical. So sánh allowlist committed paths và manifest JSON loại bỏ duy nhất runner hash xác nhận không version surface/unrelated drift.

Các jobs `bg_159`, `bg_160`, `bg_161` đều kết thúc; không service/port. Parent cho phép normal push duy nhất branch `flow/cmd-rules-261025`, không PR/merge/release; exact remote HEAD sẽ có trong final handoff.

## PR93 — sửa regression Bash 3.2

Parent báo macOS CI: rules 120 passed/8 failed, trong khi Ubuntu/Windows green. Không chạy lại CI chỉ để xác nhận lỗi đã báo. Tài liệu cài trên host `/usr/share/doc/bash/COMPAT.gz` (đọc bằng `gzip -cd`) item 52 xác nhận Bash 4.3 mới thêm quote removal cho pattern replacement; phần `compat42` ghi rõ phiên bản cũ giữ quotes. Micro-check `BASH_COMPAT=32` của `${v//@RUN@/"$repl"}` phát literal `"bash ..."`. Cùng micro-check cho replacement variable không quote phát hiện Bash 5.3 `patsub_replacement` mặc định thay `&` bằng matched token. Parent duyệt literal prefix/suffix replacement để tránh cả hai version splits.

Loại bỏ toàn bộ bốn pattern-substitution contexts được thêm trong nhánh. Aider program ghép bằng `printf -v`; template rendering dùng loop prefix/suffix expansion và biến replacement, không eval hay dependency mới. Test thêm POSIX `sh`/`grep` assertion rằng sáu Markdown templates không chứa literal `"bash `, exact runner path round-trip (bao gồm `&` trong global fixture), Aider command prefix/exact runner, giữ Roo JSON parse/regex tests. `required harness missing` assertion của hostile inflight lại pass trong cả Bash thường lẫn compat32; không có lỗi độc lập cần workaround.

Full local acceptance, output `artifact://7269`:

| Lệnh | Kết quả |
|---|---|
| `bash tests/test_flow_rules.sh` | `RESULT: 131 passed, 0 failed` |
| `BASH_COMPAT=32 bash tests/test_flow_rules.sh` | `RESULT: 131 passed, 0 failed` (mô phỏng compatibility, không phải binary Bash 3.2 thật) |
| `node npm-wrapper/scripts/sync.mjs` | Sync 133 files; runner hash `899b3b209f84cd30481944f94eb7a950c323ab1f57f233844c2e4797811a6f95` |
| `bash tests/test_flow_runner.sh` | `RESULT: 158 passed, 0 failed` |
| `bash tests/test_flow_graph_planning_parity.sh` | `RESULT: 174 passed, 0 failed` |
| `bash tests/test_flow_doctor.sh` | `RESULT: 84 passed, 0 failed` |
| `bash scripts/check-doc-budgets.sh` | `PASS: doc budgets (6 files)` |
| `bash scripts/check-i18n-pairs.sh verify` | `PASS: i18n pairs (2)` |
| `node scripts/sync-release.mjs --check` | `PASS: All release surfaces coherent (skill v1.0.0, npm 1.0.0).` |
| `bash scripts/pack-rehearsal.sh` | `E2E RESULT: 22 passed, 0 failed`; `pack-rehearsal OK` |
| `bash -n skills/flow/runner/flow.sh tests/test_flow_rules.sh` | Exit 0 |

STOP bodies byte-identical với HEAD trước sửa. Audit executable `cmd_rules` không còn quoted pattern replacements, `@Q`, associative arrays, lowercase expansion, `mapfile`, negative substring offsets. Lần audit đầu match nhầm ví dụ `${v//p/"$r"}` trong explanatory comment; đã loại comment khỏi audit, không sửa code để né check. Không version surface changes; chỉ canonical runner hash thay đổi trong manifest. Job `bg_164` đã kết thúc, không service/port. Actual macOS/Bash 3.2 CI vẫn thuộc parent.

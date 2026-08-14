---
title: flow upgrade wave1 shipped
date: 2026-08-14
summary: "Skill v0.30.0 / npm 0.7.0: identity ADR + harden CI/eval; live --record và lật branch-protection vẫn mở."
---

# flow upgrade wave1 shipped

**Ngày**: 2026-08-14 13:32
**Mức**: Medium
**Thành phần**: flow-skill identity / CI / eval
**Trạng thái**: Ongoing — byte sản phẩm đã lên nhánh; checkpoint operator vẫn mở

## Chuyện gì xảy ra

Cook đủ 8 phase của `plans/260814-0948-flow-upgrade-wave1/` (34/34 task) trên
`research/deepseek-harness-upgrade` (worktree
`~/.herdr/worktrees/flow-skill/research-deepseek-harness-upgrade`). Skill product
**v0.30.0**, npm installer **0.7.0**. Identity giờ là ADR kiểm được, không còn vibe:
flow sở hữu cổng và biên lai, không bao giờ giữ process token.

Chuỗi cook: `cbfe180` ADR → `dfcec59` all-checks-passed → `7bf133c` pack-rehearsal →
`45dc2e6` AGENTS.md + word budget → `31e99ab` i18n blob-hash → `a30e598` macOS
refuse-guard → `030f6c3` keyless `--replay` / live `--record` → `f56de84` B1-S →
`c015df3` polish. Sau đó dump plan, merge master, bump `8d339f7`, refresh hash
`c86788f`.

Cổng kongming GO: identity ruling → red-team plan R1 (14 accepted) + validate R1
(13) → R2 (12) + validate R2 (1) → checkpoint từng phase (1, 2+3, 6, 7).

## Sự thật trần

Gọi đây là "shipped" là nói dối một nửa. Code nằm trên nhánh. Bằng chứng chịu
tải thì không. Job `eval-replay` vẫn skip-with-notice cho đến khi ai đó đốt token
thật với `--record`. B1-S đã thêm `fcdd`/`fcde` nhưng chưa có batch live `--n 3`
đo chúng — mà chính ADR vừa viết nói replay không bao giờ tính vào floor. Branch
protection vẫn chưa bắt `all-checks-passed`. Ta viết hiến pháp rồi để công tắc
enforcement tắt. Đúng cái hollow-done mà B1-S sinh ra để bắt. Bực vì wave *biết*
điều này trong plan rồi vẫn đánh cook 100%.

## Chi tiết kỹ thuật

- **Identity ADR** `docs/adr/0001-discipline-layer-identity.md`: invariant
  process-token, 5 flip-tripwire, floor tỷ lệ ("nhiều nhất một fixture lệch mỗi
  batch"), replay-never-counts, fixture-pair-per-new-gate, trần monetization.
- **A1**: `tests/run_all.sh` đọc `tests/manifest.txt`; `all-checks-passed` =
  `needs` + `if: always()`. Chưa chạy thí nghiệm forced-skip (chưa có PR vào
  `master`).
- **A2**: `scripts/pack-rehearsal.sh` rc=0 local — so byte tarball `skills/flow/`,
  DEST tạm, `e2e-installed-drive.sh` 22 passed. Có `NPM_TOKEN` = fail.
- **A3**: hash `gate-rules` stale thì hard-fail. Thân `_eval_engine_run()` và
  `_run_with_timeout()` không đổi (ADR STOP giữ).
- **A4/A5**: `AGENTS.md` gốc; budget README 3553/3880, SKILL.md 3648/3950; hash
  EN/VI trong `docs/i18n-pairs.txt`.
- **macOS**: live eval từ chối khi không có `timeout`/`gtimeout` thật; opt-in
  `FLOW_EVAL_UNBOUNDED=1`. Replay không đụng guard. Chẩn đoán DEBT vẫn chưa xác
  nhận.
- **B1-S**: addendum named-artifact + `fcdd` (hollow) / `fcde` (sound). Không đụng
  scoring cơ học.
- **Local**: `tests/run_all.sh` **60/61**. `tests/test_flow_usage_log.sh` 27 fail /
  57 pass. Có sẵn từ trước: cùng suite trên `48934b8` là **29 fail / 55 pass**.
  CI xanh. Wave không đụng suite này hay `skills/flow/harness/`. Gợi ý: section 6
  `export HOME="$SB/home"` rồi rollup qua `python` — máy này không có `python`;
  `_events_path()` lấy từ `dirname(_db_path)` (`flow_harness.py:673`); quan sát
  `r1={"rolled": 0, "skipped": 0}`.

## Đã thử

Cook đúng spec. Không bịa transcript live. Không lật setting GitHub từ agent.
Đúng kỷ luật — và vì thế phần còn lại kẹt ở người.

## Root cause

ADR biến batch live thành bằng chứng tuân thủ duy nhất, rồi cook dừng ở vạch
cấm-agent. Push nhánh research không chạy GHA
(`on.pull_request.branches: [master]`). "CI hardened" là commit YAML, chưa phải
required check đã xác minh. Biết rồi. Vẫn ship.

## Bài học

- Đổi tên required-check mà chưa lật protection là diễn. Lật sau PR xanh đầu,
  đừng cùng hơi với chữ "shipped."
- Replay mà chưa commit cây `skills/flow/eval/replay/` thì chỉ là job skip. Đừng
  giả vờ đường keyless đã sống trước khi `--record` hạ cánh.
- Fail local sẵn `python` vs `python3` sẽ tiếp tục cắn ai lấy `run_all.sh` làm
  cổng ship. Tách nó ra trước wave sau.

## Việc tiếp

Operator giữ (cấm agent):

1. Live `flow.sh eval --record --n 3` (9 fixture × 3 = 27 + probe); commit cây
   `skills/flow/eval/replay/` đã strip. Rồi live `--n 3` trên `fcdd`/`fcde` và
   record lại cả batch (33 + probe). Replay không tính.
2. PR base `master`. Forced-skip (`if: false` trên `no-python-degradation`) phải
   làm `all-checks-passed` đỏ; lệch tarball 1 byte phải fail parity; revert cả
   hai; giữ link run.
3. Lật branch protection: **chỉ** `all-checks-passed` sau run xanh đầy đủ đầu tiên.
4. Chẩn đoán DEBT macOS có Bound qua `scripts/macos-timeout-watchdog-diag.sh`;
   cập nhật `DEBT.md` confirmed-or-abandoned.

Chủ: operator. Hạn: trước khi coi v0.30.0 là CI-enforced trên `master`.

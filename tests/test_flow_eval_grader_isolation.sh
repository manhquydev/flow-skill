#!/usr/bin/env bash
# Regression suite for `eval` grader-input isolation (live batches only).
# A live batch must judge every fixture against the SAME frozen grader inputs
# (gate-rules corpus + manifest + fixture artifacts as of batch start). If those
# inputs change mid-batch, the batch must abort loudly before any further
# billable judge call, with no `done` trailer (torn-batch semantics), instead of
# silently judging later fixtures under different rules.
#
# Mocked engine ONLY - this suite NEVER calls a live LLM. The mock is
# order-based on purpose: it proves isolation mechanics, not judging quality
# (verdict parsing is already covered by tests/test_flow_eval.sh). Tests run
# against a TEMPORARY COPY of the skill tree so a mutating mock can never dirty
# the real checkout; FLOW_EVAL_MANIFEST only ever points at real shipped
# fixture ids (the v1 trust boundary resolves artifacts under the copy's
# EVAL_DIR, exactly as in production).
# Run: bash tests/test_flow_eval_grader_isolation.sh
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC_SKILL="$HERE/../skills/flow"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qF "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -qF "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

CASE=""; SB=""; RUN_COPY=""; MOCKBIN=""; MOCK_STATE=""
_cleanup_case() {
  [ -n "${CASE:-}" ] && rm -rf "$CASE" 2>/dev/null
  [ -n "${SB:-}" ] && rm -rf "$SB" 2>/dev/null
  [ -n "${MOCKBIN:-}" ] && rm -rf "$MOCKBIN" 2>/dev/null
}
trap _cleanup_case EXIT

# setup_case <mutate_on> <mutate_target_relpath|-> <verdict1,verdict2,...>
# Copies the skill tree, writes a 2-fixture manifest (fcda sound / fcdc hollow),
# and installs an env-driven mock `claude`. mutate_target_relpath is relative to
# the skill-tree copy root (e.g. references/gate-02.md); "-" disables mutation.
setup_case() {
  local mutate_on="$1" mutate_target_rel="$2" verdicts_csv="$3"
  CASE="$(mktemp -d)"
  SB="$(mktemp -d)"
  mkdir -p "$CASE/skill"
  cp -r "$SRC_SKILL/." "$CASE/skill/"
  RUN_COPY="$CASE/skill/runner/flow.sh"
  printf 'id\tstage\tartifact\texpected\nfcda\tcard\tcards/C-001.md\tPASS\nfcdc\tcard\tcards/C-001.md\tFLAG\n' > "$CASE/manifest.tsv"
  MOCKBIN="$(mktemp -d)"
  MOCK_STATE="$(mktemp -d)"
  printf '0' > "$MOCK_STATE/count"
  printf '%s' "$verdicts_csv" | tr ',' '\n' > "$MOCK_STATE/verdicts"
  local mutate_target=""
  if [ "$mutate_target_rel" != "-" ]; then
    mutate_target="$CASE/skill/$mutate_target_rel"
  fi
  cat > "$MOCKBIN/claude" <<'MOCKEOF'
#!/usr/bin/env bash
case "$1" in --version) echo "1.0.0 (mock)"; exit 0 ;; esac
prompt="$(cat)"
case "$prompt" in *FLOWPONG*) echo "FLOWPONG"; exit 0 ;; esac
state="${MOCK_STATE_DIR:-}"
count=0
[ -f "$state/count" ] && count="$(cat "$state/count")"
count=$((count + 1))
printf '%s' "$count" > "$state/count"
if [ "$count" = "${MOCK_MUTATE_ON:-0}" ] && [ -n "${MOCK_MUTATE_TARGET:-}" ]; then
  printf '%s\n' "${MOCK_MUTATE_TEXT:-MUTATED BY MOCK ENGINE}" >> "$MOCK_MUTATE_TARGET"
fi
verdict="$(sed -n "${count}p" "$state/verdicts" 2>/dev/null)"
[ -z "$verdict" ] && verdict="PASS"
nonce_line="$(printf '%s' "$prompt" | grep -oE "GATE-EVAL-[A-Za-z0-9-]+: FLAG" | head -1)"
marker="${nonce_line% FLAG}"
printf '%s %s\n' "$marker" "$verdict"
MOCKEOF
  chmod +x "$MOCKBIN/claude"
  export MOCK_STATE_DIR="$MOCK_STATE"
  export MOCK_MUTATE_ON="$mutate_on"
  export MOCK_MUTATE_TARGET="$mutate_target"
  export MOCK_MUTATE_TEXT="MUTATED BY MOCK ENGINE DURING BATCH"
}

# run_batch [extra flow.sh args...] -> sets OUT and RC globals.
run_batch() {
  OUT="$(PATH="$MOCKBIN:$PATH" FLOW_PROJECT_ROOT="$SB" FLOW_EVAL_MANIFEST="$CASE/manifest.tsv" FLOW_LOG_DISABLE=1 bash "$RUN_COPY" eval --n 1 --timeout 20 "$@" 2>&1)"
  RC=$?
}

# ---------- A) clean batch: frozen inputs, both fixtures judged, snapshot named ----------
echo "A) clean batch judges both fixtures against frozen inputs"
setup_case 0 - "PASS,FLAG"
run_batch
ck 0 "$RC" "clean batch exits 0"
has "$OUT" "grader snapshot " "batch names its grader snapshot"
has "$OUT" "fcda (card): PASS - matches expected PASS" "fcda judged PASS"
has "$OUT" "fcdc (card): FLAG - matches expected FLAG" "fcdc judged FLAG"

# ---------- B) gate-rules mutated mid-batch: abort before fixture 2, no done trailer ----------
echo "B) gate-rules file mutated during vote 1 aborts the batch"
setup_case 1 "references/gate-02.md" "PASS,FLAG"
run_batch
ck 1 "$RC" "mutated gate-rules batch exits 1"
has "$OUT" "grader inputs changed during batch" "abort names the grader change"
has "$OUT" "fcda (card): PASS - matches expected PASS" "fixture 1 (pre-mutation) still counted"
no  "$OUT" "fcdc (card)" "fixture 2 never judged after mutation"
nonce="$(printf '%s' "$OUT" | sed -n 's/^eval: batch \([A-Za-z0-9-]*\).*/\1/p' | head -1)"
res_file="$(find "$SB" -name 'eval-results.jsonl' 2>/dev/null | head -1)"
if [ -n "$nonce" ] && [ -n "$res_file" ]; then
  has "$(cat "$res_file")" "\"run_id\":\"$nonce\",\"batch\":\"start\"" "aborted batch has a start marker"
  no  "$(cat "$res_file")" "\"run_id\":\"$nonce\",\"batch\":\"done\"" "aborted batch has no done trailer"
else
  echo "  FAIL [torn-batch markers] (nonce='$nonce' results='$res_file')"; fail=$((fail+1))
fi

# ---------- C) fixture artifact mutated mid-batch: same abort ----------
echo "C) fixture artifact mutated during vote 1 aborts the batch"
setup_case 1 "eval/fixtures/fcdc/cards/C-001.md" "PASS,FLAG"
run_batch
ck 1 "$RC" "mutated fixture batch exits 1"
has "$OUT" "grader inputs changed during batch" "abort names the grader change"
no  "$OUT" "fcdc (card)" "fixture 2 never judged after mutation"

# ---------- D) no temp residue: snapshot + rundirs cleaned on normal exit ----------
echo "D) no temp-dir residue after a normal batch"
setup_case 0 - "PASS"
priv_tmp="$(mktemp -d)"
before="$(find "$priv_tmp" -mindepth 1 -print 2>/dev/null | wc -l | tr -d ' ')"
OUT="$(TMPDIR="$priv_tmp" PATH="$MOCKBIN:$PATH" FLOW_PROJECT_ROOT="$SB" FLOW_EVAL_MANIFEST="$CASE/manifest.tsv" FLOW_LOG_DISABLE=1 bash "$RUN_COPY" eval --fixture fcda --n 1 --timeout 20 2>&1)"
RC=$?
after="$(find "$priv_tmp" -mindepth 1 -print 2>/dev/null | wc -l | tr -d ' ')"
ck 0 "$RC" "single-fixture batch exits 0"
ck "$before" "$after" "temp dir empty after batch (snapshot + rundir cleaned)"
rm -rf "$priv_tmp"

# ---------- E) replay/report stay offline and snapshot-free ----------
echo "E) --report on an empty project is offline and snapshot-free"
setup_case 0 - "PASS"
OUT="$(PATH="$MOCKBIN:$PATH" FLOW_PROJECT_ROOT="$SB" FLOW_LOG_DISABLE=1 bash "$RUN_COPY" eval --report 2>&1)"
RC=$?
ck 1 "$RC" "--report with no batch exits 1"
has "$OUT" "no complete batch" "--report reports no complete batch"
no  "$OUT" "grader snapshot" "--report does not snapshot grader inputs"

echo "grader isolation: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
# CI-only eval-fixture impossibility linter. Zero LLM. Not a flow.sh verb.
# Protects fcdd/fcdc mechanical-PASS (a linter that makes those fail check is a bug).
# Run: bash tests/test_eval_fixture_lint.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
EVAL_DIR="$HERE/../skills/flow/eval"
MANIFEST="$EVAL_DIR/manifest.tsv"
ROUTING_MANIFEST="$EVAL_DIR/fixtures/routing/manifest.tsv"
CONVERGE_MANIFEST="$EVAL_DIR/fixtures/converge/manifest.tsv"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

# Same emptiness predicate as _evidence_is_empty (read, do not lift into cmd_check).
evidence_is_empty() {
  local ev="$1" ev_lc
  [ -z "$ev" ] && return 0
  ev_lc="$(printf '%s' "$ev" | tr '[:upper:]' '[:lower:]')"
  case "$ev_lc" in *"(empty until done)"*|"---"|"--") return 0 ;; esac
  return 1
}

card_evidence() { # $1=card file
  awk '/^## Evidence/{f=1; next} f && /^## /{exit} f' "$1"
}

echo "A) artifact manifest paths exist and expected is PASS|FLAG"
missing=0
bad_exp=0
while IFS=$'\t' read -r fid fstage fartifact fexpected || [ -n "${fid:-}" ]; do
  fid="$(printf '%s' "$fid" | tr -d '\r')"
  fartifact="$(printf '%s' "$fartifact" | tr -d '\r')"
  fexpected="$(printf '%s' "$fexpected" | tr -d '\r')"
  [ "$fid" = "id" ] && continue
  [ -z "$fid" ] && continue
  if [ ! -f "$EVAL_DIR/fixtures/$fid/$fartifact" ]; then
    echo "  FAIL [missing artifact $fid/$fartifact]"; fail=$((fail+1)); missing=1
  fi
  case "$fexpected" in
    PASS|FLAG) : ;;
    *) echo "  FAIL [expected not PASS|FLAG: $fid=$fexpected]"; fail=$((fail+1)); bad_exp=1 ;;
  esac
done < "$MANIFEST"
[ "$missing" -eq 0 ] && echo "  ok   [every manifest id has its artifact file]" && pass=$((pass+1))
[ "$bad_exp" -eq 0 ] && echo "  ok   [every artifact expected is PASS or FLAG]" && pass=$((pass+1))

echo "B) routing: state file exists; expected-action non-empty (do not judge the verb)"
rt_missing=0
rt_empty=0
while IFS=$'\t' read -r fid fstage fstatefile futterance fexpected || [ -n "${fid:-}" ]; do
  fid="$(printf '%s' "$fid" | tr -d '\r')"
  fstatefile="$(printf '%s' "$fstatefile" | tr -d '\r')"
  fexpected="$(printf '%s' "$fexpected" | tr -d '\r')"
  [ "$fid" = "id" ] && continue
  [ -z "$fid" ] && continue
  if [ ! -f "$EVAL_DIR/fixtures/routing/states/$fstatefile" ]; then
    echo "  FAIL [missing routing state $fid/$fstatefile]"; fail=$((fail+1)); rt_missing=1
  fi
  if [ -z "$fexpected" ]; then
    echo "  FAIL [empty expected-action for $fid]"; fail=$((fail+1)); rt_empty=1
  fi
done < "$ROUTING_MANIFEST"
[ "$rt_missing" -eq 0 ] && echo "  ok   [every routing state-file exists]" && pass=$((pass+1))
[ "$rt_empty" -eq 0 ] && echo "  ok   [every expected-action is non-empty]" && pass=$((pass+1))

echo "C) converge: expected GAP|CONVERGED; listed repo-dir exists"
cv_missing=0
cv_bad=0
while IFS=$'\t' read -r fid fstage frepodir fallow fexpected || [ -n "${fid:-}" ]; do
  fid="$(printf '%s' "$fid" | tr -d '\r')"
  frepodir="$(printf '%s' "$frepodir" | tr -d '\r')"
  fexpected="$(printf '%s' "$fexpected" | tr -d '\r' | tr '[:lower:]' '[:upper:]')"
  [ "$fid" = "id" ] && continue
  [ -z "$fid" ] && continue
  if [ ! -d "$EVAL_DIR/fixtures/converge/$frepodir" ]; then
    echo "  FAIL [missing converge repo-dir $fid/$frepodir]"; fail=$((fail+1)); cv_missing=1
  fi
  case "$fexpected" in
    GAP|CONVERGED) : ;;
    *) echo "  FAIL [converge expected not GAP|CONVERGED: $fid=$fexpected]"; fail=$((fail+1)); cv_bad=1 ;;
  esac
done < "$CONVERGE_MANIFEST"
[ "$cv_missing" -eq 0 ] && echo "  ok   [every converge repo-dir exists]" && pass=$((pass+1))
[ "$cv_bad" -eq 0 ] && echo "  ok   [every converge expected is GAP or CONVERGED]" && pass=$((pass+1))

echo "D) PASS-expected card fixtures have non-empty Evidence (not the placeholder)"
card_empty=0
while IFS=$'\t' read -r fid fstage fartifact fexpected || [ -n "${fid:-}" ]; do
  fid="$(printf '%s' "$fid" | tr -d '\r')"
  fstage="$(printf '%s' "$fstage" | tr -d '\r')"
  fartifact="$(printf '%s' "$fartifact" | tr -d '\r')"
  fexpected="$(printf '%s' "$fexpected" | tr -d '\r')"
  [ "$fid" = "id" ] && continue
  [ -z "$fid" ] && continue
  [ "$fstage" = "card" ] || continue
  [ "$fexpected" = "PASS" ] || continue
  ev="$(card_evidence "$EVAL_DIR/fixtures/$fid/$fartifact")"
  if evidence_is_empty "$ev"; then
    echo "  FAIL [PASS-expected card $fid has empty/placeholder Evidence]"; fail=$((fail+1)); card_empty=1
  fi
done < "$MANIFEST"
[ "$card_empty" -eq 0 ] && echo "  ok   [PASS-expected cards have real Evidence]" && pass=$((pass+1))

echo "E) heading-mapped PASS fixtures (01/02/card only; not f05) have FLAG partners"
# Collect stage -> has_pass / has_flag for heading-mapped stages only.
has_pass_01=0; has_flag_01=0
has_pass_02=0; has_flag_02=0
has_pass_card=0; has_flag_card=0
while IFS=$'\t' read -r fid fstage fartifact fexpected || [ -n "${fid:-}" ]; do
  fid="$(printf '%s' "$fid" | tr -d '\r')"
  fstage="$(printf '%s' "$fstage" | tr -d '\r')"
  fexpected="$(printf '%s' "$fexpected" | tr -d '\r')"
  [ "$fid" = "id" ] && continue
  [ -z "$fid" ] && continue
  short="${fstage%%-*}"
  case "$short" in
    01|02|card) : ;;
    *) continue ;;
  esac
  if [ "$fexpected" = "PASS" ]; then
    eval "has_pass_${short}=1"
  elif [ "$fexpected" = "FLAG" ]; then
    eval "has_flag_${short}=1"
  fi
done < "$MANIFEST"
ck 1 "$has_pass_01" "stage 01 has a PASS fixture"
ck 1 "$has_flag_01" "stage 01 has a FLAG partner"
ck 1 "$has_pass_02" "stage 02 has a PASS fixture"
ck 1 "$has_flag_02" "stage 02 has a FLAG partner"
ck 1 "$has_pass_card" "card stage has a PASS fixture"
ck 1 "$has_flag_card" "card stage has a FLAG partner"
# f05a/b are listed and unmapped — linter must not demand a heading or a pair for 05.
if grep -q $'^f05a\t' "$MANIFEST" && grep -q $'^f05b\t' "$MANIFEST"; then
  echo "  ok   [f05a/b remain listed; not treated as heading-mapped]"
  pass=$((pass+1))
else
  echo "  FAIL [f05a/b should stay listed and unmapped]"
  fail=$((fail+1))
fi

echo "F) protect fcdd/fcdc/fcda/fcde mechanical-PASS and fcdb FAIL (linter must not 'fix' them)"
check_copy() { # $1=fid $2=want_rc $3=label
  local fid="$1" want="$2" label="$3" CB rc
  CB="$(mktemp -d)"
  cp -r "$EVAL_DIR/fixtures/$fid/." "$CB/"
  FLOW_PROJECT_ROOT="$CB" FLOW_LOG_DISABLE=1 bash "$RUN" check C-001 >/dev/null 2>&1
  rc=$?
  rm -rf "$CB"
  ck "$want" "$rc" "$label"
}
check_copy fcda 0 "fcda card mechanically passes check"
check_copy fcde 0 "fcde card mechanically passes check"
check_copy fcdc 0 "fcdc decoy still mechanically passes check (linter must not fail it)"
check_copy fcdd 0 "fcdd artifact-less prose still mechanically passes check (linter must not fail it)"
check_copy fcdb 1 "fcdb process-only hollow still fails mechanical check"
fcdd_ev="$(card_evidence "$EVAL_DIR/fixtures/fcdd/cards/C-001.md")"
no "$fcdd_ev" "https://" "fcdd Evidence names no URL"
no "$fcdd_ev" "curl" "fcdd Evidence names no curl"
no "$fcdd_ev" '\$[[:space:]]' "fcdd Evidence names no \$ command prompt"
# Manifest expected stays FLAG for the hollow-but-clean pair (judge target, not check).
fcdd_exp="$(awk -F'\t' '$1=="fcdd"{gsub(/\r/,""); print $4}' "$MANIFEST")"
fcdc_exp="$(awk -F'\t' '$1=="fcdc"{gsub(/\r/,""); print $4}' "$MANIFEST")"
ck "FLAG" "$fcdd_exp" "fcdd manifest expected remains FLAG"
ck "FLAG" "$fcdc_exp" "fcdc manifest expected remains FLAG"

echo "G) conv-01 has no [FILL] / unimplemented-FR hole; gap-01 still has the FR2 hole"
conv_fill="$(grep -r '\[FILL' "$EVAL_DIR/fixtures/converge/conv-01" 2>/dev/null || true)"
if [ -z "$conv_fill" ]; then echo "  ok   [conv-01 contains no [FILL]]"; pass=$((pass+1)); else echo "  FAIL [conv-01 contains [FILL]]"; fail=$((fail+1)); fi
no "$(cat "$EVAL_DIR/fixtures/converge/conv-01/src/app.py")" "has no route" "conv-01 src is not the unimplemented-FR hole"
no "$(cat "$EVAL_DIR/fixtures/converge/conv-01/src/app.py")" "never written" "conv-01 src is not the never-written hole"
has "$(cat "$EVAL_DIR/fixtures/converge/gap-01/src/app.py")" "FR2" "gap-01 still names the FR2 hole"
has "$(cat "$EVAL_DIR/fixtures/converge/gap-01/src/app.py")" "no route" "gap-01 still contains the missing-route hole"

echo "H) red-then-revert: temp PASS-expected card with empty Evidence fails this linter; corpus untouched"
TMPCORPUS="$(mktemp -d)"
mkdir -p "$TMPCORPUS/fixtures/hollow/cards"
printf '%s\n' \
  '# C-001 — hollow' \
  'status: done' \
  'deps: none' \
  '' \
  '## Scope' \
  'x' \
  '' \
  '## Allowed files' \
  'y' \
  '' \
  '## Verify (run)' \
  '- [x] z' \
  '' \
  '## Done-evidence (x)' \
  'w' \
  '' \
  '## Evidence (paste)' \
  '(empty until done)' \
  > "$TMPCORPUS/fixtures/hollow/cards/C-001.md"
printf 'id\tstage\tartifact\texpected\nhollow\tcard\tcards/C-001.md\tPASS\n' > "$TMPCORPUS/manifest.tsv"
tmp_ev="$(card_evidence "$TMPCORPUS/fixtures/hollow/cards/C-001.md")"
if evidence_is_empty "$tmp_ev"; then
  echo "  ok   [temp PASS-expected empty-Evidence card is flagged by the emptiness predicate]"
  pass=$((pass+1))
else
  echo "  FAIL [temp empty-Evidence card was not flagged]"
  fail=$((fail+1))
fi
# Shipped fcda must still be non-empty after the temp exercise (corpus not dirtied).
ship_ev="$(card_evidence "$EVAL_DIR/fixtures/fcda/cards/C-001.md")"
if evidence_is_empty "$ship_ev"; then
  echo "  FAIL [shipped fcda Evidence became empty — corpus dirtied]"
  fail=$((fail+1))
else
  echo "  ok   [shipped fcda Evidence unchanged after temp corpus discarded]"
  pass=$((pass+1))
fi
rm -rf "$TMPCORPUS"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

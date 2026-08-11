#!/usr/bin/env bash
# World-state multi-signal floor for done Evidence + ready re-validate.
# Plan: 260811-1120-flow-hollow-done-trust-eval
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
export FLOW_HARNESS_DISABLE=1
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected /$2/)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }

# Multi-signal golden (categories A URL + B curl/command)
GPASS='$ curl https://x/healthz -> 200 PASS healthcheck'

mkcard() {
  printf '# C-001 — t\nstatus: %s\ndeps: %s\n## Scope\nx\n## Allowed files\nsrc/a.ts\n## Verify\n- [%s] v\n## Done-evidence\nu\n## Evidence\n%s\n' \
    "$1" "${4:-none}" "$2" "$3" > "$SB/cards/C-001.md"
}

echo "A) empty / process-only FAIL; multi-signal PASS"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
mkcard done "x" "(empty until done)"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "empty evidence done -> fail"
mkcard done "x" "---"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "placeholder --- done -> fail"
mkcard done "x" "The pull request was approved and CI stayed green. Release notes list it. The team is confident."
out="$(bash "$RUN" check C-001 2>&1)"; ck 1 $? "process-only prose done -> fail"
has "$out" "world-state signal" "process-only names world-state signal"
mkcard done "x" "https://example.com/looks-live"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "denylist URL alone -> fail"
mkcard done "x" "https://staging.realapp.io/g/x"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "single URL (score 1) -> fail"
mkcard done "x" "https://staging.realapp.io/ok"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "URL path /ok must not award C (no false A+C)"
mkcard done "x" "https://example.com:443/looks ok"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "denylist host with :port still denied"
mkcard done "x" "id=1 ok"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "bare id=1 ok does not pass floor"
mkcard done "x" "https://staging.realapp.io/x deploy failed"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "fail token must not award C"
mkcard done "x" "$GPASS"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 0 $? "multi-signal G-PASS -> ok"
mkcard todo " " "(empty until done)"
bash "$RUN" check C-001 >/dev/null 2>&1; ck 0 $? "todo empty evidence still ok"
rm -rf "$SB"

echo "B) card done reverts hollow; keeps multi-signal"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
mkcard todo "x" "PR approved, CI green, release notes shipped"
bash "$RUN" card start C-001 >/dev/null
bash "$RUN" card done C-001 >/dev/null 2>&1; ck 1 $? "card done process-only -> fail"
has "$(cat "$SB/cards/C-001.md")" "status: todo" "reverted to todo"
mkcard todo "x" "$GPASS"
bash "$RUN" card start C-001 >/dev/null
bash "$RUN" card done C-001 >/dev/null; ck 0 $? "card done G-PASS -> ok"
has "$(cat "$SB/cards/C-001.md")" "status: done" "stayed done"
rm -rf "$SB"

echo "C) ready: hollow done dep does not unblock"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards" "$SB/flow"
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
  printf '#%s\n## Gate\n- [x] ok\n\nbody\n' "$s" > "$SB/flow/$s.md"
done
printf '# C-001 — base\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\na.py\n## Verify\n- [x] x\n## Done-evidence\nu\n## Evidence\nPull request approved by two teammates; CI pipeline stayed green; release notes list the feature. The team is confident.\n' > "$SB/cards/C-001.md"
printf '# C-002 — next\nstatus: todo\ndeps: C-001\n## Scope\nb\n## Allowed files\nb.py\n## Verify\n- [ ] y\n## Done-evidence\nu\n## Evidence\n(empty until done)\n' > "$SB/cards/C-002.md"
out="$(bash "$RUN" ready 2>&1)"
has "$out" "blocked" "C-002 blocked when dep evidence hollow"
no_buildable=0
printf '%s' "$out" | grep -q "BUILDABLE C-002" && no_buildable=1
ck 0 "$no_buildable" "C-002 not BUILDABLE on hollow dep"
# fix dep evidence → buildable
printf '# C-001 — base\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\na.py\n## Verify\n- [x] x\n## Done-evidence\nu\n## Evidence\n%s\n' "$GPASS" > "$SB/cards/C-001.md"
out="$(bash "$RUN" ready 2>&1)"
has "$out" "BUILDABLE C-002" "C-002 buildable after dep multi-signal"
rm -rf "$SB"

echo "D) project-type lock after planning (only when type file exists)"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
  printf '#%s\n## Gate\n- [x] ok\n\nbody\n' "$s" > "$SB/flow/$s.md"
done
# no type file yet → first set ok even after planning
bash "$RUN" project-type web >/dev/null; ck 0 $? "first explicit type set after planning ok"
out="$(bash "$RUN" project-type cli 2>&1)"; ck 1 $? "type flip after file exists without FORCE -> fail"
has "$out" "locked" "mentions locked"
FLOW_FORCE=1 bash "$RUN" project-type cli >/dev/null; ck 0 $? "FLOW_FORCE allows type flip"
rm -rf "$SB"

echo "E) graph cards: hollow done dep not deps_met (parity H1)"
if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
  PY="$(command -v python3 || command -v python)"
  H="$HERE/../skills/flow/harness/flow_harness.py"
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
  # graph executor is the durable layer — must not set FLOW_HARNESS_DISABLE
  unset FLOW_HARNESS_DISABLE
  mkdir -p "$SB/cards" "$SB/flow"
  for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '#%s\n## Gate\n- [x] ok\n\nbody\n' "$s" > "$SB/flow/$s.md"
  done
  printf '# C-001\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\nsrc/a.ts\n## Verify\n- [x] v\n## Done-evidence\nu\n## Evidence\nPR approved; CI green; release notes updated. Team confident.\n' > "$SB/cards/C-001.md"
  printf '# C-002\nstatus: todo\ndeps: C-001\n## Scope\nb\n## Allowed files\nsrc/b.ts\n## Verify\n- [ ] v\n## Done-evidence\nu\n## Evidence\n(empty until done)\n' > "$SB/cards/C-002.md"
  out="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards 2>&1)"
  has "$out" '"missing": \["C-001"\]' "graph cards missing lists hollow dep C-001"
  no_ready=0
  printf '%s' "$out" | grep -q '"ready": \["C-002"\]' && no_ready=1
  ck 0 "$no_ready" "C-002 not alone in ready with hollow dep"
  # fix evidence
  printf '# C-001\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\nsrc/a.ts\n## Verify\n- [x] v\n## Done-evidence\nu\n## Evidence\n%s\n' "$GPASS" > "$SB/cards/C-001.md"
  out="$(FLOW_PROJECT_ROOT="$SB" "$PY" "$H" graph cards 2>&1)"
  has "$out" '"ready": \["C-002"\]' "graph cards ready includes C-002 after multi-signal"
  has "$out" '"deps_met": \["C-002"\]' "graph cards deps_met includes C-002 after multi-signal"
  export FLOW_HARNESS_DISABLE=1
  rm -rf "$SB"
else
  echo "  ok   [skip graph cards python absent]"; pass=$((pass+1))
fi

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

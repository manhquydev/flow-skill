#!/usr/bin/env bash
# Regression suite for gate-fired durable capture (Cluster B, Option A):
# stage 01 -> auto intake; stage 04 -> decision dual-write reminder; card done -> trace tier.
# Run: bash tests/test_flow_gate_capture.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
newsb() { SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"; }
clean_stage() { printf '#%s\n## Gate\n- [x] ok\n\nreal content.\n' "$1" > "$2"; }
harness_ok() { local py; py="$(command -v python || command -v python3 || true)"; [ -n "$py" ] && "$py" --version >/dev/null 2>&1; }

echo "B) durable hook is a clean no-op when the harness is disabled (graceful)"
newsb
printf '#00\n## Gate\n- [x] ok\n## Pitch\nbuild a small thing.\n' > "$SB/flow/00-idea.md"
clean_stage 01-research "$SB/flow/01-research.md"
out="$(FLOW_HARNESS_DISABLE=1 bash "$RUN" next 2>&1)"; rc=$?
ck 0 "$rc" "next exit 0 with harness disabled"
has "$out" "unlocked stage 2" "still advances 01->02 with harness disabled"
no  "$out" "harness:" "no durable-hook output when the durable layer is off"
rm -rf "$SB"

if ! harness_ok; then
  echo "A,C,D) skipped [no python -> durable layer unavailable]"
  echo; echo "RESULT: $pass passed, $fail failed"; [ "$fail" -eq 0 ]; exit $?
fi

echo "A) stage 01 pass auto-fires an intake into the harness + enrichment reminder"
newsb
printf '#00 Idea\n## Gate\n- [x] ok\n## Pitch\nbuild a tiny triage tool for operators.\n' > "$SB/flow/00-idea.md"
clean_stage 01-research "$SB/flow/01-research.md"
out="$(bash "$RUN" next 2>&1)"
has "$out" "unlocked stage 2" "advanced 01->02"
has "$out" "harness:" "durable-hook output present"
has "$out" "intake" "intake recorded at the research gate"
has "$out" "reclassify" "intake risk-flag enrichment reminder shown"
rm -rf "$SB"

echo "C) stage 04 pass prints the ADR decision dual-write reminder (no fabricated row)"
newsb
for s in 00-idea 01-research 02-scope 03-prd 04-adr; do clean_stage "$s" "$SB/flow/$s.md"; done
out="$(bash "$RUN" next 2>&1)"
has "$out" "unlocked stage 5" "advanced 04->05"
has "$out" "decision add" "decision dual-write reminder shown"
has "$out" "NOT a durable record" "explains the ADR md is not a durable decision record"
rm -rf "$SB"

echo "D) card done surfaces the harness trace tier (capture-quality signal)"
newsb; mkdir -p "$SB/cards"
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do clean_stage "$s" "$SB/flow/$s.md"; done
bash "$RUN" card >/dev/null 2>&1
printf '# C-001 - x\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\nb\n## Verify\n- [x] v\n## Done-evidence\nu\n## Evidence\nreal world-state proof\n' > "$SB/cards/C-001.md"
out="$(bash "$RUN" check C-001 2>&1)"
has "$out" "PASS: C-001" "card check passes"
has "$out" "harness:" "trace output surfaced at card done"
has "$out" "tier" "shows the trace tier verdict"
rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

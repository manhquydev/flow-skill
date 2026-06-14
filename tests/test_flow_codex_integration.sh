#!/usr/bin/env bash
# Regression guard for the Codex cross-vendor second-engine doc-contract.
# The detection/cost-gate/gate-parity invariants live in the reference docs (the semantic layer),
# so this suite asserts those invariants are present AND bound to their actual clause — a later
# edit that deletes/inverts an invariant must fail, not survive on an unrelated keyword. It is a
# DOC-CONTRACT test (no runner code for this feature).
# Run: bash tests/test_flow_codex_integration.sh   (exit 0 = all pass, 1 = any fail)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REF="$HERE/../skills/flow/references"
SKILL="$HERE/../skills/flow/SKILL.md"
CONTRACT="$HERE/../flow/05-contract.md"
pass=0; fail=0
# case-insensitive ERE match (use for clause-bound + tolerant-alternation assertions)
hasE() { if grep -qiE "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing /$2/ in $(basename "$1"))"; fail=$((fail+1)); fi; }
# literal-ish match (BRE; patterns below contain no regex metachars). NOTE: avoid grep -F here —
# MSYS/Git-Bash `grep -qF` aborts (SIGABRT) on this platform; plain `grep -qi` is portable.
has()  { if grep -qi "$2" "$1" 2>/dev/null; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing '$2' in $(basename "$1"))"; fail=$((fail+1)); fi; }
# negative assertion: the file must NOT contain an anti-pattern
lacks(){ if grep -qiE "$2" "$1" 2>/dev/null; then echo "  FAIL [$3] (anti-pattern /$2/ present in $(basename "$1"))"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
file() { if [ -f "$1" ]; then echo "  ok   [$2]"; pass=$((pass+1)); else echo "  FAIL [$2] (no file $1)"; fail=$((fail+1)); fi; }

echo "==== Codex integration doc-contract ===="

file "$REF/codex-integration.md" "codex-integration.md exists (the seam)"

# Invariant 1: detection is a TWO-STATE model — installed is NOT sufficient (clause-bound, not bare keyword).
has  "$REF/codex-integration.md" "not sufficient" "seam: INSTALLED is explicitly not-sufficient"
hasE "$REF/codex-integration.md" "never (select|route).{0,40}installed alone" "seam: never route on INSTALLED alone"
hasE "$REF/agent-detection.md"   "installed.{0,30}usable|never route to codex on mere presence" "detection: two-state mirrored (installed!=usable)"
# the probe is the AUTH-AWARE command (setup --json), and 'status' is explicitly rejected as the auth check.
has  "$REF/codex-integration.md" "setup --json"  "seam: liveness probe uses setup --json (auth-aware)"
hasE "$REF/codex-integration.md" "not .?status|status.{0,40}no auth" "seam: status rejected as the auth probe"
has  "$REF/agent-detection.md"   "setup --json"  "detection: probe command mirrored (setup --json)"

# Invariant 2: degrade-and-never-break (portability promise), clause-bound.
hasE "$REF/codex-integration.md" "degrade.*(never|silent)|absence never (lowers|breaks)" "seam: degrade-never-break rule"
has  "$REF/agent-detection.md"   "degrade"        "detection: degrade rule present"

# Invariant 3: cost gate = exactly 3 triggers, closed-set (no rogue 4th / no fire-every-stage).
has  "$REF/codex-integration.md"  "two-strikes"    "seam cost gate: two-strikes trigger"
has  "$REF/codex-integration.md"  "security-class" "seam cost gate: security-class trigger"
has  "$REF/codex-integration.md"  "opt-in"         "seam cost gate: operator opt-in trigger"
hasE "$REF/codex-integration.md"  "never call codex on every stage|not .* every stage" "seam cost gate: closed-set (no fire-every-stage)"
has  "$REF/adversarial-review.md" "ask the operator to opt in" "review lens: zero-findings -> operator opt-in (NOT auto-trigger)"

# Invariant 4: gate parity — Codex INFORMS, never auto-passes AND never auto-fails (bind to the clause).
has  "$REF/adversarial-review.md" "INFORMS"        "review lens: Codex INFORMS triage"
hasE "$REF/adversarial-review.md" "never auto-(pass|fail)" "review lens: never auto-pass/auto-fail (gate parity)"
hasE "$REF/codex-integration.md"  "never auto-(pass|fail)" "seam: gate parity (never auto decide)"

# Invariant 5: auto-run cost-gate parity (was entirely unguarded) — Codex only at the 2nd strike, not first red.
has  "$REF/auto-run.md" "codex:codex-rescue"       "auto-run: Tier-B can escalate to Codex fresh-engine"
has  "$REF/auto-run.md" "repair=codex"             "auto-run: AUTO-LOG names the Codex engine"
hasE "$REF/auto-run.md" "two-strikes deadlock|strike 2" "auto-run: Codex gated to the 2nd strike (deadlock)"
lacks "$REF/auto-run.md" "prefer a codex.{0,40}on (the )?first red|first red.{0,30}prefer.{0,10}codex" "auto-run: does NOT call Codex on first red (cost-gate)"

# Invariant 6: durable metric hook present (S2 — feeds the quality loop).
hasE "$REF/codex-integration.md" "intervention( add)?|durable metric" "seam: durable-metric hook documented"

# Invariant 7: surfaced + opt-in default + contract carries the same two-state.
has  "$SKILL" "codex-integration"  "SKILL.md points to codex-integration.md"
hasE "$REF/agent-stage-mapping.md" "default (stays|remains) ck" "stage map: opt-in, default ck:"
has  "$CONTRACT" "USABLE"          "contract I1: carries the USABLE two-state (no INSTALLED-only drift)"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

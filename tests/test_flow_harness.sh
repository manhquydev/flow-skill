#!/usr/bin/env bash
# Regression suite for skill/flow/harness/flow_harness.py (Phase 2 durable layer).
# Requires python (stdlib sqlite3). Run: bash tests/test_flow_harness.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
H="$HERE/../skill/flow/harness/flow_harness.py"
PY="$(command -v python || command -v python3)"
if [ -z "$PY" ]; then echo "SKIP: python not found"; exit 0; fi
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]: $1"; fail=$((fail+1)); fi; }

SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
py() { "$PY" "$H" "$@"; }

echo "init + idempotent re-init"
py init >/dev/null; ck 0 $? "init"
py init >/dev/null; ck 0 $? "re-init idempotent"

echo "intake classification"
has "$(py intake --type spec_slice --summary 'reply endpoint' --flags public_contracts,existing_behavior)" "lane=normal" "2 flags -> normal"
has "$(py intake --type change_request --summary 'login' --flags auth)" "lane=high_risk" "auth hard-gate -> high_risk"
py intake --type change_request --summary x --flags auth --lane tiny >/dev/null 2>&1; ck 1 $? "downgrade auth->tiny blocked"
py intake --type change_request --summary x --flags auth --lane tiny --narrow-scope >/dev/null 2>&1; ck 0 $? "downgrade allowed with --narrow-scope"
has "$(py intake --type maintenance --summary 'bump dep' --flags weak_proof)" "lane=normal" "1 non-hard flag -> normal"
has "$(py intake --type new_initiative --summary 'big area' --flags auth,data_model,public_contracts,multi_domain)" "high_risk" "4+ flags -> high_risk"

echo "story add / verify pass+fail"
py story add --id US-001 --title 'reply' --lane normal --verify 'exit 0' >/dev/null
has "$(py story verify --id US-001)" "pass" "verify exit0 -> pass"
py story add --id US-002 --title 'bad' --lane normal --verify 'exit 7' >/dev/null
py story verify-all >/dev/null 2>&1; ck 1 $? "verify-all returns 1 when any fails"

echo "trace tier scoring"
has "$(py trace --summary 'tiny docs done here' --outcome completed --lane tiny)" "tier 1/3, required 1" "tiny trace meets tier1"
has "$(py trace --summary 'thin normal trace x' --outcome completed --lane normal)" "BELOW required" "thin normal trace below tier2"
T2="$(py trace --summary 'full normal trace done' --story US-001 --intake 1 --agent dev --actions a --files-read r.py --files-changed c.py --outcome completed --friction 'note')"
has "$T2" "tier 2/3, required 2" "complete normal trace reaches tier2"
T3="$(py trace --summary 'high risk detailed trace' --story US-001 --intake 1 --agent dev --actions a --files-read r --files-changed c --outcome completed --decisions d --errors none --friction f --duration 60 --lane high_risk)"
has "$T3" "tier 3/3" "detailed trace reaches tier3"

echo "pre-close gate fires for unverified story"
py story add --id US-003 --title 'unverified' --lane normal >/dev/null
has "$(py trace --summary 'work on unverified story' --story US-003 --outcome completed)" "pre-close gate" "warns when linked story not verified"

echo "backlog growth-rule + query"
py backlog add --title 'missing rule' --pain 'inferred' --predicted 'save time' >/dev/null
has "$(py query backlog --open)" "missing rule" "backlog open lists item"
py backlog close --id 1 --outcome 'added the rule' --status implemented >/dev/null; ck 0 $? "backlog close"
has "$(py query matrix --numeric)" "US-001" "matrix lists stories"
has "$(py query friction)" "note" "friction query surfaces trace friction"

rm -rf "$SB"
echo; echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
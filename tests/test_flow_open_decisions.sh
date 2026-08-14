#!/usr/bin/env bash
# Regression suite for C-001: ## Open decisions section + /flow clarify advisory.
# Open decisions are unchecked `- [ ]` bullets under `## Open decisions`, counted by
# the EXISTING scan_gate box scanner — no new scan bash. Run:
#   bash tests/test_flow_open_decisions.sh
# Exit 0 = all pass, 1 = any fail.
#
# Red-team recipes H1/H2/H3 are binding (plans/260813-1100-spec-kit-imports/phase-01).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
TPL="$HERE/../skills/flow/_templates"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q -- "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q -- "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }
# Portable in-place tick of the sample OD bullet (no GNU/BSD `sed -i` split — macOS-safe).
tick_od() { awk '{ if ($0 == "- [ ] which tenant key?") print "- [x] which tenant key?"; else print }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }

# H3: every suite starts with a sandbox + the three env vars. Template path is
# $HERE/../skills/flow/_templates/… (this repo IS a flow project).
newsb() {
  SB="$(mktemp -d)"
  mkdir -p "$SB/flow"
  export FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_DISABLE=1 FLOW_LOG_DISABLE=1
}
G() { bash "$RUN" gate "$1" 2>&1; }
C() { bash "$RUN" clarify 2>&1; }
N() { bash "$RUN" next 2>&1; }

# H1 sanitizer: strip [FILL…] everywhere; flip `- [ ]` → `- [x]` ONLY inside ## Gate.
# Leaves the Open-decisions body untouched.
sanitize_fill_and_gate() {
  awk '
    /^##[[:space:]]+Gate/ { in_gate=1 }
    /^##[[:space:]]/ && $0 !~ /^##[[:space:]]+Gate/ { in_gate=0 }
    {
      line = $0
      gsub(/\[FILL[^]]*\]/, "filled", line)
      if (in_gate) gsub(/- \[ \]/, "- [x]", line)
      print line
    }
  ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

od_section() {
  awk '/^##[[:space:]]+Open decisions/{f=1;next} /^##[[:space:]]/{f=0} f' "$1"
}

stage_clean() { printf '#%s\n## Gate\n- [x] honestly done\n\nreal content.\n' "$1" > "$2"; }

echo "A) H1 template-roundtrip: heading present; sanitized Gate + stripped FILL; OD section has zero unchecked boxes; gate 02-scope exits 0"
if grep -q '^## Open decisions' "$TPL/02-scope.md"; then
  echo "  ok   [02-scope template has ^## Open decisions]"; pass=$((pass+1))
else
  echo "  FAIL [02-scope template has ^## Open decisions]"; fail=$((fail+1))
fi
if grep -q '^## Open decisions' "$TPL/03-prd.md"; then
  echo "  ok   [03-prd template has ^## Open decisions]"; pass=$((pass+1))
else
  echo "  FAIL [03-prd template has ^## Open decisions]"; fail=$((fail+1))
fi
if grep -q '^## Open decisions' "$TPL/05-contract.md"; then
  echo "  ok   [05-contract template has ^## Open decisions]"; pass=$((pass+1))
else
  echo "  FAIL [05-contract template has ^## Open decisions]"; fail=$((fail+1))
fi

newsb
cp "$TPL/02-scope.md" "$SB/flow/02-scope.md"
sanitize_fill_and_gate "$SB/flow/02-scope.md"
od="$(od_section "$SB/flow/02-scope.md")"
od_boxes="$(printf '%s\n' "$od" | grep -cE '^[[:space:]]*- \[ \]' || true)"
ck "0" "$od_boxes" "Open-decisions section has zero unchecked '- [ ]' (stub is not self-poison)"
out="$(G 02-scope)"; ck 0 $? "sanitized 02-scope template passes gate 02-scope"
rm -rf "$SB"

echo "B) H2 isolator: unchecked OD bullet fails gate <stage> on 02/03/05; ticking it unlocks"
for stage in 02-scope 03-prd 05-contract; do
  newsb
  cat > "$SB/flow/${stage}.md" <<EOF
# ${stage}
## Gate
- [x] No FILL placeholders remain in this file
- [x] No unresolved open decisions (resolve via /flow clarify, or assume/cut)

## Open decisions
- [ ] which tenant key?

## Body
real content, no FILL.
EOF
  out="$(G "$stage")"; ck 1 $? "unchecked OD bullet fails gate ${stage}"
  has "$out" "which tenant key" "gate ${stage} names the open-decision bullet"
  tick_od "$SB/flow/${stage}.md"
  out="$(G "$stage")"; ck 0 $? "ticked OD bullet -> gate ${stage} clean"
  rm -rf "$SB"
done

echo "B2) optional next unlock: clean 00+01, dirty 02 -> next exits 1; tick -> next copies 03-prd"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
stage_clean "Research" "$SB/flow/01-research.md"
cat > "$SB/flow/02-scope.md" <<'EOF'
# Scope
## Gate
- [x] honestly done
- [x] No unresolved open decisions (resolve via /flow clarify, or assume/cut)

## Open decisions
- [ ] which tenant key?

## Body
real content.
EOF
out="$(N)"; ck 1 $? "next exits 1 on dirty Open decisions (contiguous clean 00+01)"
tick_od "$SB/flow/02-scope.md"
out="$(N)"; ck 0 $? "next exits 0 after OD bullet ticked"
if [ -f "$SB/flow/03-prd.md" ]; then
  echo "  ok   [next copies 03-prd after OD resolved]"; pass=$((pass+1))
else
  echo "  FAIL [next copies 03-prd after OD resolved]"; fail=$((fail+1))
fi
rm -rf "$SB"

echo "C) LAW: cmd_next never calls cmd_clarify; clarify IS reachable via dispatch"
body="$(sed -n '/^cmd_next()/,/^}/p' "$RUN"; sed -n '/^function cmd_next/,/^}/p' "$RUN")"
has "$body" "cmd_next" "cmd_next body extracted (range non-empty - guards a silent pass)"
n="$(printf '%s' "$body" | grep -c 'cmd_clarify' || true)"
ck 0 "$n" "cmd_next never calls cmd_clarify"
has "$(grep -A2 '^  clarify)' "$RUN")" "cmd_clarify" "clarify IS reachable via dispatch"

echo "D) cmd_clarify advisory: exit 0 with or without open decisions; lists bullets when present"
newsb
out="$(C)"; ck 0 $? "clarify with no stage files exits 0"
has "$out" "no ## Open decisions" "missing heading -> prints 'no ## Open decisions'"
rm -rf "$SB"

newsb
cat > "$SB/flow/02-scope.md" <<'EOF'
# Scope
## Gate
- [ ] a gate box that must NOT be listed by clarify
- [x] other

## Open decisions
- [ ] which tenant key?

## Assumptions
tenant_id is the identity key (operator-locked).
EOF
out="$(C)"; ck 0 $? "clarify with open-decision bullet exits 0"
has "$out" "which tenant key" "lists the open-decision bullet"
no "$out" "a gate box that must NOT" "does not dump Gate checklist (section-scoped)"
rm -rf "$SB"

newsb
cat > "$SB/flow/02-scope.md" <<'EOF'
# Scope
## Gate
- [ ] leftover gate box
## Body
no open-decisions heading here
EOF
out="$(C)"; ck 0 $? "clarify with heading absent still exits 0"
has "$out" "no ## Open decisions" "heading absent -> 'no ## Open decisions'"
no "$out" "leftover gate box" "missing heading does not dump Gate boxes"
rm -rf "$SB"

echo "E) manifest.txt registers this suite (self-guard)"
has "$(cat "$HERE/manifest.txt" 2>/dev/null)" "test_flow_open_decisions.sh" "manifest.txt lists test_flow_open_decisions.sh"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

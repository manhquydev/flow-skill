#!/usr/bin/env bash
# End-to-end drive of the INSTALLED /flow skill in this fresh project.
# Covers happy path (web + cli) and edge cases. Asserts outcomes + prints readable transcripts.
set -u
RUN="${1:-$(cd "$(dirname "$0")" && pwd)/../skills/flow/runner/flow.sh}"
pass=0; fail=0
section() { echo; echo "==================== $1 ===================="; }
ck() { if [ "$1" = "$2" ]; then echo "  [ok] $3"; pass=$((pass+1)); else echo "  [FAIL] $3 (expected exit $1, got $2)"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  [ok] $3"; pass=$((pass+1)); else echo "  [FAIL] $3"; fail=$((fail+1)); fi; }
fill_clean() { printf '# %s\n## Gate\n- [x] a\n- [x] b\n- [x] c\n\nreal honest content, no placeholders.\n' "$1" > "$2"; }
SB() { local d; d="$(mktemp -d)"; echo "$d"; }

section "L) doctor (environment + quality check)"
out="$(FLOW_PROJECT_ROOT="$(SB)" bash "$RUN" doctor)"; echo "$out" | sed 's/^/    /'
has "$out" "READY" "doctor reports READY"

section "A) HAPPY PATH - web product: walk all 6 gates -> card -> done"
P="$(SB)"; export FLOW_PROJECT_ROOT="$P"
bash "$RUN" next >/dev/null; ck 0 $? "next starts stage 00"
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
  fill_clean "$s" "$P/flow/$s.md"
  bash "$RUN" next >/dev/null 2>&1 || true
done
out="$(bash "$RUN" next)"; echo "$out" | sed 's/^/    /'; ck 0 $? "stage 05 clean -> planning complete"
has "$out" "COMPLETE" "planning COMPLETE message"
bash "$RUN" card >/dev/null; ck 0 $? "card creates C-001"
cat > "$P/cards/C-001.md" <<'EOF'
# C-001 - healthz endpoint
status: done
deps: none
## Scope
one endpoint + ugly page, deployed
## Allowed files
app/health.py
## Verify (run these before calling the card done)
- [x] curl https://app.example.com/healthz returns 200
## Done-evidence (world-state proof)
a clickable https URL returning 200
## Evidence (paste the actual proof here when done)
$ curl -s https://app.example.com/healthz -> {"status":"ok"}
EOF
out="$(bash "$RUN" check C-001)"; echo "$out" | sed 's/^/    /'; ck 0 $? "done card with real evidence PASSES"

section "B) HAPPY PATH - CLI product: done-evidence adapts"
P="$(SB)"; export FLOW_PROJECT_ROOT="$P"
bash "$RUN" project-type cli >/dev/null
out="$(bash "$RUN" project-type)"; echo "$out" | sed 's/^/    /'
has "$out" "exit code" "cli done-evidence = installs + invoke + exit code (not a URL)"

section "C) EDGE - gate blocks honestly (FILL + unchecked box), with line numbers"
P="$(SB)"; export FLOW_PROJECT_ROOT="$P"
bash "$RUN" next >/dev/null                      # unlock 00 (fresh template, has FILL)
out="$(bash "$RUN" next 2>&1)"; rc=$?; echo "$out" | sed 's/^/    /'
ck 1 $rc "fresh template fails the gate"
has "$out" "unchecked gate boxes" "lists unchecked boxes"
has "$out" "FILL" "lists [FILL] placeholders"
has "$out" "Kill at a gate is also valid" "KILL is offered as a valid outcome"

section "D) EDGE - card 'done' but evidence empty -> check FAILS"
P="$(SB)"; export FLOW_PROJECT_ROOT="$P"; mkdir -p "$P/cards"
cat > "$P/cards/C-001.md" <<'EOF'
# C-001 - x
status: done
deps: none
## Scope
x
## Allowed files
y
## Verify
- [ ] curl 200
## Done-evidence
url
## Evidence
(empty until done)
EOF
out="$(bash "$RUN" check C-001 2>&1)"; rc=$?; echo "$out" | sed 's/^/    /'
ck 1 $rc "done + empty evidence + unchecked verify -> FAIL"
has "$out" "Evidence is empty" "flags empty done-evidence"

section "E) EDGE - gap-bypass cannot fake 'planning complete'"
P="$(SB)"; export FLOW_PROJECT_ROOT="$P"; mkdir -p "$P/flow"
printf '#00\n## Gate\n- [x] ok\n' > "$P/flow/00-idea.md"
printf '#05\n## Gate\n- [x] ok\n' > "$P/flow/05-contract.md"   # stray future stage
out="$(bash "$RUN" next)"; echo "$out" | sed 's/^/    /'
has "$out" "unlocked stage 1" "advances 00->01, ignores stray 05"
bash "$RUN" card >/dev/null 2>&1; ck 1 $? "card stays blocked (planning not really complete)"

section "F) EDGE - legitimate gate-skip (DEBT + skip), planning tolerates it"
P="$(SB)"; export FLOW_PROJECT_ROOT="$P"; mkdir -p "$P/flow"
for s in 00-idea 02-scope 03-prd 04-adr 05-contract; do fill_clean "$s" "$P/flow/$s.md"; done  # 01 absent
bash "$RUN" debt add "skip 01-research" "internal tool, no public market" "before public release" >/dev/null
out="$(bash "$RUN" skip 01-research --reason "internal tool, no public market")"; echo "$out" | sed 's/^/    /'
ck 0 $? "skip advances with a stage-matched DEBT"
bash "$RUN" card >/dev/null 2>&1; ck 0 $? "card unblocks after a legitimate debt-skip"

section "G) EDGE/SECURITY - the contract is never skippable; security reasons HALT"
P="$(SB)"; export FLOW_PROJECT_ROOT="$P"
bash "$RUN" debt add "skip 05-contract" "x" "later" >/dev/null
out="$(bash "$RUN" skip 05-contract --reason "no time" 2>&1)"; rc=$?; echo "$out" | sed 's/^/    /'
ck 1 $rc "contract (05) refused - it is adapted, not skipped"
bash "$RUN" debt add "skip 04-adr" "x" "later" >/dev/null
bash "$RUN" skip 04-adr --reason "auth tokens deferred" >/dev/null 2>&1; ck 1 $? "security-class reason HALTS"

section "H) EDGE - design check flags a non-compliant UI file"
P="$(SB)"; export FLOW_PROJECT_ROOT="$P"; mkdir -p "$P"
printf '<h1>My Workshop \xf0\x9f\x8e\x89</h1>\n<p>Welcome {{ user.name }}</p>\n<button>Trigger the queue</button>\n' > "$P/ui.html"
out="$(bash "$RUN" design "$P/ui.html" 2>&1)"; rc=$?; echo "$out" | sed 's/^/    /'
ck 1 $rc "design check flags violations"

section "I) DURABLE HARNESS - intake auto-escalates auth to high_risk; story verify"
P="$(SB)"; export FLOW_PROJECT_ROOT="$P"
out="$(bash "$RUN" harness intake --type change_request --summary "add login" --flags auth 2>&1)"; echo "$out" | sed 's/^/    /'
has "$out" "high_risk" "auth hard-gate auto-escalates to high_risk"
bash "$RUN" harness story add --id US-1 --title t --lane normal --verify "exit 0" >/dev/null 2>&1
out="$(bash "$RUN" harness story verify --id US-1 2>&1)"
has "$out" "pass" "story verify runs the real command -> pass"

echo
echo "########################################################"
echo "E2E RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
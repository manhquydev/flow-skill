#!/usr/bin/env bash
# Regression suite for skills/flow/runner/flow.sh (Phase 1 engine).
# Run: bash tests/test_flow_runner.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected $1 got $2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q -e "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q -e "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

stage_clean() { printf '#%s\n## Gate\n- [x] honestly done\n\nreal content.\n' "$1" > "$2"; }

echo "A) gap-bypass must NOT report planning complete"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow"
printf '#00\n## Gate\n- [x] ok\n' > "$SB/flow/00-idea.md"
printf '#05\n## Gate\n- [x] ok\n' > "$SB/flow/05-contract.md"   # stray future stage
has "$(bash "$RUN" next)" "unlocked stage 1" "next advances 00->01, ignores stray 05"
bash "$RUN" card >/dev/null 2>&1; ck 1 $? "card blocked while stages 01-04 missing"
rm -rf "$SB"

echo "B) start + dirty-gate fail + clean-gate advance"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB"
bash "$RUN" next >/dev/null; ck 0 $? "next starts stage 00"
bash "$RUN" next >/dev/null 2>&1; ck 1 $? "fresh template (FILL) fails gate"
stage_clean "Idea" "$SB/flow/00-idea.md"
bash "$RUN" next >/dev/null; ck 0 $? "clean stage 00 advances to 01"
rm -rf "$SB"

echo "C) ### wrong-heading-level rejected; required sections enforced"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
printf '# C-001 — x\nstatus: todo\ndeps: none\n### Scope\nx\n## Allowed files\ny\n## Verify (run)\n- [ ] z\n## Done-evidence (x)\nw\n## Evidence (paste)\n(empty until done)\n' > "$SB/cards/C-001.md"
out="$(bash "$RUN" check C-001)"; rc=$?
has "$out" "missing section: ## Scope" "### Scope does not satisfy ## Scope"
ck 1 $rc "malformed card -> exit 1"
rm -rf "$SB"

echo "D) done-card gates: empty/--- evidence + unchecked verify fail; real evidence passes"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/cards"
mkcard() { # $1 status  $2 verifybox  $3 evidence
  printf '# C-001 — scaffold
status: %s
deps: none
## Scope
one thing
## Allowed files
infra/
## Verify (run these before calling the card done)
- [%s] curl 200
## Done-evidence (world-state proof)
url
## Evidence (paste the actual proof here when done)
%s
' "$1" "$2" "$3" > "$SB/cards/C-001.md"
}
mkcard done " " "(empty until done)"; bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "done + empty evidence + unchecked verify fails"
mkcard done "x" "---"; bash "$RUN" check C-001 >/dev/null 2>&1; ck 1 $? "done + '---' evidence fails"
mkcard done "x" '$ curl https://x/healthz -> {"ok":true}'; bash "$RUN" check C-001 >/dev/null 2>&1; ck 0 $? "done + checked verify + real evidence passes"
mkcard todo " " "(empty until done)"; bash "$RUN" check C-001 >/dev/null 2>&1; ck 0 $? "todo card with no FILL passes"
rm -rf "$SB"

echo "E) full happy E2E + ready resolves short dep id"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow" "$SB/cards"
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do stage_clean "$s" "$SB/flow/$s.md"; done
bash "$RUN" card >/dev/null; ck 0 $? "card after planning complete"
printf '# C-001 — base\nstatus: done\ndeps: none\n## Scope\na\n## Allowed files\na.py\n## Verify\n- [x] x\n## Done-evidence\nu\n## Evidence\n$ curl https://x/healthz -> 200 PASS healthcheck\n' > "$SB/cards/C-001.md"
printf '# C-002 — next\nstatus: todo\ndeps: C-1\n## Scope\nb\n## Allowed files\nb.py\n## Verify\n- [ ] y\n## Done-evidence\nu\n## Evidence\n(empty until done)\n' > "$SB/cards/C-002.md"
has "$(bash "$RUN" ready)" "BUILDABLE C-002" "short dep id C-1 resolves to done C-001"
rm -rf "$SB"

echo "F) _python: returns non-zero exit when no python3/python on PATH; exit 0 + path when present"
# Extract _python directly from flow.sh so the test tracks the real implementation.
# Sourcing the full script is unsafe (triggers dispatch); sed-extract + eval is the clean approach.
_PYTHON_DEF="$(sed -n '/^_python()/,/^}/p' "$RUN")"
# No-interpreter case: shadow PATH inside the subshell after bash itself is loaded.
no_py_out="$(bash -c "PATH=/nonexistent; $_PYTHON_DEF; _python; echo exit=\$?")"
ck "exit=1" "$(printf '%s' "$no_py_out" | grep 'exit=')" "_python exit is non-zero when no interpreter on PATH"
ck "" "$(printf '%s' "$no_py_out" | grep -v 'exit=')" "_python stdout is empty when no interpreter found"
# Real-interpreter case: current shell has python available (skip gracefully if truly absent).
real_py="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
if [ -n "$real_py" ]; then
  real_out="$(bash -c "$_PYTHON_DEF; _python; echo exit=\$?")"
  real_path="$(printf '%s' "$real_out" | grep -v 'exit=')"
  real_exit="$(printf '%s' "$real_out" | grep 'exit=')"
  ck "exit=0" "$real_exit" "_python exit 0 when real python present"
  has "$real_path" "python" "_python prints interpreter path when present"
else
  echo "  skip [_python real-interpreter checks] (no python on this PATH)"
fi

echo "G) advisory probe tempdir cleaned even when interrupted (SIGINT) — tempdir-leak guard"
# Run cmd_coherence in a background subshell under a controlled TMPDIR so mktemp -d creates
# dirs there. Send SIGINT immediately; the EXIT trap (_cleanup_tds) fires and removes them.
# A package.json with a version field ensures the tempdir is actually created before the kill.
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"
printf '{"name":"t","version":"1.0.0"}\n' > "$SB/package.json"
MY_TMPDIR="$(mktemp -d)"                           # isolated tempdir root for this test
leftover=""
TMPDIR="$MY_TMPDIR" bash "$RUN" coherence >/dev/null 2>&1 &
bgpid=$!
# Wait until the subshell ACTUALLY creates its tempdir (poll w/ timeout), THEN interrupt — a
# fixed sleep could fire before `mktemp -d` on a slow host and false-green without exercising
# cleanup. End-state ("no leftover") holds whether SIGINT lands mid-run or it completed normally.
waited=0
while [ -z "$(ls "$MY_TMPDIR" 2>/dev/null)" ] && [ "$waited" -lt 100 ]; do sleep 0.05; waited=$((waited+1)); done
kill -INT "$bgpid" 2>/dev/null; wait "$bgpid" 2>/dev/null || true
leftover="$(ls "$MY_TMPDIR" 2>/dev/null)"
if [ -z "$leftover" ]; then
  echo "  ok   [advisory probe tempdir_leak_on_sigint: no leftover under controlled TMPDIR]"; pass=$((pass+1))
else
  echo "  FAIL [advisory probe tempdir_leak_on_sigint: leftover dirs: $leftover]"; fail=$((fail+1))
fi
rm -rf "$SB" "$MY_TMPDIR"

echo "H) doctor prints timeout: full|partial|absent (informational; never scores eval)"
out="$(bash "$RUN" doctor 2>&1)"
if printf '%s' "$out" | grep -qE 'timeout:[[:space:]]*(full|partial|absent)'; then
  echo "  ok   [doctor prints timeout: full|partial|absent]"; pass=$((pass+1))
else
  echo "  FAIL [doctor missing timeout: full|partial|absent line]"; fail=$((fail+1))
fi
if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
  has "$out" "timeout:   full" "timeout/gtimeout present -> full"
fi
# PATH-shadow: hide timeout/gtimeout. Do not use FLOW_EVAL_FORCE_DARWIN (eval-only).
notimeoutbin="$(mktemp -d)"
for d in /usr/bin /bin; do
  [ -d "$d" ] || continue
  for f in "$d"/*; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in timeout|timeout.exe|gtimeout|gtimeout.exe) continue ;; esac
    [ -e "$notimeoutbin/$b" ] || ln -s "$f" "$notimeoutbin/$b" 2>/dev/null || cp "$f" "$notimeoutbin/$b" 2>/dev/null
  done
done
if PATH="$notimeoutbin" command -v timeout >/dev/null 2>&1 || PATH="$notimeoutbin" command -v gtimeout >/dev/null 2>&1; then
  echo "  skip [timeout-still-resolves] (cannot hide timeout/gtimeout on this platform)"
else
  out2="$(PATH="$notimeoutbin" bash "$RUN" doctor 2>&1)"
  case "$(uname -s 2>/dev/null)" in
    Darwin) has "$out2" "timeout:   absent" "Darwin without timeout/gtimeout -> absent (live eval still REFUSED)" ;;
    *)      has "$out2" "timeout:   partial" "non-Darwin without timeout/gtimeout -> partial" ;;
  esac
fi
rm -rf "$notimeoutbin"

echo "I) doctor runner integrity (C5: pack-time manifest hash vs live flow.sh)"
sha_bin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else sha256sum "$1" | awk '{print $1}'; fi
}
# Copy the skill tree into a temp root so the manifest lookup (SCRIPT_DIR/../../..)
# resolves there without touching the repo's own portable-manifest.json. (A symlink
# would not work: bash resolves SCRIPT_DIR through it back to the real tree.)
IT="$(mktemp -d)"
cp -R "$HERE/../skills/flow" "$IT/src"
RUNX="$IT/src/runner/flow.sh"
LIVE="$(sha_bin "$RUNX")"
# (a) bundled receipt matching -> ok line
printf '{\n  "schema_version": 1,\n  "files": {\n    "runner/flow.sh": "%s"\n  }\n}\n' "$LIVE" > "$IT/src/manifest-hashes.json"
out="$(bash "$RUNX" doctor 2>&1)"; rc=$?
has "$out" "bundled tree integrity: ok (1 files verified)" "bundled receipt matching -> ok line"
ck 0 $rc "bundled receipt matching -> doctor exit 0"
# (b) tampered bytes vs receipt -> loud FAIL + nonzero
printf '\n' >> "$RUNX"
out="$(bash "$RUNX" doctor 2>&1)"; rc=0; bash "$RUNX" doctor >/dev/null 2>&1 || rc=$?
has "$out" "FAIL: bundled tree integrity" "tampered bytes vs receipt -> loud FAIL"
ck 1 $rc "tampered bytes vs receipt -> doctor nonzero"
cp "$HERE/../skills/flow/runner/flow.sh" "$RUNX"
rm -f "$IT/src/manifest-hashes.json"
# (c) receipt absent -> dev checkout skip line
out="$(bash "$RUNX" doctor 2>&1)"; rc=$?
has "$out" "bundled tree integrity: dev checkout (install receipt not present) - skipped" "receipt absent -> skip line"
ck 0 $rc "receipt absent -> doctor exit 0"
# (e) hash generation deterministic: sync.mjs run twice => byte-identical manifest
cp "$HERE/../portable-manifest.json" "$IT/pm.before"
node "$HERE/../npm-wrapper/scripts/sync.mjs" >/dev/null 2>&1
node "$HERE/../npm-wrapper/scripts/sync.mjs" >/dev/null 2>&1
if cmp -s "$IT/pm.before" "$HERE/../portable-manifest.json"; then
  echo "  ok   [hash regeneration deterministic (byte-stable manifest)]"; pass=$((pass+1))
else
  echo "  FAIL [hash regeneration not byte-stable]"; fail=$((fail+1))
fi
rm -rf "$IT"

echo "J) flow gate [--card C-NNN|<stage>] --json closed envelope"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB/flow" "$SB/cards"
PY_BIN="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"

# 1. Clean stage gate: exit 0, valid JSON, clean: true, findings: []
stage_clean "00-idea" "$SB/flow/00-idea.md"
out="$(bash "$RUN" gate 00-idea --json 2>&1)"; rc=$?
ck 0 $rc "clean stage gate --json exit 0"
has "$out" '"schema_version":1' "clean stage JSON carries schema_version 1"
has "$out" '"kind":"gate.report"' "clean stage JSON carries kind gate.report"
has "$out" '"target":"00-idea"' "clean stage JSON carries target 00-idea"
has "$out" '"clean":true' "clean stage JSON carries clean: true"
has "$out" '"findings":\[\]' "clean stage JSON carries empty findings array"
if [ -n "$PY_BIN" ]; then
  printf '%s' "$out" | "$PY_BIN" -c 'import sys, json; d = json.load(sys.stdin); assert d["clean"] is True; assert d["findings"] == []; assert d["target"] == "00-idea"'
  ck 0 $? "clean stage JSON parses via python"
else
  echo "  skip [clean stage JSON parses via python] (no python on this PATH)"
fi
# Flag-order parity: gate --json 00-idea
out_pre="$(bash "$RUN" gate --json 00-idea 2>&1)"; rc_pre=$?
ck 0 $rc_pre "gate --json 00-idea flag-order exit 0"
ck "$out" "$out_pre" "gate --json 00-idea identical to gate 00-idea --json"

# 2. Dirty stage gate: unchecked + [FILL] + midtier findings, quotes, backslashes, and real TAB
echo "web" > "$SB/PROJECT_TYPE"
TAB_CHAR="$(printf '\t')"
printf '# 01-research\n## Gate\n- [ ] unchecked item with "quotes", \\backslashes\\ and tab1%stomb\n[FILL: placeholder text]\n## What exists already\n1. single entry\n' "$TAB_CHAR" > "$SB/flow/01-research.md"
out="$(bash "$RUN" gate 01-research --json 2>&1)"; rc=$?
ck 1 $rc "dirty stage gate --json exit 1"
has "$out" '"clean":false' "dirty stage JSON carries clean: false"
has "$out" '"target":"01-research"' "dirty stage JSON carries target 01-research"
has "$out" 'unchecked gate boxes:' "findings carry unchecked section"
has "$out" 'unfilled \[FILL\] placeholders:' "findings carry FILL section"
has "$out" 'What exists already' "findings carry midtier violation"
if [ -n "$PY_BIN" ]; then
  printf '%s' "$out" | "$PY_BIN" -c '
import sys, json, re
d = json.load(sys.stdin)
assert d["clean"] is False
assert d["target"] == "01-research"
# Each line remains its own array element (headings + detail lines)
assert len(d["findings"]) >= 5
assert any("quotes" in f and "backslashes" in f for f in d["findings"])
assert any("What exists already" in f for f in d["findings"])
# Findings include L<line>: prefix from scan_gate detail lines
assert any(re.match(r"^L[0-9]+:", f) for f in d["findings"])
# Real TAB preservation: parsed JSON finding contains literal tab character (\t)
assert any("tab1\ttomb" in f for f in d["findings"]), "literal tab not preserved in findings: %r" % (d["findings"],)
'
  ck 0 $? "dirty stage JSON with L<line>: prefix, TAB, and quotes/backslashes parses via python"
else
  echo "  skip [dirty stage JSON with L<line>: prefix, TAB, and quotes/backslashes parses via python] (no python on this PATH)"
fi
# 3. Missing stage artifact file: exit 1, clean: false, findings has missing file
out="$(bash "$RUN" gate 02-scope --json 2>&1)"; rc=$?
ck 1 $rc "missing stage artifact gate --json exit 1"
has "$out" '"clean":false' "missing stage JSON carries clean: false"
has "$out" 'missing file:' "missing stage JSON carries missing file finding"
if [ -n "$PY_BIN" ]; then
  printf '%s' "$out" | "$PY_BIN" -c 'import sys, json; d = json.load(sys.stdin); assert d["clean"] is False; assert any("missing file:" in f for f in d["findings"])'
  ck 0 $? "missing stage JSON parses via python"
else
  echo "  skip [missing stage JSON parses via python] (no python on this PATH)"
fi

# 4. Clean card gate: exit 0, valid JSON, clean: true, target: C-001
printf '# C-001 — clean\nstatus: todo\ndeps: none\n## Scope\nscope\n## Allowed files\nfile.txt\n## Verify\n- [x] verify\n## Done-evidence\nurl\n## Evidence\n(empty until done)\n' > "$SB/cards/C-001.md"
out_card="$(bash "$RUN" gate --card C-001 --json 2>&1)"; rc=$?
ck 0 $rc "clean card gate --card --json exit 0"
has "$out_card" '"target":"C-001"' "clean card JSON carries target C-001"
has "$out_card" '"clean":true' "clean card JSON carries clean: true"
has "$out_card" '"findings":\[\]' "clean card JSON carries empty findings"
# Flag-order parity: gate --json --card C-001
out_card_pre="$(bash "$RUN" gate --json --card C-001 2>&1)"; rc_card_pre=$?
ck 0 $rc_card_pre "gate --json --card C-001 flag-order exit 0"
ck "$out_card" "$out_card_pre" "gate --json --card C-001 identical to gate --card C-001 --json"
# 5. Dirty card gate: exit 1, valid JSON, clean: false, findings non-empty
printf '# C-002 — dirty\nstatus: todo\ndeps: none\n## Scope\nscope\n## Allowed files\nfile.txt\n## Verify\n- [ ] verify\n[FILL: placeholder]\n## Done-evidence\nurl\n## Evidence\n(empty until done)\n' > "$SB/cards/C-002.md"
out="$(bash "$RUN" gate --card C-002 --json 2>&1)"; rc=$?
ck 1 $rc "dirty card gate --card --json exit 1"
has "$out" '"target":"C-002"' "dirty card JSON carries target C-002"
has "$out" '"clean":false' "dirty card JSON carries clean: false"
has "$out" 'unchecked gate boxes:' "dirty card findings carry unchecked"

# 6. Nonexistent card: exit 2, fails loudly, no JSON report
out="$(bash "$RUN" gate --card C-999 --json 2>&1)"; rc=$?
ck 2 $rc "nonexistent card gate --card --json exit 2"
has "$out" "card not found" "reports card not found for nonexistent card"

# 7. Error handling & legacy usage parity: exit 2
out="$(bash "$RUN" gate bogus 2>&1)"; rc=$?
ck 2 $rc "legacy gate bogus exit 2"
has "$out" "usage: /flow gate <stage:" "legacy gate bogus outputs stage usage"
no "$out" "--json" "legacy gate bogus does not mention --json"

out="$(bash "$RUN" gate --card 2>&1)"; rc=$?
ck 2 $rc "legacy gate --card exit 2"
ck "usage: /flow gate --card C-NNN" "$out" "legacy gate --card outputs exact legacy card usage"

out="$(bash "$RUN" gate --card junk 2>&1)"; rc=$?
ck 2 $rc "legacy gate --card junk exit 2"
ck "usage: /flow gate --card C-NNN" "$out" "legacy gate --card junk outputs exact legacy card usage"

out="$(bash "$RUN" gate bogus --json 2>&1)"; rc=$?
ck 2 $rc "gate bogus --json exit 2"
has "$out" '\[--json\]' "gate bogus --json usage mentions optional --json"

out="$(bash "$RUN" gate 00-idea --json extra 2>&1)"; rc=$?
ck 2 $rc "extra args gate 00-idea --json extra exit 2"
has "$out" '\[--json\]' "extra args with --json shows --json usage"

out="$(bash "$RUN" gate 00-idea extra 2>&1)"; rc=$?
ck 2 $rc "extra args gate 00-idea extra prose exit 2"
no "$out" "--json" "extra args without --json does not mention --json"

out="$(bash "$RUN" gate --card C-001 --json extra 2>&1)"; rc=$?
ck 2 $rc "extra args gate --card C-001 --json extra exit 2"

# 7b. Empty first positional argument must fail loud with exit 2 (no silent scan drop)
out="$(bash "$RUN" gate "" 00-idea 2>&1)"; rc=$?
ck 2 $rc "gate empty-arg 00-idea exit 2"
ck "usage: /flow gate <stage: 00-idea 01-research 02-scope 03-prd 04-adr 05-contract> | /flow gate --card C-NNN" "$out" "gate empty-arg outputs legacy usage"

out="$(bash "$RUN" gate "" 2>&1)"; rc=$?
ck 2 $rc "gate empty-arg alone exit 2"
ck "usage: /flow gate <stage: 00-idea 01-research 02-scope 03-prd 04-adr 05-contract> | /flow gate --card C-NNN" "$out" "gate empty-arg alone outputs legacy usage"
# 8. Prose parity without --json
out="$(bash "$RUN" gate 00-idea 2>&1)"; rc=$?
ck 0 $rc "prose clean stage exit 0"
has "$out" "clean" "prose clean stage reports clean"
out="$(bash "$RUN" gate 01-research 2>&1)"; rc=$?
ck 1 $rc "prose dirty stage exit 1"
has "$out" "unchecked gate boxes:" "prose dirty stage reports findings"
out="$(bash "$RUN" gate --card C-001 2>&1)"; rc=$?
ck 0 $rc "prose clean card exit 0"
has "$out" "clean" "prose clean card reports clean"
out="$(bash "$RUN" gate --card C-002 2>&1)"; rc=$?
ck 1 $rc "prose dirty card exit 1"
has "$out" "unchecked gate boxes:" "prose dirty card reports findings"

rm -rf "$SB"

echo "K) flow debt [list] [--json] closed envelope"
SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; mkdir -p "$SB"
PY_BIN="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"

# 1. No DEBT.md: exit 0, valid empty JSON envelope, prose unmodified
out="$(bash "$RUN" debt list --json 2>&1)"; rc=$?
ck 0 $rc "no DEBT.md debt list --json exit 0"
has "$out" '"schema_version":1' "no DEBT.md JSON carries schema_version 1"
has "$out" '"kind":"debt.list"' "no DEBT.md JSON carries kind debt.list"
has "$out" '"total":0' "no DEBT.md JSON carries total 0"
has "$out" '"open_count":0' "no DEBT.md JSON carries open_count 0"
has "$out" '"debts":\[\]' "no DEBT.md JSON carries empty debts array"
if [ -n "$PY_BIN" ]; then
  printf '%s' "$out" | "$PY_BIN" -c 'import sys, json; d = json.load(sys.stdin); assert d["schema_version"] == 1; assert d["kind"] == "debt.list"; assert d["total"] == 0; assert d["open_count"] == 0; assert d["debts"] == []'
  ck 0 $? "no DEBT.md JSON parses via python"
else
  echo "  skip [no DEBT.md JSON parses via python] (no python on this PATH)"
fi

# Flag-order and shorthand parity: debt --json, debt --json list, debt list --json
out_shorthand="$(bash "$RUN" debt --json 2>&1)"; rc_shorthand=$?
ck 0 $rc_shorthand "debt --json exit 0"
ck "$out" "$out_shorthand" "debt --json identical to debt list --json"

out_prefix="$(bash "$RUN" debt --json list 2>&1)"; rc_prefix=$?
ck 0 $rc_prefix "debt --json list exit 0"
ck "$out" "$out_prefix" "debt --json list identical to debt list --json"

# Prose parity when no DEBT.md
out_prose="$(bash "$RUN" debt list 2>&1)"; rc_prose=$?
ck 0 $rc_prose "prose debt list (no file) exit 0"
ck "No debts recorded." "$out_prose" "prose debt list reports No debts recorded."

out_prose_bare="$(bash "$RUN" debt 2>&1)"; rc_prose_bare=$?
ck 0 $rc_prose_bare "prose bare debt (no file) exit 0"
ck "No debts recorded." "$out_prose_bare" "prose bare debt reports No debts recorded."

# 2. Populated DEBT.md: open, closed (-[x], -[X]), quotes, backslashes, tabs, line preservation
TAB_CHAR="$(printf '\t')"
printf '# DEBT - deliberate gate-skips\n\n- [ ] DEBT: skip 01-research -- internal tool with "quotes", \\backslashes\\ and tab1%stomb -- close before: public release -- opened 2026-10-18\n- [x] DEBT: skip 04-adr -- single obvious choice -- close before: v2 -- opened 2026-10-15\n- [X] DEBT: temp auth bypass -- dev only -- close before: staging -- opened 2026-10-16\n' "$TAB_CHAR" > "$SB/DEBT.md"

out_pop="$(bash "$RUN" debt list --json 2>&1)"; rc_pop=$?
ck 0 $rc_pop "populated debt list --json exit 0"
has "$out_pop" '"total":3' "populated JSON carries total 3"
has "$out_pop" '"open_count":1' "populated JSON carries open_count 1"
if [ -n "$PY_BIN" ]; then
  printf '%s' "$out_pop" | "$PY_BIN" -c '
import sys, json
d = json.load(sys.stdin)
assert d["schema_version"] == 1
assert d["kind"] == "debt.list"
assert d["total"] == 3
assert d["open_count"] == 1
assert len(d["debts"]) == 3

# Item 1: open with special characters and tab preserved
item0 = d["debts"][0]
assert item0["line"] == 3
assert item0["open"] is True
assert "quotes" in item0["text"]
assert "backslashes" in item0["text"]
assert "tab1\ttomb" in item0["text"]
assert item0["text"].startswith("- [ ] DEBT:")

# Item 2: closed with lowercase x
item1 = d["debts"][1]
assert item1["line"] == 4
assert item1["open"] is False
assert "04-adr" in item1["text"]
assert item1["text"].startswith("- [x] DEBT:")

# Item 3: closed with uppercase X
item2 = d["debts"][2]
assert item2["line"] == 5
assert item2["open"] is False
assert "temp auth bypass" in item2["text"]
assert item2["text"].startswith("- [X] DEBT:")
'
  ck 0 $? "populated JSON parses via python with correct open/closed status, lines, and escaped chars"
else
  echo "  skip [populated JSON parses via python with correct open/closed status, lines, and escaped chars] (no python on this PATH)"
fi

# Flag-order and shorthand parity on populated fixture
out_pop_shorthand="$(bash "$RUN" debt --json 2>&1)"; rc_pop_shorthand=$?
ck 0 $rc_pop_shorthand "populated debt --json exit 0"
ck "$out_pop" "$out_pop_shorthand" "populated debt --json identical to debt list --json"

out_pop_prefix="$(bash "$RUN" debt --json list 2>&1)"; rc_pop_prefix=$?
ck 0 $rc_pop_prefix "populated debt --json list exit 0"
ck "$out_pop" "$out_pop_prefix" "populated debt --json list identical to debt list --json"

# Prose parity with open debts
out_pop_prose="$(bash "$RUN" debt list 2>&1)"; rc_pop_prose=$?
ck 0 $rc_pop_prose "prose debt list with open debts exit 0"
has "$out_pop_prose" "OPEN debts (close before their named condition):" "prose lists OPEN debts header"
has "$out_pop_prose" "  L3:- \[ \] DEBT: skip 01-research" "prose lists line 3 with L prefix"
no "$out_pop_prose" "04-adr" "prose omits closed debt line 4"
no "$out_pop_prose" "temp auth bypass" "prose omits closed debt line 5"

out_pop_prose_bare="$(bash "$RUN" debt 2>&1)"; rc_pop_prose_bare=$?
ck 0 $rc_pop_prose_bare "prose bare debt with open debts exit 0"
ck "$out_pop_prose" "$out_pop_prose_bare" "prose bare debt matches debt list"

# 3. Closed-only DEBT.md fixture
printf '# DEBT\n\n- [x] DEBT: all settled -- exp -- close before: prod -- opened 2026-10-17\n' > "$SB/DEBT.md"
out_closed="$(bash "$RUN" debt list --json 2>&1)"; rc_closed=$?
ck 0 $rc_closed "closed-only debt list --json exit 0"
has "$out_closed" '"total":1' "closed-only JSON total 1"
has "$out_closed" '"open_count":0' "closed-only JSON open_count 0"
if [ -n "$PY_BIN" ]; then
  printf '%s' "$out_closed" | "$PY_BIN" -c '
import sys, json
d = json.load(sys.stdin)
assert d["total"] == 1
assert d["open_count"] == 0
assert len(d["debts"]) == 1
assert d["debts"][0]["open"] is False
assert d["debts"][0]["line"] == 3
'
  ck 0 $? "closed-only JSON parses via python with open_count 0"
else
  echo "  skip [closed-only JSON parses via python with open_count 0] (no python on this PATH)"
fi

out_closed_prose="$(bash "$RUN" debt list 2>&1)"; rc_closed_prose=$?
ck 0 $rc_closed_prose "prose debt list closed-only exit 0"
ck "No OPEN debts (all closed)." "$out_closed_prose" "prose reports No OPEN debts (all closed)."

# 4. Error handling & invalid / duplicate flags exit 2
out_err="$(bash "$RUN" debt --json --json 2>&1)"; rc_err=$?
ck 2 $rc_err "duplicate flag debt --json --json exit 2"
has "$out_err" "usage: /flow debt" "duplicate flag prints usage"

out_err="$(bash "$RUN" debt list --json --json 2>&1)"; rc_err=$?
ck 2 $rc_err "duplicate flag debt list --json --json exit 2"

out_err="$(bash "$RUN" debt --json list --json 2>&1)"; rc_err=$?
ck 2 $rc_err "duplicate flag debt --json list --json exit 2"

out_err="$(bash "$RUN" debt --bogus 2>&1)"; rc_err=$?
ck 2 $rc_err "unknown flag debt --bogus exit 2"

out_err="$(bash "$RUN" debt list --bogus 2>&1)"; rc_err=$?
ck 2 $rc_err "unknown flag debt list --bogus exit 2"

out_err="$(bash "$RUN" debt list extra 2>&1)"; rc_err=$?
ck 2 $rc_err "extra arg debt list extra exit 2"

out_err="$(bash "$RUN" debt --json extra 2>&1)"; rc_err=$?
ck 2 $rc_err "extra arg debt --json extra exit 2"

out_err="$(bash "$RUN" debt --json add "what" "exp" "close" 2>&1)"; rc_err=$?
ck 2 $rc_err "invalid flag on add debt --json add exit 2"

out_err="$(bash "$RUN" debt bogus 2>&1)"; rc_err=$?
ck 2 $rc_err "unknown subcommand debt bogus exit 2"

out_err="$(bash "$RUN" debt "" 2>&1)"; rc_err=$?
ck 2 $rc_err "empty positional arg debt '' exit 2"

# 5. debt add prose and exit code non-regression
out_add_fail="$(bash "$RUN" debt add 2>&1)"; rc_add_fail=$?
ck 1 $rc_add_fail "debt add missing args exit 1"
ck 'usage: /flow debt add "<what skipped>" "<exposure>" "<close-before condition>"' "$out_add_fail" "debt add missing args prints exact legacy usage"

out_add_ok="$(bash "$RUN" debt add "new item" "exposure desc" "close condition" 2>&1)"; rc_add_ok=$?
ck 0 $rc_add_ok "debt add valid args exit 0"
has "$out_add_ok" "PASS: debt recorded in DEBT.md" "debt add reports PASS"

rm -rf "$SB"

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
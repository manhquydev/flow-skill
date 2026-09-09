#!/usr/bin/env bash
# Mechanical midtier scanners inside scan_gate (plan 260909-1119 phase 3).
# Run: bash tests/test_flow_midtier_scanners.sh
# Exit 0 = all pass, 1 = any fail.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
EVAL_DIR="$HERE/../skills/flow/eval"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected='$1' got='$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q -- "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q -- "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

_portable_timeout() { # $1 = seconds, rest = command
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return $?; fi
  "$@" & local pid=$!
  ( sleep "$secs" 2>/dev/null; kill -TERM "$pid" 2>/dev/null ) & local watchdog=$!
  wait "$pid" 2>/dev/null; local rc=$?
  kill "$watchdog" 2>/dev/null; wait "$watchdog" 2>/dev/null
  return "$rc"
}

newsb() {
  SB="$(mktemp -d)"
  mkdir -p "$SB/flow" "$SB/cards"
  export FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_DISABLE=1 FLOW_LOG_DISABLE=1
}

clean() { rm -rf "$SB" 2>/dev/null; unset FLOW_PROJECT_ROOT FLOW_SESSION_ID; }

stage_clean() { # $1=basename without .md  $2=path
  printf '# %s\n## Gate\n- [x] honestly done\n\nreal content.\n' "$1" > "$2"
}

G() { bash "$RUN" gate "$1" 2>&1; }
N() { bash "$RUN" next 2>&1; }

hide_claude_bin() {
  fakebin="$(mktemp -d)"
  for d in /usr/bin /bin; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      [ -e "$f" ] || continue
      b="$(basename "$f")"
      case "$b" in claude|claude.exe|claude.cmd) continue ;; esac
      [ -e "$fakebin/$b" ] || ln -s "$f" "$fakebin/$b" 2>/dev/null || cp "$f" "$fakebin/$b" 2>/dev/null
    done
  done
  printf '%s' "$fakebin"
}

echo "A) 00+web-typed 01 with 2 hostnames -> next FAIL; 3 bare domains PASS"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
printf 'web\n' > "$SB/PROJECT_TYPE"
cat > "$SB/flow/01-research.md" <<'EOF'
# Research
## Gate
- [x] opened tools
## What exists already
1. Alpha (alpha.dev) — note
2. Beta (beta.io) — note
EOF
out="$(N)"; ck 1 $? "next exits 1 on 2 hostnames typed-web"
has "$out" "typed web" "FAIL names typed-web hostname floor"
has "$out" "[x]" "midtier [x] printed"
clean

newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
printf 'web\n' > "$SB/PROJECT_TYPE"
cat > "$SB/flow/01-research.md" <<'EOF'
# Research
## Gate
- [x] opened tools
## What exists already
1. Alpha (alpha.dev) — note
2. Beta (beta.io) — note
3. Gamma (gamma.org) — note
EOF
out="$(N)"; ck 0 $? "next exits 0 on 3 bare domains typed-web"
clean

echo "B) f01a copy without PROJECT_TYPE file PASSES (URL floor off)"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
cp "$EVAL_DIR/fixtures/f01a/flow/01-research.md" "$SB/flow/01-research.md"
out="$(G 01-research)"; ck 0 $? "f01a 01-research gate clean with no PROJECT_TYPE"
out="$(N)"; ck 0 $? "next PASSes f01a-shaped research when untyped"
clean

echo "B2) typed-web f01a copy PASSES (3 numbered incumbents, 2 host.tld)"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
printf 'web\n' > "$SB/PROJECT_TYPE"
cp "$EVAL_DIR/fixtures/f01a/flow/01-research.md" "$SB/flow/01-research.md"
out="$(G 01-research)"; ck 0 $? "typed-web f01a gate 01-research exit 0"
clean

echo "C) no PROJECT_TYPE file -> URL scanner off even with 2 hostnames"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
cat > "$SB/flow/01-research.md" <<'EOF'
# Research
## Gate
- [x] opened tools
## What exists already
1. Alpha (alpha.dev)
2. Beta (beta.io)
EOF
out="$(G 01-research)"; ck 0 $? "2 hostnames without PROJECT_TYPE file do not trip URL floor"
clean

echo "D) PROJECT_TYPE=cli (file exists, not web) -> URL floor off"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
printf 'cli\n' > "$SB/PROJECT_TYPE"
cat > "$SB/flow/01-research.md" <<'EOF'
# Research
## Gate
- [x] opened tools
## What exists already
1. Alpha (alpha.dev)
2. Beta (beta.io)
EOF
out="$(G 01-research)"; ck 0 $? "typed cli does not apply hostname floor"
clean

echo "E) wrapped L then grade B FAIL; L grade A PASS"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
stage_clean "Research" "$SB/flow/01-research.md"
cat > "$SB/flow/02-scope.md" <<'EOF'
# Scope
## Gate
- [x] every feature has impact and grade
## Features in v1
- Shared calendar
  impact L (nice-to-have)
  grade B — 3rd-party integration
## Open decisions
EOF
out="$(G 02-scope)"; ck 1 $? "wrapped L+B fails gate"
has "$out" "L-impact" "names L-impact above A"
clean

newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
stage_clean "Research" "$SB/flow/01-research.md"
cat > "$SB/flow/02-scope.md" <<'EOF'
# Scope
## Gate
- [x] every feature has impact and grade
## Features in v1
- Shared calendar — impact L — grade A — cheap CRUD
## Open decisions
EOF
out="$(G 02-scope)"; ck 0 $? "L + grade A PASSes mechanical L-above-A"
clean

echo "F) PRD Features 'secure API' FAIL; gate checkbox 'secure' PASS"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
stage_clean "Research" "$SB/flow/01-research.md"
stage_clean "Scope" "$SB/flow/02-scope.md"
cat > "$SB/flow/03-prd.md" <<'EOF'
# PRD
## Gate — check ALL before next
- [x] No unquantified adjectives (fast / secure / intuitive / robust / prominent) in Features or NFRs
## Features
- FR1: As a user I call a secure API and I see 200
## Non-functional requirements
none
## Open decisions
EOF
out="$(G 03-prd)"; ck 1 $? "Features body 'secure API' fails adjective scan"
has "$out" "secure" "names the adjective"
clean

newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
stage_clean "Research" "$SB/flow/01-research.md"
stage_clean "Scope" "$SB/flow/02-scope.md"
cat > "$SB/flow/03-prd.md" <<'EOF'
# PRD
## Gate — check ALL before next
- [x] No unquantified adjectives (fast / secure / intuitive / robust / prominent) in Features or NFRs
## Features
- FR1: As a user I submit a form and I see a confirmation
## Non-functional requirements
page load < 2s
## Open decisions
EOF
out="$(G 03-prd)"; ck 0 $? "gate checkbox containing secure PASSes (body has no adjective)"
clean

echo "G) 6 open-decision bullets FAIL (checked or not)"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
stage_clean "Research" "$SB/flow/01-research.md"
cat > "$SB/flow/02-scope.md" <<'EOF'
# Scope
## Gate
- [x] ok
## Features in v1
- Core job — impact H — grade A
## Open decisions
- [x] one
- [x] two
- [x] three
- [x] four
- [x] five
- [x] six
EOF
out="$(G 02-scope)"; ck 1 $? "6 open-decision bullets fail"
has "$out" "Open decisions" "names open-decisions cap"
clean

echo "H) timeout 20 status+next on scanner-dirty box-clean 02"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
stage_clean "Research" "$SB/flow/01-research.md"
cat > "$SB/flow/02-scope.md" <<'EOF'
# Scope
## Gate
- [x] every feature has impact and grade
## Features in v1
- Shared calendar
  impact L (nice-to-have)
  grade B
## Open decisions
EOF
out="$(_portable_timeout 20 bash "$RUN" status 2>&1)"; rc=$?
ck 0 "$rc" "status on scanner-dirty 02 returns (not 124)"
has "$out" "NEXT_VERB=fix-gate" "status prints NEXT_VERB=fix-gate"
out="$(_portable_timeout 20 bash "$RUN" next 2>&1)"; rc=$?
ck 1 "$rc" "next on scanner-dirty 02 exits 1"
clean

echo "I) NEXT_VERB on resume idx<0 and status empty project"
newsb
out="$(bash "$RUN" resume 2>&1)"; rc=$?
ck 0 "$rc" "resume with no stages exits 0"
has "$out" "NEXT_VERB=next" "resume idx<0 prints NEXT_VERB=next"
out="$(bash "$RUN" status 2>&1)"
has "$out" "NEXT ->" "status still has NEXT ->"
has "$out" "NEXT_VERB=next" "status prints NEXT_VERB=next"
clean

echo "J) card gate --card ignores midtier smells (box/FILL only)"
newsb
cat > "$SB/cards/C-001.md" <<'EOF'
# C-001 — one thing
status: todo
deps: none
implements: FR1
risk: unknown
risk-reason:
risk-ack: none
## Scope
impact L grade B secure API alpha.dev beta.io
## Independent test
user can click
## Allowed files
src/
## Verify (run these before done)
- [x] curl 200
## Done-evidence
a live URL
## Evidence
(empty until done)
## Open decisions
- [x] one
- [x] two
- [x] three
- [x] four
- [x] five
- [x] six
EOF
out="$(bash "$RUN" gate --card C-001 2>&1)"; rc=$?
ck 0 "$rc" "gate --card PASSes a box-clean card with midtier smells"
no "$out" "typed web" "card path does not run hostname floor"
no "$out" "L-impact" "card path does not run L-above-A"
no "$out" "unquantified" "card path does not run adjective scan"
no "$out" "Open decisions" "card path does not cap open-decisions"
clean

echo "K) 00-inspect.md unchanged (not in basename allowlist)"
newsb
printf 'web\n' > "$SB/PROJECT_TYPE"
cat > "$SB/flow/00-inspect.md" <<'EOF'
# Inspect
## Gate
- [x] done
## What exists already
1. Alpha (alpha.dev)
2. Beta (beta.io)
EOF
out="$(bash "$RUN" status 2>&1)"
has "$out" "brownfield: assessment present, gate clean" "00-inspect with 2 hostnames stays box/FILL only"
clean

echo "L) planning_complete false when 01 is midtier-dirty; FLOW_LAST_GATE_FAIL counts midtier"
newsb
unset FLOW_LOG_DISABLE
export FLOW_SESSION_ID=midtierA
stage_clean "Idea" "$SB/flow/00-idea.md"
stage_clean "Scope" "$SB/flow/02-scope.md"
stage_clean "PRD" "$SB/flow/03-prd.md"
stage_clean "ADR" "$SB/flow/04-adr.md"
stage_clean "Contract" "$SB/flow/05-contract.md"
printf 'web\n' > "$SB/PROJECT_TYPE"
cat > "$SB/flow/01-research.md" <<'EOF'
# Research
## Gate
- [x] opened
## What exists already
1. Alpha (alpha.dev)
2. Beta (beta.io)
EOF
out="$(bash "$RUN" card 2>&1)"; ck 1 $? "card refused while 01 midtier-dirty (planning_complete false)"
has "$out" "finish planning" "card names finish planning"
clean

newsb
unset FLOW_LOG_DISABLE
export FLOW_SESSION_ID=midtierB
stage_clean "Idea" "$SB/flow/00-idea.md"
printf 'web\n' > "$SB/PROJECT_TYPE"
cat > "$SB/flow/01-research.md" <<'EOF'
# Research
## Gate
- [x] opened
## What exists already
1. Alpha (alpha.dev)
2. Beta (beta.io)
EOF
out="$(N)"; ck 1 $? "next fails on dirty 01 (current stage)"
ev="$(cat "$SB/.flow/events.jsonl" 2>/dev/null | tail -1)"
has "$ev" "midtier:1" "FLOW_LAST_GATE_FAIL persisted midtier count 1"
clean
export FLOW_LOG_DISABLE=1

echo "M) grep -cF unmeasured == 3; PATH-hidden claude eval/routing/converge exit 0"
n="$(grep -cF 'semantic layer unmeasured on this host' "$RUN")"
ck "3" "$n" "unmeasured phrase appears exactly 3 times in flow.sh"
fakebin="$(hide_claude_bin)"
if PATH="$fakebin" command -v claude >/dev/null 2>&1; then
  echo "  skip [claude-absent] (platform still resolves claude; cannot hide it here)"
else
  newsb
  out="$(PATH="$fakebin" bash "$RUN" eval 2>&1)"; ck 0 $? "eval SKIP exit 0"
  has "$out" "semantic layer unmeasured on this host" "eval SKIP names unmeasured"
  out="$(PATH="$fakebin" bash "$RUN" eval --stage routing 2>&1)"; ck 0 $? "routing SKIP exit 0"
  has "$out" "semantic layer unmeasured on this host" "routing SKIP names unmeasured"
  out="$(PATH="$fakebin" bash "$RUN" eval --stage converge 2>&1)"; ck 0 $? "converge SKIP exit 0"
  has "$out" "semantic layer unmeasured on this host" "converge SKIP names unmeasured"
  clean
fi
rm -rf "$fakebin"

echo "N) manifest.txt registers this suite"
has "$(cat "$HERE/manifest.txt" 2>/dev/null)" "test_flow_midtier_scanners.sh" "manifest.txt lists test_flow_midtier_scanners.sh"

echo "O) H-impact grade C does not trip L-above-A (C-launder is semantic, not this scanner)"
newsb
stage_clean "Idea" "$SB/flow/00-idea.md"
stage_clean "Research" "$SB/flow/01-research.md"
cat > "$SB/flow/02-scope.md" <<'EOF'
# Scope
## Gate
- [x] ok
## Features in v1
- Payments — impact H — grade C — the product
## Open decisions
EOF
out="$(G 02-scope)"; ck 0 $? "H+C does not fail mechanical L-above-A"
clean

echo "P) type lock holds after artifacts exist even when 01 is midtier-dirty"
newsb
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do
  printf '#%s\n## Gate\n- [x] ok\n\nbody\n' "$s" > "$SB/flow/$s.md"
done
bash "$RUN" project-type web >/dev/null; ck 0 $? "first type set after artifacts present"
out="$(bash "$RUN" project-type cli 2>&1)"; ck 1 $? "flip refused while 01 midtier-dirty"
has "$out" "locked" "type lock names locked despite dirty 01"
clean

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
exit $?

#!/usr/bin/env bash
# Regression suite for the flow.sh multi-agent worktree layer ('workspace' verb family).
# Run: bash tests/test_flow_workspace.sh   (Git Bash on Windows or any POSIX bash)
# Exit 0 = all pass, 1 = any fail.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
pass=0; fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected '$1' got '$2'"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail+1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

# A real git repo with one commit (worktree add needs a HEAD). FLOW_SESSION_ID makes the lock strong.
newsb() {
  SB="$(mktemp -d)"; export FLOW_PROJECT_ROOT="$SB"; export FLOW_SESSION_ID=WS
  git -C "$SB" init -q
  git -C "$SB" config user.email t@t; git -C "$SB" config user.name t
  git -C "$SB" commit -q --allow-empty -m init
}
clean() { # remove the sandbox AND any sibling worktrees it spawned
  local base; base="$(dirname "$SB")/$(basename "$SB")"
  local d; for d in "$base"-*; do [ -d "$d" ] && rm -rf "$d" 2>/dev/null; done
  rm -rf "$SB" 2>/dev/null
}
reg() { cat "$SB/.flow/workspaces.jsonl" 2>/dev/null; }                 # raw registry
# valid-JSON-ish: every non-empty line has the closing field "status":"..."  (torn lines lack it)
parseable_lines() { reg | grep -c '"status":"[a-z]*"}$' 2>/dev/null; }
total_lines()     { reg | grep -c . 2>/dev/null; }

echo "A) add creates a worktree + exactly one active JSON record (C-001/C-002)"
newsb
out="$(bash "$RUN" workspace add feat-a --vendor codex --task 'csv, with comma' --card C-007 2>&1)"; rc=$?
ck 0 "$rc" "add exit 0"
has "$out" "PASS: created worktree for 'feat-a'" "add prints PASS"
ck 0 "$([ -d "$(dirname "$SB")/$(basename "$SB")-feat-a" ] && echo 0 || echo 1)" "sibling worktree dir created"
ck 1 "$(total_lines)" "exactly one registry line"
has "$(reg)" '"branch":"feat-a"' "record has branch"
has "$(reg)" '"task_label":"csv, with comma"' "task with comma stored intact"
has "$(reg)" '"port_offset":0' "first port_offset is 0"
clean

echo "B) second add derives a DISTINCT port (lock-held max+1, graft G3)"
newsb
bash "$RUN" workspace add feat-a >/dev/null 2>&1
out="$(bash "$RUN" workspace add feat-b 2>&1)"; rc=$?
ck 0 "$rc" "second add exit 0"
has "$out" "port-offset 1" "second workspace gets port-offset 1"
clean

echo "C) re-adding the same branch fails and relays git VERBATIM (FR2)"
newsb
bash "$RUN" workspace add feat-a >/dev/null 2>&1
out="$(bash "$RUN" workspace add feat-a 2>&1)"; rc=$?
ck 1 "$rc" "re-add exit 1"
has "$out" "fatal" "git's verbatim fatal relayed"
clean

echo "D) list joins git worktree list + registry (FR3); main worktree shows vendor '-'"
newsb
bash "$RUN" workspace add feat-a --vendor codex --card C-007 >/dev/null 2>&1
bash "$RUN" workspace add feat-b --vendor claude >/dev/null 2>&1
out="$(bash "$RUN" workspace list 2>&1)"; rc=$?
ck 0 "$rc" "list exit 0"
has "$out" "feat-a .*codex .*C-007" "feat-a row shows vendor+card"
has "$out" "feat-b .*claude" "feat-b row shows vendor"
clean

echo "E) enter re-prints the cd + PORT block; unknown branch exits 1"
newsb
bash "$RUN" workspace add feat-a --vendor codex >/dev/null 2>&1
out="$(bash "$RUN" workspace enter feat-a 2>&1)"; rc=$?
ck 0 "$rc" "enter exit 0"
has "$out" "export PORT=" "enter prints PORT export"
has "$out" "CODEX_HOME" "codex vendor gets CODEX_HOME hint"
out="$(bash "$RUN" workspace enter nope 2>&1)"; rc=$?
ck 1 "$rc" "enter on unknown branch exits 1"
clean

echo "F) git absent -> add/remove exit 1, read verbs exit 0 (graceful degrade)"
newsb
# Symlink farm of the core bin dirs MINUS git, so flow.sh's coreutils run but 'command -v git' fails.
# Bounded to /usr/bin + /bin (fast + present on all 3 OSes); git lives there on Linux/macOS so it is
# explicitly excluded, and lives elsewhere on Git Bash so it is absent regardless.
fakebin="$(mktemp -d)"
for d in /usr/bin /bin; do
  [ -d "$d" ] || continue
  for f in "$d"/*; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in git|git.exe) continue ;; esac
    [ -e "$fakebin/$b" ] || ln -s "$f" "$fakebin/$b" 2>/dev/null || cp "$f" "$fakebin/$b" 2>/dev/null
  done
done
if PATH="$fakebin" command -v git >/dev/null 2>&1; then
  echo "  skip [git-absent] (platform still resolves git; cannot hide it here)"
else
  out="$(PATH="$fakebin" bash "$RUN" workspace add x 2>&1)"; rc=$?
  ck 1 "$rc" "add exit 1 without git"
  has "$out" "git not found" "add explains git missing"
  out="$(PATH="$fakebin" bash "$RUN" workspace list 2>&1)"; rc=$?
  ck 0 "$rc" "list exit 0 without git (read verb degrades)"
fi
rm -rf "$fakebin"; clean

echo "G) remove: dirty tree refused VERBATIM; --force removes + tombstones (C-003)"
newsb
bash "$RUN" workspace add feat-a >/dev/null 2>&1
echo dirty > "$(dirname "$SB")/$(basename "$SB")-feat-a/untracked.txt"   # make the worktree unclean
out="$(bash "$RUN" workspace remove feat-a 2>&1)"; rc=$?
ck 1 "$rc" "remove refuses an unclean tree"
has "$out" "FAIL: git worktree remove refused" "refusal message"
out="$(bash "$RUN" workspace remove feat-a --force 2>&1)"; rc=$?
ck 0 "$rc" "--force removes"
has "$(reg)" '"status":"removed"' "tombstone appended on clean removal"
out="$(bash "$RUN" workspace list 2>&1)"
no "$out" "feat-a " "removed branch no longer an active worktree"
clean

echo "H) doctor: clean -> exit 0; orphan RECORD and orphan TREE -> exit 1 (FR8)"
newsb
bash "$RUN" workspace add feat-a >/dev/null 2>&1
out="$(bash "$RUN" workspace doctor 2>&1)"; rc=$?
ck 0 "$rc" "doctor clean exit 0"
has "$out" "PASS: no drift" "doctor reports no drift"
# inject an orphan RECORD (active record whose worktree path does not exist)
printf '{"worktree_path":"/no/such","branch":"ghost","vendor":"-","agent_session_id":"x","card_id":"","task_label":"","owned_files_glob":"","port_offset":9,"created_at":1,"status":"active"}\n' >> "$SB/.flow/workspaces.jsonl"
# inject an orphan TREE (a worktree created directly by git, no flow record)
git -C "$SB" worktree add "$(dirname "$SB")/$(basename "$SB")-rogue" -b rogue >/dev/null 2>&1
out="$(bash "$RUN" workspace doctor 2>&1)"; rc=$?
ck 1 "$rc" "doctor flags drift exit 1"
has "$out" "ORPHAN RECORDS" "doctor names the orphan record"
has "$out" "ORPHAN TREES" "doctor names the orphan tree"
clean

echo "I) check: allowed-files overlap with an active card -> exit 1; disjoint -> exit 0"
newsb
mkdir -p "$SB/cards"
printf '# C-001\nstatus: todo\ndeps: none\n## Scope\nx\n## Allowed files\n- src/pay/**\n- tests/pay/**\n## Verify\n## Done-evidence\n## Evidence\n' > "$SB/cards/C-001.md"
printf '# C-002\nstatus: todo\ndeps: none\n## Scope\nx\n## Allowed files\n- src/pay/**\n## Verify\n## Done-evidence\n## Evidence\n' > "$SB/cards/C-002.md"
printf '# C-003\nstatus: todo\ndeps: none\n## Scope\nx\n## Allowed files\n- src/auth/**\n## Verify\n## Done-evidence\n## Evidence\n' > "$SB/cards/C-003.md"
bash "$RUN" workspace add card-1 --card C-001 >/dev/null 2>&1     # active workspace owns src/pay/**
out="$(bash "$RUN" workspace check card-2 --card C-002 2>&1)"; rc=$?
ck 1 "$rc" "overlapping card check exits 1"
has "$out" "overlap with active card C-001" "names the colliding card"
out="$(bash "$RUN" workspace check card-3 --card C-003 2>&1)"; rc=$?
ck 0 "$rc" "disjoint card check exits 0"
has "$out" "PASS:" "disjoint check passes"
# branch already claimed -> exit 1
out="$(bash "$RUN" workspace check card-1 2>&1)"; rc=$?
ck 1 "$rc" "check on an already-claimed branch exits 1"
clean

echo "J) FM7 torn-line: a truncated final record is SKIPPED; last valid record still resolves"
newsb
bash "$RUN" workspace add feat-a --vendor codex >/dev/null 2>&1
printf '{"worktree_path":"/x","branch":"feat-a","vendor":"codex","agent_sess' >> "$SB/.flow/workspaces.jsonl"   # torn (no newline, no status)
out="$(bash "$RUN" workspace enter feat-a 2>&1)"; rc=$?
ck 0 "$rc" "enter still resolves the last valid record despite a torn trailing line"
has "$out" "export PORT=" "valid record survives the torn line"
out="$(bash "$RUN" workspace doctor 2>&1)"; rc=$?
ck 0 "$rc" "doctor does not choke on the torn line"
clean

echo "K) FM2 concurrency: 4 distinct-session adds keep the registry parseable + active ports distinct"
newsb
for i in 1 2 3 4; do ( FLOW_SESSION_ID="S$i" bash "$RUN" workspace add "br$i" >/dev/null 2>&1 ) & done
wait
tl="$(total_lines)"; pl="$(parseable_lines)"
ck "$tl" "$pl" "every registry line is well-formed (no torn/corrupt line under concurrency)"
# active ports must be distinct (lock serializes successful adds; blocked ones simply retry IRL)
ndistinct="$(bash "$RUN" workspace doctor 2>&1 | grep -c 'duplicate port_offset' || true)"
ck 0 "$ndistinct" "no duplicate port_offset among the workspaces that won the lock"
clean

echo "L) lift refactor: cmd_ready still emits allowed-files via the shared helper (no regression)"
newsb
export MODE=work
# minimal complete planning so 'ready' runs: stub all stage gates clean + one card
mkdir -p "$SB/flow" "$SB/cards"
for s in 00-idea 01-research 02-scope 03-prd 04-adr 05-contract; do printf '# %s\n## Gate\n- [x] ok\n\nreal.\n' "$s" > "$SB/flow/$s.md"; done
printf '# C-001\nstatus: todo\ndeps: none\n## Scope\nx\n## Allowed files\n- src/app.ts\n## Verify\n## Done-evidence\n## Evidence\n' > "$SB/cards/C-001.md"
out="$(bash "$RUN" ready 2>&1)"; rc=$?
ck 0 "$rc" "ready exit 0"
has "$out" "allowed: - src/app.ts" "ready prints allowed-files via _card_allowed_files"
clean

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

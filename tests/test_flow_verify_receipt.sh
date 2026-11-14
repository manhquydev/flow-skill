#!/usr/bin/env bash
# Regression suite for the card verify-command receipt feature:
# `verify-command: <cmd>` frontmatter runs the command at check/done time,
# records a sha256 receipt event, and fails the gate BEFORE any status change.
# Run: bash tests/test_flow_verify_receipt.sh  (Git Bash on Windows or any POSIX bash)
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../skills/flow/runner/flow.sh"
HARNESS_PY="$HERE/../skills/flow/harness/flow_harness.py"
PY="$(command -v python3 || command -v python)"
pass=0
fail=0
ck()  { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass + 1)); else echo "  FAIL [$3] expected='$1' got='$2'"; fail=$((fail + 1)); fi; }
has() { if printf '%s' "$1" | grep -q "$2"; then echo "  ok   [$3]"; pass=$((pass + 1)); else echo "  FAIL [$3] (missing: $2)"; fail=$((fail + 1)); fi; }
no()  { if printf '%s' "$1" | grep -q "$2"; then echo "  FAIL [$3] (unexpected: $2)"; fail=$((fail+1)); else echo "  ok   [$3]"; pass=$((pass+1)); fi; }

mkcard() { # $1 verify-command line ('' = none)
  SB="$(mktemp -d)"
  export FLOW_PROJECT_ROOT="$SB"
  export HOME="$SB/home"
  mkdir -p "$SB/home" "$SB/cards"
  git -C "$SB" init -q
  git -C "$SB" config user.email "t@example.com"
  git -C "$SB" config user.name "T"
  {
    printf '# C-001 — receipt fixture\nstatus: todo\ndeps: none\n'
    [ -n "$1" ] && printf 'verify-command: %s\n' "$1"
    printf '## Scope\none thing\n## Allowed files\nout.txt\n## Verify\n- [x] echo hello\n## Done-evidence\nurl\n## Evidence\n$ curl https://x/healthz -> {"ok":true}\n'
  } > "$SB/cards/C-001.md"
}

echo "A) verify-command pass: card done OK + JSONL receipt with 64-hex sha256"
mkcard 'echo verify-out hello'
out="$(bash "$RUN" card done C-001 2>&1)"; rc=$?
ck 0 "$rc" "card done exits 0 with passing verify-command"
has "$out" "PASS: C-001 is valid" "done-gate passes"
ev="$(grep 'verify-receipt' "$SB/.flow/events.jsonl" 2>/dev/null | tail -1)"
[ -n "$ev" ] && ck 0 0 "verify-receipt event present" || ck 0 1 "verify-receipt event present"
has "$ev" '"card":"C-001"' "event carries card id"
has "$ev" '"cmd":"echo verify-out hello"' "event carries the command"
has "$ev" '"exit_code":0' "event carries exit_code 0"
sha="$(printf '%s' "$ev" | sed -nE 's/.*"sha256":"([0-9a-f]{64})".*/\1/p')"
expected_sha="$(printf 'verify-out hello\n' | sha256sum 2>/dev/null | awk '{print $1}')"
[ -n "$expected_sha" ] || expected_sha="$(printf 'verify-out hello\n' | shasum -a 256 2>/dev/null | awk '{print $1}')"
ck "$expected_sha" "$sha" "sha256 matches exact output digest (including trailing newline)"
st="$(sed -n 's/^status: *//p' "$SB/cards/C-001.md" | tr -d '[:space:]')"
ck done "$st" "status flipped to done"
rm -rf "$SB"

echo "B) verify-command fail: gate fails, diagnostic + last lines, status unchanged"
mkcard 'echo boom; exit 3'
out="$(bash "$RUN" card done C-001 2>&1)"; rc=$?
ck 1 "$rc" "card done exits 1 on failing verify-command"
has "$out" "FAIL: verify-command exited 3" "diagnostic names the exit code"
has "$out" "boom" "merged output tail shown"
has "$out" "status unchanged" "status-unchanged notice"
st="$(sed -n 's/^status: *//p' "$SB/cards/C-001.md" | tr -d '[:space:]')"
ck todo "$st" "status stays todo (no mutation)"
ev="$(grep 'verify-receipt' "$SB/.flow/events.jsonl" 2>/dev/null | tail -1)"
has "$ev" '"exit_code":3' "receipt event records exit_code 3"
rm -rf "$SB"

echo "C) control: no verify-command frontmatter -> unchanged behavior, no receipt event"
mkcard ''
out="$(bash "$RUN" card done C-001 2>&1)"; rc=$?
ck 0 "$rc" "card done exits 0 without verify-command"
no_ev="$(grep -c 'verify-receipt' "$SB/.flow/events.jsonl" 2>/dev/null)"
no_ev="${no_ev:-0}"
ck 0 "$no_ev" "no verify-receipt event for a card without frontmatter"
st="$(sed -n 's/^status: *//p' "$SB/cards/C-001.md" | tr -d '[:space:]')"
ck done "$st" "status flipped to done (control)"
rm -rf "$SB"

echo "D) harness rollup: verify-receipt JSONL lands in verify_receipt table"
if [ -n "$PY" ] && "$PY" --version >/dev/null 2>&1; then
  mkcard 'printf receipt-rollup'
  bash "$RUN" card done C-001 >/dev/null 2>&1
  FLOW_PROJECT_ROOT="$SB" "$PY" "$HARNESS_PY" init >/dev/null 2>&1
  FLOW_PROJECT_ROOT="$SB" "$PY" "$HARNESS_PY" rollup >/dev/null 2>&1
  q="$("$PY" -c '
import os, sqlite3, sys
db = os.path.join(os.environ["FLOW_PROJECT_ROOT"], ".flow", "harness.db")
con = sqlite3.connect(db)
rows = con.execute("SELECT card, cmd, sha256, exit_code FROM verify_receipt WHERE card=\"C-001\" AND exit_code=0").fetchall()
print(len(rows))
if rows:
    r = rows[0]
    expected_rollup_sha = "e80a1dbbbe3f4db75e7edd14ac065e32632b08bb9e7ef8b09515b7cc2fbc7664" # sha256 of "receipt-rollup"
    ok = (r[2] == expected_rollup_sha) and ("receipt-rollup" in r[1])
    print("SHA-OK" if ok else "SHA-BAD: " + r[2])
else:
    print("SHA-NA")
' 2>&1)"
  has "$q" "^1$" "rollup inserted a verify_receipt row"
  has "$q" "SHA-OK" "rolled-up sha256/cmd fields sane"
  rm -rf "$SB"
else
  echo "  SKIP [python unavailable: rollup assertion skipped]"
fi
echo "E) body text containing verify-command is ignored (only header frontmatter parsed)"
mkcard ''
cat << 'EOC' > "$SB/cards/C-001.md"
# C-001 — no header verify command
status: todo
deps: none
## Scope
Example in body text:
verify-command: echo hostile-body-command; exit 99
## Allowed files
out.txt
## Verify
- [x] echo hello
## Done-evidence
url
## Evidence
$ curl https://x/healthz -> {"ok":true}
EOC
out="$(bash "$RUN" card done C-001 2>&1)"; rc=$?
ck 0 "$rc" "card done exits 0 ignoring body verify-command"
no "$out" "hostile-body-command" "body verify-command was not executed"
st="$(sed -n 's/^status: *//p' "$SB/cards/C-001.md" | tr -d '[:space:]')"
ck done "$st" "card flipped to done"
rm -rf "$SB"

echo "F) inline secrets in verify-command are masked in verify-receipt event"
mkcard 'curl -H "Authorization: Bearer secret_bearer_token_12345" http://localhost:8080'
bash "$RUN" card done C-001 >/dev/null 2>&1
ev="$(grep 'verify-receipt' "$SB/.flow/events.jsonl" 2>/dev/null | tail -1)"
has "$ev" '***redacted***' "secret command masked"
no "$ev" 'secret_bearer_token_12345' "raw secret not in JSONL event"
rm -rf "$SB"

echo "G) FLOW_LOG_DISABLE=1 suppresses verify-receipt event logging"
mkcard 'echo optout-test'
FLOW_LOG_DISABLE=1 bash "$RUN" card done C-001 >/dev/null 2>&1
no_ev="$(grep -c 'verify-receipt' "$SB/.flow/events.jsonl" 2>/dev/null || true)"
no_ev="${no_ev:-0}"
ck 0 "$no_ev" "no verify-receipt emitted when FLOW_LOG_DISABLE=1"
rm -rf "$SB"

echo "H) verify-command executes only ONCE during card done"
mkcard 'printf "x" >> counter.txt && [ "$(wc -c < counter.txt | tr -d " ")" = "1" ]'
out="$(bash "$RUN" card done C-001 2>&1)"; rc=$?
ck 0 "$rc" "card done exits 0 with once-only execution"
has "$out" "PASS: C-001 is valid" "done-gate passes"
cnt="$(wc -c < "$SB/counter.txt" 2>/dev/null | tr -d " ")"
ck 1 "$cnt" "verify-command executed exactly once (not twice)"
rm -rf "$SB"

echo "I) harness prune resets verify_receipt table rows for pruned sink"
if [ -n "$PY" ] && "$PY" --version >/dev/null 2>&1; then
  mkcard 'printf prune-test'
  bash "$RUN" card done C-001 >/dev/null 2>&1
  tmpf="$(mktemp)"; cp "$SB/.flow/events.jsonl" "$tmpf"; cat "$tmpf" >> "$SB/.flow/events.jsonl"; rm -f "$tmpf"
  FLOW_PROJECT_ROOT="$SB" "$PY" "$HARNESS_PY" init >/dev/null 2>&1
  FLOW_PROJECT_ROOT="$SB" "$PY" "$HARNESS_PY" rollup >/dev/null 2>&1
  q1="$("$PY" -c '
import os, sqlite3
db = os.path.join(os.environ["FLOW_PROJECT_ROOT"], ".flow", "harness.db")
con = sqlite3.connect(db)
print(len(con.execute("SELECT line_no FROM verify_receipt").fetchall()))
' 2>/dev/null)"
  ck 2 "$q1" "verify_receipt has 2 rows before prune"
  FLOW_PROJECT_ROOT="$SB" "$PY" "$HARNESS_PY" prune --keep 2 >/dev/null 2>&1
  q2="$("$PY" -c '
import os, sqlite3
db = os.path.join(os.environ["FLOW_PROJECT_ROOT"], ".flow", "harness.db")
con = sqlite3.connect(db)
print(len(con.execute("SELECT line_no FROM verify_receipt").fetchall()))
' 2>/dev/null)"
  ck 0 "$q2" "verify_receipt reset to 0 rows after prune"
  FLOW_PROJECT_ROOT="$SB" "$PY" "$HARNESS_PY" rollup >/dev/null 2>&1
  q3="$("$PY" -c '
import os, sqlite3
db = os.path.join(os.environ["FLOW_PROJECT_ROOT"], ".flow", "harness.db")
con = sqlite3.connect(db)
print(len(con.execute("SELECT line_no FROM verify_receipt").fetchall()))
' 2>/dev/null)"
  ck 1 "$q3" "verify_receipt re-populated cleanly after re-rollup"
  rm -rf "$SB"
fi


echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

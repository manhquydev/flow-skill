#!/usr/bin/env bash
# Regression test for EN/VI beginner card-completion onboarding path.
# Verifies template + EN/VI docs + concierge lead a newcomer from a fresh C-001
# to `PASS: C-001 is valid (status: done)` using real FlowSkill without lowering gates.
# Run: bash tests/test_flow_card_onboarding.sh
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RUN="$ROOT/skills/flow/runner/flow.sh"

pass=0; fail=0
ck() {
  local exp="$1" got="$2" msg="$3"
  if [ "$exp" = "$got" ]; then
    echo "  ok   [$msg]"; pass=$((pass + 1))
  else
    echo "  FAIL [$msg] expected='$exp' got='$got'"; fail=$((fail + 1))
  fi
}
has_lit() {
  if grep -Fq -- "$2" "$1" 2>/dev/null; then
    echo "  ok   [$3]"; pass=$((pass + 1))
  else
    echo "  FAIL [$3] (missing literal: $2)"; fail=$((fail + 1))
  fi
}
no_lit() {
  if grep -Fq -- "$2" "$1" 2>/dev/null; then
    echo "  FAIL [$3] (unexpected literal: $2)"; fail=$((fail + 1))
  else
    echo "  ok   [$3]"; pass=$((pass + 1))
  fi
}

echo "A) Card template + EN/VI docs + concierge share runnable CLI proof & card-done distinction"
for f in \
  "$ROOT/skills/flow/_templates/card.md" \
  "$ROOT/skills/flow/references/concierge.md" \
  "$ROOT/README.md" \
  "$ROOT/README_VN.md" \
  "$ROOT/npm-wrapper/README.md" \
  "$ROOT/npm-wrapper/README_VN.md"
do
  rel="${f#"$ROOT"/}"
  has_lit "$f" "evidence/cli-smoke.log" "$rel references evidence/cli-smoke.log"
  has_lit "$f" "exit 0" "$rel includes exit 0 proof signal"
  has_lit "$f" "(empty until done)" "$rel names (empty until done) sentinel"
  if [ "$rel" != "skills/flow/_templates/card.md" ]; then
    has_lit "$f" "card done C-" "$rel names card done C-NNN path"
  fi
  no_lit  "$f" "dist/cli.js" "$rel drops broken dist/cli.js proof example"
  no_lit  "$f" "console.log('ready')" "$rel does not teach dummy console.log('ready') as proof"
done
has_lit "$ROOT/npm-wrapper/README.md" "check C-001" "npm-wrapper/README.md distinguishes check C-001"
has_lit "$ROOT/npm-wrapper/README_VN.md" "check C-001" "npm-wrapper/README_VN.md distinguishes check C-001"
has_lit "$ROOT/README.md" "check C-001" "README.md distinguishes check C-001"
has_lit "$ROOT/README_VN.md" "check C-001" "README_VN.md distinguishes check C-001"
sentinel_cnt="$(grep -o '(empty until done)' "$ROOT/skills/flow/_templates/card.md" | wc -l | tr -d '[:space:]')"
ck "1" "$sentinel_cnt" "card.md contains (empty until done) exactly once (never in HTML comment)"

echo "B) Isolated real-FlowSkill fixture: scaffold C-001 via flow.sh card"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
export HOME="$SB/home"
export FLOW_PROJECT_ROOT="$SB/proj"
mkdir -p "$HOME" "$SB/proj/flow" "$SB/proj/dist"
(
  cd "$SB/proj" || exit 1
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  printf '# 00 Idea\n- [x] Done\n' > flow/00-idea.md
  for s in 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '# %s\n- [x] Done\n' "$s" > "flow/$s.md"
  done
)

card_out="$(cd "$SB/proj" && bash "$RUN" card 2>&1)"
card_rc=$?
ck 0 "$card_rc" "flow.sh card creates C-001 from template (rc=0)"
printf '%s' "$card_out" | grep -q 'PASS: created C-001'
ck 0 $? "flow.sh card prints PASS: created C-001"

# Fill required card sections cleanly while keeping status: todo and (empty until done)
python3 - "$SB/proj/cards/C-001.md" <<'PY'
import sys
p = sys.argv[1]
txt = open(p, encoding="utf-8").read()
txt = txt.replace("# C-001 — [FILL: one-line scope, ONE thing]", "# C-001 — CLI smoke")
txt = txt.replace("[FILL: card ids this depends on, e.g. \"C-001, C-002\" — or \"none\"]", "none")
txt = txt.replace("[FILL: PRD feature ids this card delivers, e.g. \"FR1, FR2\" — or \"infra\"/\"none\" for non-feature cards]", "FR1")
txt = txt.replace("risk: unknown", "risk: standard")
txt = txt.replace("risk-reason:", "risk-reason: none")
txt = txt.replace("[FILL: exactly what this card builds. If it's two things, split it.]", "CLI smoke check")
txt = txt.replace("[FILL: one sentence — if only this card shipped, what can a user do? Or `infra` / `none` for scaffold/CI/contract-test/e2e plumbing. \"Unit tests pass\" is not an independent test.]", "User runs the CLI smoke check and sees ready.")
txt = txt.replace("[FILL: which files/dirs this card may touch — keeps the diff reviewable]", "evidence/cli-smoke.log")
txt = txt.replace("- [ ] [FILL: command + expected output OR URL/path + observable user fact. Not \"tests pass\"]", "- [ ] Run CLI smoke and log ready to evidence/cli-smoke.log")
txt = txt.replace("[FILL: what will be observable in the world when this is done — a URL you can click,\na a curl output, a deployed page. \"Tests pass\" / \"code merged\" are NOT done-evidence.]", "evidence/cli-smoke.log exists with ready output and exit 0")
# Fallback in case line 31 wording differs slightly
import re
txt = re.sub(r"\[FILL:[^\]]*\]", "evidence/cli-smoke.log exists with ready output and exit 0", txt)
open(p, "w", encoding="utf-8").write(txt)
PY

echo "C) Negative 1: keeping (empty until done) above proof still fails"
cp "$SB/proj/cards/C-001.md" "$SB/proj/cards/C-001.base.md"
python3 - "$SB/proj/cards/C-001.md" <<'PY'
import re, sys
p = sys.argv[1]
txt = open(p, encoding="utf-8").read()
txt = txt.replace("status: todo", "status: done", 1)
txt = txt.replace("- [ ] ", "- [x] ", 1)
txt = re.sub(r"(?m)^\(empty until done\)$", "(empty until done)\nevidence/cli-smoke.log\n$ cat evidence/cli-smoke.log\nready\nexit 0", txt, count=1)
open(p, "w", encoding="utf-8").write(txt)
PY
mkdir -p "$SB/proj/evidence"
printf 'ready\n' > "$SB/proj/evidence/cli-smoke.log"
neg1_rc=0; neg1_out="$(cd "$SB/proj" && bash "$RUN" check C-001 2>&1)" || neg1_rc=$?
ck 1 "$neg1_rc" "keeping (empty until done) causes check C-001 to FAIL"
printf '%s' "$neg1_out" | grep -q '## Evidence is empty'
ck 0 $? "keeping (empty until done) reports ## Evidence is empty"

echo "D) Negative 2: .js path + output + exit 0 scores 1/2 and fails"
cp "$SB/proj/cards/C-001.base.md" "$SB/proj/cards/C-001.md"
printf 'console.log("Homework tracker ready");\n' > "$SB/proj/dist/cli.js"
python3 - "$SB/proj/cards/C-001.md" <<'PY'
import re, sys
p = sys.argv[1]
txt = open(p, encoding="utf-8").read()
txt = txt.replace("status: todo", "status: done", 1)
txt = txt.replace("- [ ] ", "- [x] ", 1)
txt = re.sub(r"(?m)^\(empty until done\)$", "dist/cli.js\n$ node dist/cli.js\nHomework tracker ready\nexit 0", txt, count=1)
open(p, "w", encoding="utf-8").write(txt)
PY
neg2_rc=0; neg2_out="$(cd "$SB/proj" && bash "$RUN" check C-001 2>&1)" || neg2_rc=$?
ck 1 "$neg2_rc" "dist/cli.js + output + exit 0 causes check C-001 to FAIL"
printf '%s' "$neg2_out" | grep -q 'score 1/2'
ck 0 $? "dist/cli.js example reports score 1/2"

echo "E) Negative 3: check C-001 on status: todo stays todo (does not mark done)"
cp "$SB/proj/cards/C-001.base.md" "$SB/proj/cards/C-001.md"
neg3_rc=0; neg3_out="$(cd "$SB/proj" && bash "$RUN" check C-001 2>&1)" || neg3_rc=$?
ck 0 "$neg3_rc" "check C-001 on todo exits 0"
printf '%s' "$neg3_out" | grep -q 'PASS: C-001 is valid (status: todo).'
ck 0 $? "check C-001 on todo reports status: todo (not done)"

echo "F) Positive: documented CLI command + replace placeholder + card done C-001 -> PASS done + durable DB"
rm -rf "$SB/proj/evidence"
printf 'console.log("Homework tracker: 2 due");\n' > "$SB/proj/dist/cli.js"
cmd_out="$(cd "$SB/proj" && mkdir -p evidence && node dist/cli.js > evidence/cli-smoke.log && cat evidence/cli-smoke.log)"
ck "Homework tracker: 2 due" "$cmd_out" "fixture CLI command creates evidence/cli-smoke.log with feature output"
python3 - "$SB/proj/cards/C-001.md" "$cmd_out" <<'PY'
import re, sys
p, out = sys.argv[1], sys.argv[2]
txt = open(p, encoding="utf-8").read()
txt = txt.replace("- [ ] ", "- [x] ", 1)
txt, n = re.subn(r"(?m)^\(empty until done\)$", f"evidence/cli-smoke.log\n$ cat evidence/cli-smoke.log\n{out}\nexit 0", txt, count=1)
assert n == 1, f"expected 1 standalone placeholder line, replaced {n}"
open(p, "w", encoding="utf-8").write(txt)
PY
ev_comment_rc=0
python3 - "$SB/proj/cards/C-001.md" <<'PY' || ev_comment_rc=$?
import re, sys
txt = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"(?ms)^## Evidence\b.*?(?=^## |\Z)", txt)
assert m, "missing ## Evidence section"
assert "<!-- Replace the placeholder line below completely with >=2 real world-state proofs" in m.group(0), "Evidence HTML comment missing"
PY
ck 0 "$ev_comment_rc" "Evidence section HTML comment preserved after replacing standalone placeholder line"

pos1_rc=0; pos1_out="$(cd "$SB/proj" && bash "$RUN" card done C-001 2>&1)" || pos1_rc=$?
ck 0 "$pos1_rc" "card done C-001 exits 0 with documented proof"
printf '%s' "$pos1_out" | grep -q 'PASS: C-001 is valid (status: done).'
ck 0 $? "card done C-001 prints PASS: C-001 is valid (status: done)."
grep -q '^status: done' "$SB/proj/cards/C-001.md"
ck 0 $? "cards/C-001.md updated to status: done"

db_row="$(python3 - "$SB/proj/.flow/harness.db" <<'PY'
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
row = conn.execute("SELECT status FROM story WHERE id='C-001'").fetchone()
print(row[0] if row else "missing")
PY
)"
ck "implemented" "$db_row" "durable .flow/harness.db records C-001 status as implemented"

echo "G) Positive: check C-001 on completed card also passes with status: done"
pos2_rc=0; pos2_out="$(cd "$SB/proj" && bash "$RUN" check C-001 2>&1)" || pos2_rc=$?
ck 0 "$pos2_rc" "check C-001 on completed card exits 0"
printf '%s' "$pos2_out" | grep -q 'PASS: C-001 is valid (status: done).'
ck 0 $? "check C-001 on completed card prints PASS: C-001 is valid (status: done)."

if [ "${_FLOW_CARD_ONBOARDING_SELF_TEST:-0}" != 1 ]; then
  echo "H) Regression: exported external FLOW_PROJECT_ROOT cannot be written by this suite"
  EXT="$(mktemp -d)"
  mkdir -p "$EXT/flow" "$EXT/cards"
  printf '# 00 Idea\n- [x] Done\n' > "$EXT/flow/00-idea.md"
  for s in 01-research 02-scope 03-prd 04-adr 05-contract; do
    printf '# %s\n- [x] Done\n' "$s" > "$EXT/flow/$s.md"
  done
  ext_rc=0
  FLOW_PROJECT_ROOT="$EXT" _FLOW_CARD_ONBOARDING_SELF_TEST=1 bash "$0" >/dev/null 2>&1 || ext_rc=$?
  ck 0 "$ext_rc" "suite succeeds even when caller exports external FLOW_PROJECT_ROOT"
  ext_cards="$(find "$EXT/cards" -mindepth 1 -maxdepth 1 | wc -l | tr -d '[:space:]')"
  ck "0" "$ext_cards" "external FLOW_PROJECT_ROOT/cards remains untouched (0 files)"
  rm -rf "$EXT"
fi

rm -f "$SB/proj/cards/C-001.base.md"
echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

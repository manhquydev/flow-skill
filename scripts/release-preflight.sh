#!/usr/bin/env bash
# release-preflight.sh — harness-aware gate before shipping skill and/or npm-wrapper.
# Run from repo root: bash scripts/release-preflight.sh
# Exit 0 = safe to proceed with tag/publish steps in docs/release-process.md
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
rc=0
fail() { echo "FAIL: $*" >&2; rc=1; }
ok() { echo "OK: $*"; }
warn() { echo "WARN: $*"; }

echo "=== release-preflight ($(date -u +%Y-%m-%dT%H:%MZ)) ==="
echo "ROOT=$ROOT"

# Resolve node (Git Bash on Windows often lacks node on PATH; try common locations).
NODE=""
if command -v node >/dev/null 2>&1; then
  NODE="$(command -v node)"
elif [ -x "/c/Program Files/nodejs/node.exe" ]; then
  NODE="/c/Program Files/nodejs/node.exe"
elif [ -n "${PROGRAMFILES:-}" ] && [ -x "$PROGRAMFILES/nodejs/node.exe" ]; then
  NODE="$PROGRAMFILES/nodejs/node.exe"
fi
json_get() {
  # $1=relative path under ROOT  $2=dotted path e.g. version | metadata.version
  local rel="$1" dotted="$2"
  if [ -n "$NODE" ]; then
    (cd "$ROOT" && "$NODE" -e "
      const d=require('./$rel');
      const p='$dotted'.split('.');
      let x=d; for (const k of p) x=x&&x[k];
      if (x!=null) process.stdout.write(String(x));
    " 2>/dev/null) && return
  fi
  if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    local py
    py="$(command -v python3 || command -v python)"
    "$py" -c "
import json
d=json.load(open(r'$ROOT/$rel',encoding='utf-8'))
x=d
for k in '$dotted'.split('.'):
    x=x.get(k) if isinstance(x,dict) else None
print(x if x is not None else '', end='')
" 2>/dev/null
    return
  fi
  # last resort for top-level version only
  if [ "$dotted" = "version" ]; then
    sed -nE 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$ROOT/$rel" | head -1
  fi
}

FLOW_SH="$ROOT/skills/flow/runner/flow.sh"
if [ ! -f "$FLOW_SH" ]; then
  fail "missing $FLOW_SH"
  exit 2
fi

# --- 1) Skill product coherence (SKILL.md / plugin / portable-manifest) ---
echo
echo "--- coherence ---"
if bash "$FLOW_SH" coherence; then
  ok "flow coherence PASS"
else
  fail "flow coherence did not PASS"
fi

# --- 2) Version surface extract ---
echo
echo "--- versions ---"
skill_v="$(sed -nE 's/^[[:space:]]*version:[[:space:]]*"?([0-9][.0-9A-Za-z-]*)"?.*/\1/p' "$ROOT/skills/flow/SKILL.md" | head -1)"
plugin_v="$(json_get '.claude-plugin/plugin.json' 'version' | tr -d '\r\n')"
portable_v="$(json_get 'portable-manifest.json' 'version' | tr -d '\r\n')"
npm_v="$(json_get 'npm-wrapper/package.json' 'version' | tr -d '\r\n')"
echo "  skill product (SKILL.md):     ${skill_v:-?}"
echo "  plugin.json:                  ${plugin_v:-?}"
echo "  portable-manifest.json:       ${portable_v:-?}"
echo "  npm-wrapper package.json:     ${npm_v:-?}"
echo "  node for dual-version CLI:    ${NODE:-missing}"

if [ -n "$skill_v" ] && [ "$skill_v" = "$plugin_v" ] && [ "$skill_v" = "$portable_v" ]; then
  ok "skill product mirrors agree ($skill_v)"
else
  fail "skill product mirrors disagree"
fi
if [ -n "$npm_v" ] && [ -n "$skill_v" ] && [ "$npm_v" = "$skill_v" ]; then
  warn "npm package version equals skill product ($npm_v) — usually accidental; dual-axis is intentional"
fi

# marketplace metadata.version is NOT skill product (hosting catalog)
mp_v="$(json_get '.claude-plugin/marketplace.json' 'metadata.version' | tr -d '\r\n')"
echo "  marketplace metadata.version: ${mp_v:-?} (catalog — independent of skill product)"

# --- 3) Doctor (engine + harness present) ---
echo
echo "--- doctor ---"
if bash "$FLOW_SH" doctor 2>&1 | tee /tmp/flow-doctor.out | tail -5; then
  if grep -q "READY" /tmp/flow-doctor.out 2>/dev/null; then
    ok "doctor READY"
  else
    warn "doctor finished without READY line — inspect full output"
  fi
else
  fail "doctor failed"
fi

# --- 4) Durable layer presence (optional soft) ---
echo
echo "--- harness / memory ---"
if [ -f "$ROOT/.flow/harness.db" ]; then
  ok "project harness.db present ($(wc -c <"$ROOT/.flow/harness.db" | tr -d ' ') bytes)"
  if command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    py="$(command -v python3 || command -v python)"
    if "$py" "$ROOT/skills/flow/harness/flow_harness.py" query matrix 2>/dev/null | head -3; then
      ok "harness query matrix runnable"
    else
      warn "harness.db present but query matrix failed (ok if empty/corrupt mid-migrate)"
    fi
  fi
else
  warn "no .flow/harness.db in repo root — dogfood durable layer not initialized (optional)"
fi
if [ -f "$ROOT/.flow/events.jsonl" ]; then
  ok "project events.jsonl present ($(wc -l <"$ROOT/.flow/events.jsonl" | tr -d ' ') lines)"
else
  warn "no .flow/events.jsonl — no mechanical flight recorder yet"
fi

# --- 5) npm-wrapper dual-version string (after sync if tree present) ---
echo
echo "--- npm-wrapper ---"
if [ -f "$ROOT/npm-wrapper/package.json" ]; then
  if [ ! -f "$ROOT/npm-wrapper/skills/flow/SKILL.md" ]; then
    echo "  running npm run sync..."
    if command -v npm >/dev/null 2>&1; then
      (cd "$ROOT/npm-wrapper" && npm run sync >/dev/null 2>&1) || fail "npm run sync failed"
    else
      warn "npm not on PATH — cannot sync bundle"
    fi
  fi
  if [ -n "$NODE" ] && [ -f "$ROOT/npm-wrapper/bin/cli.mjs" ]; then
    help_out="$("$NODE" "$ROOT/npm-wrapper/bin/cli.mjs" --help 2>/dev/null | head -1 || true)"
    echo "  help: $help_out"
    if echo "$help_out" | grep -q "ships skill v"; then
      ok "dual-version help present"
    else
      fail "dual-version help missing (run npm run sync; need skill bundle)"
    fi
    if [ -n "$npm_v" ] && echo "$help_out" | grep -q "v${npm_v}"; then
      ok "help package version matches package.json"
    else
      warn "help line package version may not match package.json ($npm_v)"
    fi
  else
    # Offline / no node: assert sources that would produce dual-version
    if [ -f "$ROOT/npm-wrapper/skills/flow/SKILL.md" ] && [ -n "$npm_v" ] && [ -n "$skill_v" ]; then
      ok "bundle SKILL present; dual-version expected at runtime (node not available to exec CLI)"
    else
      warn "skip dual-version CLI exec (no node); ensure npm run sync before publish"
    fi
  fi
else
  fail "npm-wrapper missing"
fi

# --- 6) Live registry (network; soft fail offline) ---
echo
echo "--- registry (live) ---"
if command -v npm >/dev/null 2>&1; then
  tags="$(npm view @manhquy/flow-skill dist-tags --json 2>/dev/null || true)"
  if [ -n "$tags" ]; then
    echo "  dist-tags: $tags"
    reg_rc=""
    reg_latest=""
    if [ -n "$NODE" ]; then
      reg_rc="$("$NODE" -e "try{const t=JSON.parse(process.argv[1]);process.stdout.write(t.rc||'')}catch(e){}" "$tags" 2>/dev/null || true)"
      reg_latest="$("$NODE" -e "try{const t=JSON.parse(process.argv[1]);process.stdout.write(t.latest||'')}catch(e){}" "$tags" 2>/dev/null || true)"
    elif command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
      py="$(command -v python3 || command -v python)"
      reg_rc="$("$py" -c "import json,sys; t=json.loads(sys.argv[1]); print(t.get('rc') or '')" "$tags" 2>/dev/null || true)"
      reg_latest="$("$py" -c "import json,sys; t=json.loads(sys.argv[1]); print(t.get('latest') or '')" "$tags" 2>/dev/null || true)"
    fi
    reg_rc="$(printf '%s' "$reg_rc" | tr -d '\r\n')"
    reg_latest="$(printf '%s' "$reg_latest" | tr -d '\r\n')"
    echo "  package.json npm_v=$npm_v  registry rc=$reg_rc  latest=$reg_latest"
    if [ -n "$npm_v" ] && [ -n "$reg_rc" ] && [ "$npm_v" = "$reg_rc" ]; then
      ok "local package.json matches dist-tag rc"
    elif [ -n "$npm_v" ] && [ -n "$reg_rc" ] && [ "$npm_v" != "$reg_rc" ]; then
      warn "local package.json ($npm_v) != registry rc ($reg_rc) — expected mid-release before tag push"
    fi
    if [ -n "$reg_rc" ] && [ -n "$reg_latest" ] && [ "$reg_rc" != "$reg_latest" ]; then
      warn "rc ($reg_rc) != latest ($reg_latest) — intentional for RC; promote latest manually if desired"
    fi
  else
    warn "npm view failed (offline or network)"
  fi
else
  warn "npm not on PATH"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "PREFLIGHT PASS — next: docs/release-process.md (tag npm@… / skill tag v…)"
else
  echo "PREFLIGHT FAIL — fix FAIL lines before shipping"
fi
exit "$rc"

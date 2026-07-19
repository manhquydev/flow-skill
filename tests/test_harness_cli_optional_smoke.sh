#!/usr/bin/env bash
# Optional harness-cli-v0.1.17 smoke (plan phase 5). Default skip unless HARNESS_CLI_SMOKE=1.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
HDIR="$HERE/../skills/flow/harness"
H="$HDIR/flow_harness.py"
PIN="$HDIR/pins/harness-cli-v0.1.17.sha256sums"
PY="$(command -v python || command -v python3)"
pass=0; fail=0
ck() { if [ "$1" = "$2" ]; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3] expected=$1 got=$2"; fail=$((fail+1)); fi; }
has() { if printf '%s' "$1" | grep -qE "$2"; then echo "  ok   [$3]"; pass=$((pass+1)); else echo "  FAIL [$3]"; fail=$((fail+1)); fi; }

echo "A) always-on: rust refuse without network"
if [ -z "$PY" ]; then echo "SKIP python"; exit 0; fi
SB="$(mktemp -d)"
FLOW_PROJECT_ROOT="$SB" "$PY" "$H" init >/dev/null
FAKE="$SB/fake-cli"; printf '#!/bin/sh\nexit 0\n' > "$FAKE"; chmod +x "$FAKE" 2>/dev/null || true
rc=0
out="$(FLOW_PROJECT_ROOT="$SB" FLOW_HARNESS_BACKEND=rust FLOW_HARNESS_CLI="$FAKE" "$PY" "$H" query matrix 2>&1)" || rc=$?
ck 2 "$rc" "rust refuse exit 2"
rm -rf "$SB"; unset rc

echo "B) pin file present (sha256 sums for release assets)"
test -f "$PIN" && ck 0 0 "sha256sums pin file exists" || ck 0 1 "sha256sums pin file exists"
if [ -f "$PIN" ]; then
  has "$(cat "$PIN")" "harness-cli" "pin lists harness-cli assets"
fi

echo "C) optional download smoke"
if [ "${HARNESS_CLI_SMOKE:-0}" != "1" ]; then
  echo "  ok   [skip optional smoke — set HARNESS_CLI_SMOKE=1 to run]"
  pass=$((pass+1))
else
  # Network path: download windows-x64 or linux-x64 by uname
  TAG="harness-cli-v0.1.17"
  BASE="https://github.com/hoangnb24/repository-harness/releases/download/${TAG}"
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT) asset="harness-cli-windows-x64.exe" ;;
    Darwin) asset="harness-cli-macos-x64" ;; # may need arm64 on M1; smoke is best-effort
    *) asset="harness-cli-linux-x64" ;;
  esac
  TD="$(mktemp -d)"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$BASE/$asset" -o "$TD/cli" && curl -fsSL "$BASE/${asset}.sha256" -o "$TD/cli.sha256" || true
  fi
  if [ ! -f "$TD/cli" ]; then
    echo "  FAIL [download $asset]"; fail=$((fail+1))
  else
    # verify sha if openssl/sha256sum available
    exp="$(awk '{print $1}' "$TD/cli.sha256" 2>/dev/null | head -1)"
    if [ -n "$exp" ] && command -v sha256sum >/dev/null 2>&1; then
      got="$(sha256sum "$TD/cli" | awk '{print $1}')"
      ck "$exp" "$got" "sha256 matches release"
    else
      echo "  ok   [sha256 tool missing — file downloaded only]"; pass=$((pass+1))
    fi
    chmod +x "$TD/cli" 2>/dev/null || true
    # contract query needs a db path — init may create
    export HARNESS_DB_PATH="$TD/h.db"
    if "$TD/cli" query contract --json >"$TD/out.json" 2>"$TD/err"; then
      has "$(cat "$TD/out.json")" "protocol_version" "contract json has protocol_version"
    else
      # some builds need init first
      "$TD/cli" init >/dev/null 2>&1 || true
      if "$TD/cli" query contract --json >"$TD/out.json" 2>"$TD/err"; then
        has "$(cat "$TD/out.json")" "protocol_version" "contract after init"
      else
        echo "  FAIL [query contract]"; fail=$((fail+1)); cat "$TD/err" | head -5
      fi
    fi
  fi
  rm -rf "$TD"
fi

echo
echo "RESULT: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

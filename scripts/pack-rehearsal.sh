#!/usr/bin/env bash
# pack-rehearsal.sh — credentialless pack → tarball parity → install → e2e.
# Local and CI share this file. From repo root (or anywhere):
#   bash scripts/pack-rehearsal.sh
# Requires Node >=22.14 (same floor as npm-wrapper engines). Ubuntu is the CI lane.
# There is no $INSTALLED variable. Zero-arg e2e invoke is a job bug.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAP="$ROOT/npm-wrapper"
WORKDIR=""
PREFIX=""
DEST=""
PACKED=""
NL="\n"

cleanup() {
  [ -n "$WORKDIR" ] && rm -rf "$WORKDIR"
  [ -n "$PREFIX" ] && rm -rf "$PREFIX"
  [ -n "$DEST" ] && rm -rf "$DEST"
  [ -n "$PACKED" ] && rm -f "$PACKED"
}
trap cleanup EXIT

if [ -n "${GITHUB_ACTIONS:-}" ] && [ -n "${NPM_TOKEN:-}" ]; then
  echo "FAIL: NPM_TOKEN is set; pack-rehearsal is credentialless" >&2
  exit 1
fi

node -e 'const [M,m]=process.versions.node.split(".").map(Number);if(M<22||(M===22&&m<14)){console.error("FAIL: need Node >=22.14, got "+process.versions.node);process.exit(1)}'
to_physical() {
  (cd "$1" && pwd -P)
}

WORKDIR="$(to_physical "$(mktemp -d)")"
PREFIX="$(to_physical "$(mktemp -d)")"
DEST="$(to_physical "$(mktemp -d)")"
export HOME="$WORKDIR/home"
mkdir -p "$HOME"
echo "=== pack-rehearsal ==="
echo "ROOT=$ROOT"
echo "DEST=$DEST"

# Pack from npm-wrapper so prepack runs sync.mjs; tarball lands there.
cd "$WRAP"
# Redirect stdout only — notices stay on stderr. Avoid `npm pack | tail` so a
# failed pack cannot hide behind tail's exit 0 (set -e without pipefail).
npm pack > "$WORKDIR/pack.out"
PACKED_NAME="$(tail -1 "$WORKDIR/pack.out")"
PACKED="$WRAP/$PACKED_NAME"
case "$PACKED_NAME" in
  manhquy-flow-skill-*.tgz) ;;
  *) echo "FAIL: npm pack did not print manhquy-flow-skill-*.tgz (got: $PACKED_NAME)" >&2; exit 1 ;;
esac
[ -f "$PACKED" ] || { echo "FAIL: tarball missing: $PACKED" >&2; exit 1; }
echo "packed $PACKED_NAME"

mkdir -p "$WORKDIR/extract"
tar -xzf "$PACKED" -C "$WORKDIR/extract"
EXTRACTED="$WORKDIR/extract/package/skills/flow"
[ -d "$EXTRACTED" ] || { echo "FAIL: tarball missing package/skills/flow" >&2; exit 1; }

# Shared JS predicate — argv branch before copy. Not an unfiltered diff -r.
node "$WRAP/scripts/sync.mjs" --compare "$EXTRACTED" "$ROOT/skills/flow"

# C5 — pack verification: the packaged runner's sha256 must equal the pack-time hash that
# sync.mjs (prepack) recorded in portable-manifest.json. Mismatch = tampered/drifted bytes.
EXPECT="$(sed -nE 's/.*"skills\/flow\/runner\/flow\.sh"[[:space:]]*:[[:space:]]*"([0-9a-f]{64})".*/\1/p' "$ROOT/portable-manifest.json" | head -1)"
if [ -n "$EXPECT" ]; then
  if command -v shasum >/dev/null 2>&1; then
    GOT="$(shasum -a 256 "$EXTRACTED/runner/flow.sh" | awk '{print $1}')"
  else
    GOT="$(sha256sum "$EXTRACTED/runner/flow.sh" | awk '{print $1}')"
  fi
  if [ "$GOT" = "$EXPECT" ]; then
    echo "runner hash verified: ${EXPECT%"${EXPECT#????????}"}..."
  else
    echo "FAIL: packaged runner sha256 mismatch (manifest ${EXPECT%"${EXPECT#????????}"}... vs packaged ${GOT%"${GOT#????????}"}...)" >&2
    exit 1
  fi
else
  echo "FAIL: no hashes entry in portable-manifest.json (run node npm-wrapper/scripts/sync.mjs)" >&2
  exit 1
fi

# C5 receipt — the tarball must carry the skill-adjacent receipt (doctor's preferred source on
# real installs, where repo-root portable-manifest.json does not ship), and its hash must equal
# the sha256 of the extracted runner.
RECEIPT="$EXTRACTED/manifest-hashes.json"
[ -f "$RECEIPT" ] || { echo "FAIL: tarball missing skills/flow/manifest-hashes.json (receipt not shipped)" >&2; exit 1; }
RECEIPT_HASH="$(sed -nE 's/.*"runner\/flow\.sh"[[:space:]]*:[[:space:]]*"([0-9a-f]{64})".*/\1/p' "$RECEIPT" | head -1)"
[ -n "$RECEIPT_HASH" ] && [ "$RECEIPT_HASH" = "$GOT" ] || {
  echo "FAIL: manifest-hashes.json receipt hash mismatch (receipt ${RECEIPT_HASH:-missing} vs packaged ${GOT%"${GOT#????????}"})" >&2
  exit 1
}
echo "receipt hash verified: ${RECEIPT_HASH%"${RECEIPT_HASH#????????}"}..."

# Local tarball only. --ignore-scripts: do not re-run prepack on the installed copy.
npm i --no-audit --no-fund --ignore-scripts --prefix "$PREFIX" "$PACKED"
BIN="$PREFIX/node_modules/.bin/flow-skill"
[ -f "$BIN" ] || { echo "FAIL: installer bin missing at $BIN" >&2; exit 1; }

# Dry-run JSONL, then the real project-scope install (writes $DEST/.claude/skills/flow only).
"$BIN" --yes --project --dir "$DEST" --dry-run --json
"$BIN" --yes --project --dir "$DEST"

# Pin one path, azure-shaped. No $INSTALLED. Do not use repo install.sh.
RUN="$DEST/.claude/skills/flow/runner/flow.sh"
[ -f "$RUN" ] || { echo "FAIL: installed runner not found at $RUN" >&2; exit 1; }

DEST_ABS="$(cd "$DEST" && pwd -P)"
RUN_DIR="$(cd "$(dirname "$RUN")" && pwd -P)"
case "$RUN_DIR" in
  "$DEST_ABS"/*) ;;
  *) echo "FAIL: driven runner $RUN_DIR is not under DEST $DEST_ABS" >&2; exit 1 ;;
esac
CHECKOUT_DIR="$(cd "$ROOT/skills/flow/runner" && pwd -P)"
if [ "$RUN_DIR" = "$CHECKOUT_DIR" ]; then
  echo "FAIL: driven runner is the checkout $CHECKOUT_DIR" >&2
  exit 1
fi

# Zero-arg invoke is a job bug — always pass the installed runner as $1.
bash "$ROOT/tests/e2e-installed-drive.sh" "$RUN"

# C5 installed-artifact check — doctor must verify the live runner via the shipped receipt:
# clean install => ok; tampered bytes => loud FAIL + nonzero; restored bytes => ok again.
INSTALLED_RECEIPT="$DEST/.claude/skills/flow/manifest-hashes.json"
[ -f "$INSTALLED_RECEIPT" ] || { echo "FAIL: install missing manifest-hashes.json receipt at $INSTALLED_RECEIPT" >&2; exit 1; }
OUT="$(bash "$RUN" doctor 2>&1)" || { echo "FAIL: doctor failed on clean install:$NL$OUT" >&2; exit 1; }
printf '%s\n' "$OUT" | grep -q "bundled tree integrity: ok" || { echo "FAIL: doctor did not print 'bundled tree integrity: ok' on clean install:$NL$OUT" >&2; exit 1; }
echo "doctor on installed artifact: bundled tree integrity: ok"

cp "$RUN" "$RUN.bak"
printf '\n' >> "$RUN"
rc=0; OUT="$(bash "$RUN" doctor 2>&1)" || rc=$?
if [ "$rc" -eq 0 ]; then echo "FAIL: doctor exited 0 on tampered installed runner" >&2; exit 1; fi
if ! printf '%s\n' "$OUT" | grep -q "FAIL: bundled tree integrity"; then
  echo "FAIL: doctor did not flag tampered installed runner:$NL$OUT" >&2
  exit 1
fi
echo "doctor on installed artifact: tamper detected -> FAIL + nonzero (rc=$rc)"
mv "$RUN.bak" "$RUN" || exit 1
OUT="$(bash "$RUN" doctor 2>&1)" || { echo "FAIL: doctor failed after restore:$NL$OUT" >&2; exit 1; }
printf '%s\n' "$OUT" | grep -q "bundled tree integrity: ok" || { echo "FAIL: doctor not ok after restore:$NL$OUT" >&2; exit 1; }
echo "doctor on installed artifact: restored -> bundled tree integrity: ok"

echo "pack-rehearsal OK (runner=$RUN)"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node --test "$ROOT/tests/test_release_run_artifact.mjs"

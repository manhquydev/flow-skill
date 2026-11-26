# Deferred Core-Runner UX & Bug-Fix Proposals (`flow.sh` & `flow.cmd`)

## Why These Proposals Are Deferred

Per repository workflow discipline, core-runner changes to `skills/flow/runner/flow.sh` and `skills/flow/runner/flow.cmd` are **intentionally separated** from the Wave 2 non-coder documentation, concierge, template, and installer UX PR (`feat/noncoder-ux-guidance`) to avoid guaranteed merge conflicts with active runner/installer PRs on `master`:

- **PR #112** (`feat/verify-hash-receipt`): touches `skills/flow/runner/flow.sh` (`cmd_card_start`, `cmd_card_done`, `cmd_check`) and `portable-manifest.json`.
- **PR #115** (`feat/flow-cost-v1`): touches `skills/flow/runner/flow.sh` (`cmd_next`), `skills/flow/runner/attestations.sh`, `npm-wrapper/scripts/sync.mjs`, and `portable-manifest.json`.
- **PR #118** (`feat/resume-receipt-verify`): touches `skills/flow/runner/flow.sh` (`cmd_resume`) and `portable-manifest.json`.
- **PR #119** (`feat/card-handoff-envelope`): touches `skills/flow/runner/flow.sh` (`_redact_secrets` .. `cmd_resume`) and `portable-manifest.json`.
- **PR #122** (`chore/installer-py-floor`): touches installer runtime-floor guards (`install.sh`, `install.ps1`, `skills/flow/runner/installer_helper.py`).

Even a 1-line edit anywhere in `skills/flow/runner/flow.sh` mutates its SHA-256 entry in `portable-manifest.json` and shifts line offsets scraped by `npm-wrapper/scripts/sync.mjs` into `npm-wrapper/.widelai/rules/flowskill.md`. Once the PRs above land on `master`, implement the 7 proposals below in focused, test-backed slices.

All code locations below are anchored **by function and content** (never brittle line numbers, per `AGENTS.md`). **None of these proposals soften any gate or alter exit codes (`0` vs `1`).**

---

## Proposal 1 (P0 · `flow.sh`): Quiet Inactive-`auto` Receipt/Trace Warnings on Manual `PASS` & Scope `PIN v1`

### Root Cause (Locate by Content)
- In `cmd_check()` (`skills/flow/runner/flow.sh`, search `_att_enforce_card "$id" "$need_live" "$enforce"` and `harness_emit trace --summary "card $id reached done-evidence"`):
  - Even when `auto` is `INACTIVE` (`enforce=0`), `_att_enforce_card` prints two `WARNING: card C-NNN ... receipt missing/stale/red (auto inactive — manual path still usable)` lines plus `note: risk=unknown — classify before /flow auto`, and `harness_emit trace` prints `harness: PASS: trace #1 recorded. tier 1/3, required 2 for lane 'normal' <-- BELOW required` **above** `PASS: C-NNN is valid (status: done).`
  - Non-programmers read 5 warning/error-shaped lines above `PASS:` and conclude `card done` failed even when exit code is `0`.
- In `_emit_next()` / `_emit_pin()` (`skills/flow/runner/flow.sh`, search `PIN v1` / `pin-v1.txt`):
  - Every `flow status` and `flow resume` dumps the 5-line `PIN v1` host-safety block (`Never FLOW_FORCE a live session... NEXT_VERB is advisory...`) directly into human stdout without marking it as AI-host metadata.

### Current vs Proposed Output
- **Current (`flow card done C-001`, exit `0`, `auto: INACTIVE`):**
  ```text
  WARNING: card C-001 semantic receipt missing/stale/red (auto inactive — manual path still usable)
  WARNING: card C-001 live_verify receipt missing/stale/red (auto inactive — manual path still usable)
    note: risk=unknown — classify before /flow auto
    harness: PASS: trace #1 recorded. tier 1/3, required 2 for lane 'normal'  <-- BELOW required
    harness:   to reach next tier, add: intake_id, files_read
  PASS: C-001 is valid (status: done).
  ```
- **Proposed (`flow card done C-001`, exit `0`, `auto: INACTIVE`):**
  ```text
  PASS: C-001 is valid (status: done).
    info: manual mode — receipts & risk classification are only required before '/flow auto'.
  ```
  *(Keep full `WARNING:` / `FAIL:` receipt output when `auto` is `ACTIVE`/stale/invalid or when `--verbose` / `attest status` is invoked.)*

### Test Contracts to Preserve
- `tests/test_flow_attestations.sh` and `tests/test_flow_auto_done_path.sh`: check exact substrings asserted when `auto` is inactive vs enforcing (`auto inactive` warning expectations must be updated in lockstep if condensed).
- `tests/test_flow_status_legibility.sh` and `tests/test_flow_resume.sh`: assert `NEXT_VERB=<enum>` + verbatim `references/pin-v1.txt` (`PIN v1`) presence and `--budget` `<= 35` line ceiling — do not alter `PIN v1` lines without updating `pin-v1.txt` and legibility tests together.
- `npm-wrapper/scripts/sync.mjs`: scrapes `# v0.28: warning-only stage semantic receipt guidance` in `cmd_next()`.

---

## Proposal 2 (P0 · `flow.cmd` & `flow.sh`): WinGet `Git.MinGit` Discovery in `flow.cmd` & Missing-Python Cascade Guard in `cmd_doctor`

### Root Cause (Locate by Content)
1. **`skills/flow/runner/flow.cmd`** (search `set "GB=%ProgramFiles%\Git\bin\bash.exe"`):
   - Checks only 3 hardcoded `Git\bin\bash.exe` paths (`%ProgramFiles%`, `%ProgramFiles(x86)%`, `%LOCALAPPDATA%\Programs`). Machines with WinGet `Git.MinGit` (`Git.MinGit_Microsoft.Winget.Source_*`, which ships GNU bash as `<git-root>\usr\bin\sh.exe` without `bin\bash.exe`) fail with `flow: Git Bash not found` even when `git` is on `PATH`.
2. **`skills/flow/runner/flow.sh` `cmd_doctor()`** (search `# 3. python`, `# 4. sqlite3`, `# 9. harness`, `bounded_json`, `privacy_guard`, `scout_bounds`):
   - When working Python `>= 3.7` is absent (or resolves to the 0-byte Windows Store `WindowsApps\python.exe` stub), `python` rightly reports `fail`, **and** 5 downstream checks cascade: `sqlite3` tells Windows users `remedy: install sqlite3 via your package manager` (misleading — `sqlite3` ships inside official Python on Windows), `harness` suggests `reinstall`, and `bounded_json`, `privacy_guard`, and `scout_bounds` all print scary `FAIL:` lines (`FAIL: privacy guard` alarms non-coders into fearing a privacy breach).

### Current vs Proposed Output
- **Current (`flow.cmd` with WinGet MinGit, exit `1`):**
  ```text
  flow: Git Bash not found - install Git for Windows (https://git-scm.com) so the gate engine can run.
  ```
- **Proposed (`flow.cmd` fallback):** If the 3 standard `Git\bin\bash.exe` locations miss, resolve `for /f "delims=" %%G in ('where git 2^>nul')` and probe `..\bin\bash.exe`, `..\usr\bin\bash.exe`, and `..\usr\bin\sh.exe` relative to `cmd\git.exe` (never `System32\bash.exe` WSL).
- **Current (`flow doctor` without Python, exit `1`):** 1 root failure + 5 downstream `FAIL`/misleading-remedy lines.
- **Proposed (`flow doctor` without Python, exit `1`):** Keep overall `doctor` exit `1` because `python` failed, but record Python-dependent checks (`sqlite3`, `harness` when `$HARNESS_PY` exists on disk, `bounded_json`, `privacy_guard`, `scout_bounds`) as `skip (requires working Python >=3.7 — resolve 'python' above first)`, and tailor `doctor_remedy_for "sqlite3"` on `MSYS*|MINGW*|CYGWIN*` to state that `sqlite3` is included with the official Python installer from `python.org`.

### Test Contracts to Preserve
- `tests/test_flow_doctor.sh`: validates closed `doctor.report` / `doctor.list` JSON schemas, check names in `skills/flow/runner/doctor-checks.tsv`, and `doctor_remedy_for()` output strings.
- `tests/test_flow_v1_runtime_required.sh`: pins `product operations REFUSED` and `docs/migration-v1.md` references when Python `< 3.7` or missing.

---

## Proposal 3 (P0 · `flow.sh`): Prioritize `unfilled [FILL] placeholders` Before `unchecked gate boxes` in `scan_gate` / `_next_action`

### Root Cause (Locate by Content)
- In `scan_gate()` (`skills/flow/runner/flow.sh`, search `unchecked="$(grep -nE '^[[:space:]]*- \[ \]' "$file"`):
  - `unchecked gate boxes:` is emitted **before** `unfilled [FILL] placeholders:`.
- In `_next_action()` (`skills/flow/runner/flow.sh`, search `reason="$(printf '%s\n' "$gate_out" | grep -m1 '\[x\]'`):
  - Takes the **first** `[x]` line from `scan_gate()`, so on a fresh `flow/00-idea.md` both `status` and `resume` print:
    `NEXT -> fix gate: unchecked gate boxes in flow/00-idea.md`
    telling beginners to tick checkboxes at lines 4–6 **before** filling `[FILL: ...]` placeholders at lines 10–16.

### Current vs Proposed Output
- **Current (`flow status` on fresh `00-idea.md`):**
  ```text
  NEXT -> fix gate: unchecked gate boxes in flow/00-idea.md
  ```
- **Proposed (`flow status` on fresh `00-idea.md`):**
  ```text
  NEXT -> fix gate: unfilled [FILL] placeholders in flow/00-idea.md
  ```
  Plus a 1-line syntax hint under `scan_gate` output on `FAIL`:
  `(tip: replace each entire '[FILL: ...]' bracket block, then change '- [ ]' to '- [x]')`.

### Test Contracts to Preserve
- `tests/test_flow_runner.sh`, `tests/test_flow_status_legibility.sh`, `tests/test_flow_resume.sh`:
  - `status` and `resume` `NEXT ->` lines MUST remain byte-for-byte identical (`_next_action` is shared).
  - Exact violation headers `unchecked gate boxes:`, `unfilled [FILL] placeholders:`, and `L<line>:` line-number prefixes must remain intact.

---

## Proposal 4 (P1 · `flow.sh`): Self-Explanatory Fix Hints on Midtier Scanners & `cmd_next` Gate `FAIL` Footer

### Root Cause (Locate by Content)
- In `_scan_midtier()` / `_midtier_adjectives()` (`skills/flow/runner/flow.sh`, search `unquantified adjective '$adj'` and `L-impact feature above grade A`):
  - Reports the violation accurately, but omits a 1-line example showing non-coders how to fix it.
- In `cmd_next()` (`skills/flow/runner/flow.sh`, search `FAIL: gate for stage $s is not clean; an earlier stage is still BLOCKED if later files exist.` and `(Kill at a gate is also valid.)`):
  - Prints `; an earlier stage is still BLOCKED if later files exist.` unconditionally even when `$s` is the only stage file on disk (`00-idea`).
  - `(Kill at a gate is also valid.)` alarms non-programmers who read `"Kill"` as `"delete my project / kill a process"`.

### Current vs Proposed Output
- **Current:**
  ```text
  FAIL: gate for stage 03-prd is not clean; an earlier stage is still BLOCKED if later files exist.
    [x] unquantified adjective 'fast' in ## Features
  Fix the above, then run '/flow next' again. (Kill at a gate is also valid.)
  ```
- **Proposed:**
  ```text
  FAIL: gate for stage 03-prd is not clean.
    [x] unquantified adjective 'fast' in ## Features (replace 'fast' with a measurable number like '< 2s', or remove it)
  Fix the above, then run '/flow next' again. (Kill at a gate — stopping an unviable idea early — is also valid.)
  ```
  *(Append `; an earlier stage is still BLOCKED.` only when a stage file later than `$s` exists in `$FLOW_DIR`.)*

### Test Contracts to Preserve
- `tests/test_flow_midtier_scanners.sh` and `tests/test_flow_open_decisions.sh`: preserve exact substrings `unquantified adjective '$adj' in ## Features`, `unquantified adjective '$adj' in ## Non-functional requirements`, `L-impact feature above grade A in ## Features in v1`, and `more than 5 ## Open decisions bullets ($n)`.

---

## Proposal 5 (P1 · `flow.sh`): Validate Unknown Verbs Before `_log_on_exit`, Handle `new`/`init` Gracefully & Hint `assess` on Existing Code

### Root Cause (Locate by Content)
1. **Rogue `.flow/` creation on typos (`skills/flow/runner/flow.sh`, search `trap '_log_on_exit' EXIT` and `FLOW_ROOT_NEW=1`):**
   - Root resolution prints `note: no Flow project found here or in ancestors - starting a new Flow project at ...` to stderr even on read-only `help`, `doctor`, or unknown commands.
   - `trap '_log_on_exit' EXIT` is armed for `*` **before** `case "$cmd" in` validates whether `$cmd` is a real command. Typing `flow new`, `flow init`, or any typo in a random folder writes `.flow/events.jsonl` on disk (permanently marking that directory as a Flow root for ancestor walks!) and prints a 60-line `usage` dump.
2. **Silent brownfield detection in `cmd_status()` (`skills/flow/runner/flow.sh`, search `planning: not started`):**
   - When `idx < 0` and `flow/00-inspect.md` is absent, `cmd_status` says `run '/flow next' to unlock stage 00` even when `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, or `src/` is right in `$ROOT`, never mentioning `/flow assess`.

### Current vs Proposed Output
- **Current (`flow new`, exit `1`):** Writes `.flow/events.jsonl`, prints `starting a new Flow project` on stderr, and dumps 60 lines of `usage`.
- **Proposed (`flow new` / `flow init`, exit `1`, zero `.flow/` writes):**
  ```text
  unknown command: new
  hint: Flow has no 'new' or 'init' verb — run '/flow next' to start Stage 00 (or '/flow assess' for existing code, 'flow help' for all commands).
  ```
- **Proposed (`flow status` when `idx < 0`, no `00-inspect.md`, and code manifest detected):**
  Add 1 advisory line under `planning: not started`:
  `  tip: existing code detected here — run '/flow assess' first if this is an existing project.`

### Test Contracts to Preserve
- `tests/test_flow_usage_log.sh`: verify which commands are expected to emit `.flow/events.jsonl` rows.
- `tests/test_flow_monorepo_root.sh`: verify ancestor adoption and `note: no Flow project found` expectations on valid commands.
- `tests/test_flow_skill_harness_docs_contract.sh`: extracts dispatch arms matching `^[[:space:]]*[a-z_"|-]+\)[[:space:]]+cmd_` — keep any `new|init` error arm **not** calling `cmd_*` (or keep it with `*)`) so `command-dispatch.md` verb-count parity stays untouched!
- `tests/test_flow_status_legibility.sh`: keep `NEXT ->` singular and first, and respect `--budget` line limits.

---

## Proposal 6 (P2 · `flow.sh`): Fix Blank `mode:     (default teach)` Display & Telemetry Bug When `MODE` File Is Absent

### Root Cause (Locate by Content)
- Search `cat "$MODE_FILE" 2>/dev/null | tr -d '\r' || echo teach` in `skills/flow/runner/flow.sh` (occurs in `cmd_status()`, `cmd_mode()`, and `_log_event()`):
  - Because POSIX pipelines without `pipefail` return the exit status of the **last** command (`tr`, which exits `0` on empty stdin), `|| echo teach` **never executes** when `$MODE_FILE` is missing!
  - Consequently, `flow status` prints `mode:     (default teach)` (blank value), `flow mode` prints `mode:  (default teach)`, and `.flow/events.jsonl` records `"mode":""` instead of `"mode":"teach"`.

### Current vs Proposed Output
- **Current (`MODE` absent):** `  mode:     (default teach)` and `"mode":""`
- **Proposed (`get_mode()` helper mirroring `get_project_type()`):**
  ```bash
  get_mode() {
    local m=""
    [ -f "$MODE_FILE" ] && m="$(tr -d '\r\n' < "$MODE_FILE" | awk 'NF{print; exit}')"
    printf '%s' "${m:-teach}"
  }
  ```
  Output: `  mode:    teach (default teach)` and `"mode":"teach"`.

### Test Contracts to Preserve
- `tests/test_flow_status_legibility.sh` and `tests/test_flow_usage_log.sh`: check any regex matching `mode:` or JSON `"mode"` field.

---

## Proposal 7 (P2 · `flow.sh`): Implicit-`web` Stage-01 Competitor Floor, Root Law-File Seeding Note & Cross-Platform Lock Recovery Hint

### Root Cause (Locate by Content)
1. **`_scan_midtier()` `01-research.md` (`skills/flow/runner/flow.sh`, search `if [ -f "$PROJECT_TYPE_FILE" ]; then`):**
   - Checks `[ -f "$PROJECT_TYPE_FILE" ]` instead of `$(get_project_type)`. Because `web` is the implicit default when `PROJECT_TYPE` does not exist on disk, default `web` projects silently bypass the `< 3` entries check under `## What exists already` unless the user explicitly ran `/flow project-type web`.
2. **`seed_law_files()` in `cmd_next()` (`skills/flow/runner/flow.sh`, search `seed_law_files`):**
   - Copies `DESIGN.md` and `RETRO.md` into `$ROOT` at Stage `00` unlock without mentioning them in stdout, surprising beginners when new root files appear.
3. **`lock_acquire()` foreign-lock refusal (`skills/flow/runner/flow.sh`, search `Close the other session. If it is truly gone: re-run with FLOW_FORCE=1, or '/flow unlock'.`):**
   - Leads with Unix-only env-prefix syntax `FLOW_FORCE=1` (which fails in Windows PowerShell/cmd) before the universal `'/flow unlock'` command.

### Current vs Proposed Output
- **`_scan_midtier()` `01-research.md`:** Use `pt="$(get_project_type)"` so implicit `web` and explicit `web` behave identically. *(Audit existing synthetic `01-research.md` test fixtures first!)*
- **`cmd_next()` Stage `00` unlock:** Append `(seeded root DESIGN.md and RETRO.md if absent)` on the instruction line after `PASS: unlocked stage 00 -> flow/00-idea.md`.
- **`lock_acquire()` foreign-lock hint:** `Close the other session. If it is truly gone: run '/flow unlock' (or set FLOW_FORCE=1).`

### Test Contracts to Preserve
- `tests/test_flow_midtier_scanners.sh`, `tests/test_flow_project_types.sh`, and synthetic `stage_clean` helpers in `tests/test_flow_*.sh`: **critical pre-check** — many suites write minimal synthetic `#01-research\n## Gate\n- [x] ok\n` files without a `PROJECT_TYPE` file! Before changing `[ -f "$PROJECT_TYPE_FILE" ]` to `$(get_project_type)`, check every suite that runs `scan_gate` or `next` across synthetic `01-research.md` without `## What exists already`!
- `tests/test_flow_monorepo_root.sh` and `tests/test_flow_runner.sh`: preserve exact `PASS: unlocked stage 00 -> ...` line 1 anchor.
- `tests/test_flow_concurrency_lock.sh`: preserve both `FLOW_FORCE=1` and `unlock` substrings on the `BLOCKED:` refusal output.

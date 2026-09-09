---
title: "Phase 3: Mechanical scanners"
status: todo
priority: P1
effort: "1d"
dependencies: []
---

# Phase 3: Mechanical scanners

## Overview

Put content scanners **inside** `scan_gate` before `return $found` (`flow.sh:191`) so all 12 callers agree. Exclusive: `runner/flow.sh`, `tests/test_flow_midtier_scanners.sh` + `tests/manifest.txt` **same patch**.

## Requirements

- Functional: `_scan_midtier` is invoked from `scan_gate` only when basename is `01-research.md`/`02-scope.md`/`03-prd.md`/`05-contract.md`. Cards (`C-*.md`) and `00-inspect.md` unchanged (box/FILL only)
- Functional: URL/hostname floor **only** when `PROJECT_TYPE` **file exists** and equals `web`. Count distinct hostnames under `## What exists already` only. Accept `host.tld`, `www.`, markdown links, optional `https?://`. f01a-shaped bare domains PASS. <3 hostnames FAIL. This is **not** "opened 3 competitors"
- Functional: `## Features in v1` — join wrapped continuation lines into one bullet, then fail if that bullet has impact L and grade B or C. Does **not** catch f02b C-launder (gate-examples §02)
- Functional: `03-prd.md` adjective scan only `## Features` / NFR **bodies** via awk slice (copy `cmd_clarify` `:2416`). Skip any `^[[:space:]]*- \[[ xX]\]` line. Reuse box regex from `scan_gate:179`. Template checkbox containing `secure` must PASS
- Functional: `02`/`03`/`05` `## Open decisions` markdown bullets >5 FAIL (checked or not)
- Functional: `NEXT_VERB=<next|card|card-start|check|fix-gate|none>` derived **only** from `_next_action` (`:1114`), printed on `status` next to `NEXT ->` and every `resume` exit including `idx<0`. Not catalog `action`. Advisory (ADR-0001: hosts must not auto-exec auto/skip from it)
- Functional: one shared SKIP printer; all three `absent)` arms (`:3815`, `:4126`, `:4381`) include `semantic layer unmeasured on this host`. Keep `return 0`
- Functional: `FLOW_LAST_GATE_FAIL` (`:1009`) counts midtier `[x]` as well as FILL/boxes
- Non-functional: heading slices via **one awk into a variable**, then grep the string. Never `sed|grep -q`/`-m1` pipes. Tests under `_portable_timeout 20` on Windows-class hang
- Non-functional: do not change `_evidence_signal_score`; do not refuse `cmd_skip` (operator DEBT bypass stays)
- Non-functional: `_eval_engine_run` (`:3201-3204`) and `_run_with_timeout` bodies byte-identical

## Architecture

`cmd_next:1002` uses `scan_gate >/dev/null` then only reprints on failure (`:1004`). A sibling after `:1004` never runs when boxes are ticked. Therefore midtier **must** set `found=1` inside `scan_gate`.

Callers (must keep agreeing): `planning_complete:433`, `_gate_state_brief:717,726`, `cmd_status` brownfield `:765`, `cmd_next:1002,1004`, `_next_action:1129,1143`, `cmd_gate` card `:1667` (no midtier), stage `:1677`, `cmd_assess:2101,2106` (`00-inspect` skip).

## Implementation Steps

1. Add `_heading_slice file heading` using clarify's awk; assign to a var
2. Add `_scan_midtier file` ; from `scan_gate` after FILL/box, basename gate, `found=1` on any `[x]`
3. Hostname scanner as specified
4. Joined-bullet L-above-A
5. Adjective + open-decisions
6. `_next_verb` closed map; print `NEXT_VERB=` 
7. `_eval_skip_unmeasured "$kind"` used by routing/converge/artifact absent+fail? **absent only** (fail probe still old wording unless cheap to share)
8. Update `FLOW_LAST_GATE_FAIL`
9. Tests: contiguous gate-clean `00-idea.md` + dirty 01/02/03; `bash flow.sh next`; `planning_complete` false; f01a copy PASS; no PROJECT_TYPE file → no URL floor; `grep -cF 'semantic layer unmeasured on this host' flow.sh` = 3; `grep -qx test_flow_midtier_scanners.sh tests/manifest.txt`; timeout 20 status+next on scanner-dirty 02
10. Manifest line in **same** patch as the suite file

## Test scenario matrix

| Path | Expect |
|---|---|
| Critical | 00+web-typed 01 with 2 hostnames → `next` FAIL; 3 bare domains → PASS |
| Critical | wrapped L then grade B → FAIL; L grade A → PASS |
| Critical | PRD Features "secure API" FAIL; gate checkbox `secure` PASS |
| Critical | 6 open-decision bullets FAIL |
| High | no PROJECT_TYPE file → URL scanner off |
| High | `grep -cF unmeasured` = 3; PATH-hidden claude eval/routing/converge exit 0 |
| High | timeout 20 status+next on scanner-dirty clean-box 02 |
| Medium | engine-body diff empty |

## Todo

- [ ] `_scan_midtier` inside `scan_gate` + awk slices + NEXT_VERB + SKIP helper
- [ ] `test_flow_midtier_scanners.sh` **and** manifest.txt same patch
- [ ] Prove engine bodies unchanged

## Success Criteria

- [ ] All critical/high rows above
- [ ] Card `gate --card` behavior unchanged vs master for a C-001 fixture
- [ ] Exclusive-file grep: this phase did not edit SKILL.md

## Risk Assessment

In-flight projects with f01a-style research: hostname scanner PASSes. Skip still bypasses. Signal: mid-tier `debt add`+`skip`. Response: out of wave (R1 reject).

If awk slice is wrong on Windows CR: strip `\r` first (flow already does in places).

## Dependency map

Wave 2 after docs. Phase 6 greps SKIP count.

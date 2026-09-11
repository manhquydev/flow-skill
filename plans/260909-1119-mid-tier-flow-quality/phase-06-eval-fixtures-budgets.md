---
title: "Phase 6: Eval fixtures + budgets"
status: todo
priority: P1
effort: "6h"
dependencies: [3]
---

# Phase 6: Eval fixtures + budgets

## Overview

Ratchet budgets; document unmeasured skip; assert SKIP phrase count. Exclusive: `gate-eval.md`, `docs/doc-budgets.txt`, additive `tests/test_flow_eval.sh`. Do not edit `flow.sh` or `SKILL.md`.

## Requirements

- `wc -w` SKILL.md and gate-rules.md; `doc-budgets.txt` = measured+10% (SKILL cap in 1600–1800)
- If SKILL.md >1600: **fail and reopen phase 1**
- `gate-eval.md`: skip exit 0 = unmeasured, not semantic pass; live eval is not a merge gate
- `grep -cF 'semantic layer unmeasured on this host' skills/flow/runner/flow.sh` equals **3**
- PATH-hidden claude: `eval`, `eval --stage routing`, `eval --stage converge` still exit 0
- No new eval fixtures if hostname scanner accepts `host.tld`
- Engine bodies unchanged; no live `--record`

## Implementation Steps

1. Measure words; write budgets
2. Unmeasured-host paragraph in gate-eval.md
3. Additive asserts in test_flow_eval.sh (count==3 + three PATH-hidden cases)
4. Confirm eval/manifest.tsv row count unchanged

## Todo

- [ ] Ratchet doc-budgets.txt
- [ ] gate-eval.md paragraph
- [ ] Additive eval tests
- [ ] Reopen phase 1 if SKILL.md >1600

## Success Criteria

- [ ] test_doc_budgets.sh pass
- [ ] SKIP count == 3
- [ ] Engine-body diff empty

## Dependency map

After phase 3 SKIP strings and phase 1 dispatcher. Wave 3.

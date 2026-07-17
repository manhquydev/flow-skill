# Nhật ký — full recommend: CI 30m Windows + rc.3 (2026-07-18)

## Đã làm
- `ci.yml`: bash-suite timeout 30m Windows / 15m else
- `tests/run_all.sh`: per-suite `wall_s` + TOTAL
- `publish-npm-wrapper.yml`: promote_to early-exit + mô tả honest
- Dual-version tests pin `package.json` + `SKILL.md`
- Bump `@manhquy/flow-skill` → **0.1.0-rc.3**, tag `npm@0.1.0-rc.3`

## Verify
- Local `npm test` 41/41
- CI run **29632290661** → **success** (bash-suite windows không còn cancel 15m)
- Publish run **29632293664** → `waiting` (cần approve environment `npm-publish`)

## Việc operator còn
1. Approve https://github.com/manhquydev/flow-skill/actions/runs/29632293664
2. Sau success: `npm view @manhquy/flow-skill dist-tags` (cả `rc`+`latest` nếu cần promote tay)
3. `npx @manhquy/flow-skill@rc --help` → phải thấy `ships skill v0.22.0`

# Nhật ký — chuẩn hóa release process + docs (2026-07-18)

## Mục tiêu
Sau ship rc.3 + fix CI, ghi lại quy trình để bản sau không lặp lại: dual-version, OIDC/dist-tag,
Windows bash timeout, smoke cwd, coherence skill vs npm.

## Đã thêm/sửa
- `docs/release-process.md` — runbook chuẩn (2 trục version, pipelines, anti-patterns, quick RC)
- `npm-wrapper/RELEASE_CHECKLIST.md` — rewrite theo thực tế rc.3 + link runbook
- `CONTRIBUTING.md` — dual-axis + CI Windows timing + links
- `docs/quality-metrics.md` — status rc.3
- `docs/codebase-summary.md` / `system-architecture.md` — distribution map
- `skills/flow/harness/README.md` — flow_version ≠ npm package
- README EN/VN → link release-process

## Không đổi code runtime
Chỉ docs/process; registry vẫn do tag `npm@*` + approve environment.

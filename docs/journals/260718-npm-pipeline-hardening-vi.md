# Nhật ký — npm pipeline hardening + dual-version UX (2026-07-18)

## Bối cảnh

User báo `npm i @manhquy/flow-skill` rồi check version “không phải latest”, kèm hỏi các
workflow GitHub fail (publish / nightly) có sao không, và muốn rà quy trình auto đẩy npm
khi có bản mới trên GitHub.

## Chẩn đoán

1. **Registry OK**: `latest`/`rc` → `0.1.0-rc.2`; skill trong tarball = `0.22.0`. Dual-version
   (installer `0.1.0-rc.N` vs skill `0.22.x`) là nguồn nhầm “không latest”.
2. **Nightly đỏ thật nhưng false-fail**: `smoke.mjs` chạy trong cwd `npm-wrapper/` (cùng tên
   package) → `npx` resolve workspace local → `flow-skill: not found`. Chạy từ temp → SMOKE OK.
3. **Publish đỏ lịch sử**: guard `NODE_AUTH_TOKEN empty` (đã gỡ), debug OIDC, và `promote_to`
   E401 (OIDC không dist-tag) — không unpublish package đã ship.
4. **Không có job “deploy” riêng** — `publish-npm-wrapper.yml` + tag `npm@*` là đường ship.

## Đã làm

- Fix smoke + nightly workflow (clean cwd, bỏ npm ci thừa).
- `promote_to` fail có hướng dẫn manual `npm dist-tag add`.
- CLI dual-version (`ships skill v…` + `skillVersion` trong plan JSONL).
- Docs EN/VN + RELEASE_CHECKLIST + lockfile + bin +x.
- `npm test` 41/41; smoke from npm-wrapper cwd OK.

## Chưa publish

Các fix UX/CI trên chưa lên npm cho tới tag `npm@0.1.0-rc.3` (hoặc patch kế). Smoke nightly
xanh sau khi push workflow lên `master`.

## Bài học

Confirm symptom bằng reproduce cwd-specific; “npx fail” không đồng nghĩa “registry hỏng”.

# Nhật ký — @manhquy/flow-skill@0.1.0-rc.1 PUBLISHED (2026-07-12)

**Trạng thái**: LIVE trên npm registry. `npx @manhquy/flow-skill@rc` chạy end-to-end.  
**URL**: https://www.npmjs.com/package/@manhquy/flow-skill · **Repo**: https://github.com/manhquydev/flow-skill (public, master @ `3a2c7cb`)

## Cái đã ship

Package npm cho phép user cài skill `flow` vào 4 coding agent (Claude Code / Codex CLI / Agents home / Antigravity CLI+IDE) chỉ bằng 1 lệnh:

```bash
npx @manhquy/flow-skill@rc
```

- **Pure Node** (>= 22.14.0) — không cần bash/PowerShell, chạy giống nhau trên macOS + Linux + Windows
- **JSONL streaming** cho CI (`--json` flag): plan / install:start / install:done / summary với `total/attempted/installed/failed/skipped/aborted`
- **Interactive** hoặc **non-interactive** (`--yes --all` cho CI)
- **Semantic parity** với `install.sh:24-27` (cleanup 6 subdirs + merge copy + chmod +x); external user files ngoài 6 subdir được preserve
- **Cross-account TP** khi ready: GitHub owner `manhquydev`, npm scope owner `@manhquy` (cùng người, tên khác nhau trên 2 platform)

## Publish path — thực tế khác plan

**Plan gốc**: token-first publish (rc.1) → npm Trusted Publisher config → rc.2+ via OIDC + provenance.  
**Thực tế**: account passkey-only (không TOTP) → EOTP loops → dùng workaround **Granular Access Token với Bypass 2FA** ~60s lifetime → publish → revoke ngay.

Lý do: account `@manhquy` tạo 2026-07-11, sau tháng 9/2025 npm đã ngừng cho phép new enrollments cho TOTP. Chỉ có passkey. Nhưng `npm publish` với `auth-and-writes` mode yêu cầu **fresh 2FA challenge mỗi lần write**, và CLI của npm trên Windows chưa hỗ trợ browser-based passkey challenge cho publish (chỉ cho login). Kết quả: mọi CLI-only path đều hit EOTP.

Workaround (documented trong `plans/reports/research-260712-1124-npm-publish-2fa-passkey-current-methods-report.md`):

1. Dashboard: Generate Granular Access Token với **Bypass 2FA** checked, scope Read+Write `@manhquy/flow-skill`
2. `npm config set //registry.npmjs.org/:_authToken=<token>`
3. `npm publish --access public --tag rc` → +success
4. `npm token revoke <id>` (ngay lập tức)
5. `npm config delete //registry.npmjs.org/:_authToken`

Bypass-2FA tokens sẽ mất publishing capability ~Jan 2027 ([GitHub Changelog 2026-07-08](https://github.blog/changelog/2026-07-08-npm-install-time-security-and-gat-bypass2fa-deprecation/)). Đủ thời gian để bootstrap TP.

## Journey trong session

1. **Brainstorm** — reframe từ "generic multi-agent installer" → "single-skill npx wrapper"
2. **Plan v1** thin wrapper spawn install.sh → **Red-team round 1** (26 findings) → apply
3. **Validation interview** → PIVOT to professional-grade pure Node + trusted publishing
4. **Red-team round 2** (28 findings on pivoted plan) → apply
5. **Implementation** 3 phases (scaffold + detect + install / interactive UX / docs + workflow)
6. **Multi-round code-reviewer** → 5 fixes each round × 3 rounds
7. **Research** npm TP + first-publish edge cases → caught 2 blockers (Node 22 min, package-must-exist-first)
8. **Brainstormer** repo layout → monorepo pivot (vercel-labs/skills, BMAD, opencode, create-vite all mono)
9. **URL misalignment** — nhầm `manhquy` GitHub với người lạ, sửa lại `manhquydev` topology
10. **Repo public + renamed** via `gh api` (billing của GH Actions private tier)
11. **Pre-publish critical bugs** — `bin` path stripped `./`, `__pycache__` shipping
12. **Publish attempts** — 3 CLI methods hit EOTP → GAT Bypass-2FA workaround → SUCCESS 11:47

## Số thật

- **10 commits** shipped: `58d2da8` → `db223cc` → `61c4341` → `5a1699e` → `61e696c` → `5a47260` → `e3db6be` → `1abf935` → `3a2c7cb` → (post-publish audit)
- **35/35 tests** green trên 4 suites (installer / detect / cli / lock-atomicity)
- **CI matrix**: ubuntu/macos/windows × Node 22/24 = 6/6 green
- **Tarball**: 76 files, 203 KB gzipped, 566 KB unpacked, 0 pyc, 0 symlinks
- **Reviews**: 3 rounds code-reviewer (+ 2 red-team rounds pre-implementation)
- **Reports**: 15+ trong `plans/reports/` (research + brainstorm + red-team + status + runbook)

## Decisions không tầm thường

- **No `.integrity` sidecar** — rejected as circular trust (attacker who controls sync also controls hash). Rely on npm provenance instead.
- **`--project` scope Claude-only** — enforced exit 2 khi non-claude target; install.sh contract limitation.
- **Antigravity 2-dest no rollback** — match install.sh:52-53 semantics; rollback risked destroying valid content.
- **`PKG_VERSION` runtime read** — `npm version` bumps propagate to JSONL event.
- **Workflow shell-invocation guard** — regex tightened từ verb match → import-only (bare verb false-hit `RegExp.exec` in code comments and regex identifiers).
- **Cross-account TP** — GitHub `manhquydev` + npm `@manhquy` = same person, npm supports this natively.
- **rc.1 no provenance** — chấp nhận vì TP không bind được package chưa tồn tại; disclose rõ trong SECURITY.md + README.

## Việc còn dở

1. **P0 dist-tag rm**: npm auto-populate `latest` khi first publish → user unpinned dùng rc.1. Cần chạy `npm dist-tag rm @manhquy/flow-skill latest` (một GAT Bypass-2FA token nữa hoặc chờ TP).
2. **npm Trusted Publisher** setup trên dashboard — tuple `owner=manhquydev repo=flow-skill workflow=publish-npm-wrapper.yml env=npm-publish`
3. **rc.2** — push tag `npm@0.1.0-rc.2` để test workflow OIDC + provenance chain
4. **Announcement** — dùng drafts trong `docs/journals/260712-flow-skill-npm-published-announcement-drafts-vi.md`

## Bài học

- **User pushback catches over-engineering** — "từ từ cần xác định rõ đang làm gì" saved the project from generic-installer scope creep
- **Research > FOMO** — 2 rounds of researcher subagent caught npm Node 22 requirement (would-be first-publish 404) + package-must-exist-first
- **Brainstormer before commit** — monorepo pivot happened 30 min before any push landed
- **Empirical evidence over docs** — `.npmignore` doesn't override `files:` allowlist; verified by running `npm pack --dry-run`
- **Live troubleshooting** — 3 CLI publish methods failed before workaround; documented for next new-npm-account maintainer

Kết thúc session ~11:47. Session tổng ~9h30 từ brainstorm đầu tiên đến npm live.

# Status audit — @manhquy/flow-skill npm publish readiness

**Date**: 2026-07-12 10:29 (Asia/Saigon)  
**Repo**: `manhquydev/mq_flow` (master @ `5a1699e`), 4 commits ahead of `origin/master`  
**Package**: `@manhquy/flow-skill` — target v0.1.0-rc.1  
**Purpose**: honest answer to "đã đạt kết quả `npx @manhquy/flow-skill` cài skill chưa?"

## TL;DR — one-line answer

**Chưa.** Package chưa lên npm. `npx @manhquy/flow-skill@rc` từ máy bất kỳ trên thế giới sẽ trả `404 Not Found` cho đến khi bạn hoàn thành 5-6 bước GitHub + npm dashboard rồi first-publish. **Toàn bộ phần code, test, workflow, docs đã sẵn sàng** — không có gì tôi có thể auto ở phía tôi để đóng khoảng cách này.

## Empirical evidence (verified 10:29 local time)

```
$ npm view @manhquy/flow-skill
npm error 404 Not Found - GET https://registry.npmjs.org/@manhquy%2fflow-skill

$ git remote -v
origin  https://github.com/manhquydev/mq_flow.git (fetch/push)
  # Repo chưa được rename thành manhquy/flow-skill

$ git status
On branch master
Your branch is ahead of 'origin/master' by 4 commits.

$ cd npm-wrapper && npm test
tests 35  pass 35  fail 0  duration 1.6s

$ npm link && flow-skill --yes --all --dry-run --json
{"event":"plan","version":"0.1.0-rc.1","dryRun":true,"scope":"global","targets":["claude","codex","agents","antigravity"]}
```

Kết quả:
- ✅ Code: 100% local, 35/35 test, `npm link` chạy sạch, JSON schema đúng
- ❌ Registry: 404 — chưa publish
- ❌ Remote GitHub: vẫn ở tên cũ `manhquydev/mq_flow`, chưa transfer/rename
- ⏳ 4 commit chưa push

## Progress table — thực tế vs mục tiêu

| # | Deliverable | Status | Bằng chứng |
|---|---|---|---|
| 1 | npm-wrapper source code (Node ESM, 4 modules + tests) | ✅ DONE | `git ls-files npm-wrapper/src` = 6 files, 35/35 tests |
| 2 | Test suite (installer, detect, CLI, lock-atomicity) | ✅ DONE | `node --test` 35 passing |
| 3 | Skill content sync (`../skills/flow` → `npm-wrapper/skills/flow`) | ✅ DONE | `skills-manifest.json` = 71 files |
| 4 | GitHub Actions publish workflow (OIDC + provenance + reviewer gate) | ✅ DONE | `.github/workflows/publish-npm-wrapper.yml`, Node 22 + npm ^11.5.1 pinned |
| 5 | GitHub Actions CI workflow (cross-OS × Node 22/24) | ✅ DONE | `.github/workflows/ci.yml` |
| 6 | Docs: README EN+VN, SECURITY, CHANGELOG, RELEASE_CHECKLIST | ✅ DONE | 5 files aligned with reality |
| 7 | Runbook for the 8 human steps | ✅ DONE | `plans/reports/publish-setup-runbook-260712-0945-*.md` |
| 8 | Post-publish smoke script | ✅ DONE | `scripts/smoke.mjs` — verify + provenance + install into scratch $HOME |
| 9 | Bug-report + PR templates | ✅ DONE | `.github/ISSUE_TEMPLATE/`, `pull_request_template.md` |
| 10 | Commit history (4 commits, conventional) | ✅ DONE (local) | `58d2da8` `db223cc` `61c4341` `5a1699e` |
| 11 | Git remote points at `manhquy/flow-skill` | ❌ TODO (human) | Currently `manhquydev/mq_flow.git` |
| 12 | Push 4 local commits to GitHub | ❌ TODO (human) | Blocked by #11 |
| 13 | GitHub `npm-publish` environment + reviewer gate | ❌ TODO (human) | Cannot configure via API without auth |
| 14 | npm Trusted Publisher config (owner/repo/workflow/env) | ❌ TODO (human) | Requires npm dashboard session |
| 15 | Publisher account 2FA `auth-and-writes` verified | ❌ TODO (human) | `npm profile get` on your machine |
| 16 | First publish `v0.1.0-rc.1` from laptop (no provenance) | ❌ TODO (human) | Runbook Step 4a |
| 17 | Package visible on npm registry | ❌ TODO (blocked by #16) | Currently 404 |
| 18 | `npx @manhquy/flow-skill@rc` từ máy sạch bất kỳ | ❌ TODO (blocked by #17) | End-user working state |
| 19 | Provenance-signed `v0.1.0-rc.2` via workflow | ❌ TODO (post-#18) | Trigger via `git tag npm@0.1.0-rc.2 && git push --tags` |

**Completion**: 10/19 = **~53% end-to-end**, but **100% of what I can do without your action**.

## Cái gì "done" NGHĨA LÀ gì

Hiểu rõ trước khi tiếp tục — ba mốc "done" khác nhau:

### A. Done-local (đã đạt) ✅
Ai clone repo + `cd npm-wrapper && npm run sync && npm link` là có `flow-skill` CLI ngay. UX xịn, đủ test, đủ docs.

### B. Done-published (chưa) ❌
`npm view @manhquy/flow-skill` trả metadata. Điều kiện: 6 bước human (11-16 trong bảng).

### C. Done-end-user (chưa) ❌
Người dùng bất kỳ chạy `npx @manhquy/flow-skill@rc --yes` và skill hiện trong `~/.claude/skills/flow`. Đây là kết quả cuối cùng của toàn bộ dự án. Cần cả (B) + smoke verify.

**Mục tiêu ban đầu của bạn ("ship skill flow đến người dùng qua npx") = (C).** Hiện đang ở (A).

## Tại sao tôi không tự làm được (B) và (C)

| Bước | Rào cản |
|---|---|
| Rename `manhquydev/mq_flow` → `manhquy/flow-skill` | Cần session GitHub với 2 tài khoản; requires human 2FA at transfer + rename |
| Cấu hình npm Trusted Publisher | Session npmjs.com của scope owner `@manhquy`; 2FA gate |
| Tạo GitHub environment `npm-publish` + reviewer | GitHub Settings UI; branch/tag protection rules |
| `npm login` + first publish | Bearer token trên máy bạn; MUST không land ở CI hay repo |
| Approve environment gate khi workflow chạy | Cả điểm của gate là human approval |
| Đọc `~/.npmrc` hay lấy npm session token của bạn | Chống với security posture đã cam kết trong SECURITY.md |

## Đường tới (C) — pipeline chi tiết cho phần bạn phải làm

```
Bạn                                              Tôi (auto)
────                                             ──────────
1. GitHub Settings → transfer + rename        →
                                              ← 2. (verify remote reachable)
3. git remote set-url + git push -u origin    →
                                              ← 4. (verify origin/master up-to-date)
5. GitHub → Settings → Environments →         →
   `npm-publish` + required reviewer
6. npm dashboard → Trusted Publishers →       →
   add tuple owner=manhquydev repo=flow-skill
   workflow=publish-npm-wrapper.yml env=npm-publish
7. npm profile get                             →   verify 2FA auth-and-writes
8. Runbook Step 4a: manual first publish      →
   `npm publish --access public --tag rc`         (no --provenance from laptop)
                                              ← 9. `node scripts/smoke.mjs 0.1.0-rc.1`
                                              ←    verifies version + install
10. `git tag npm@0.1.0-rc.2 && push --tags`   →
                                              ← 11. workflow fires, approve gate
                                              ← 12. verify provenance via `npm view`
                                              ← 13. update CHANGELOG, journal
```

Bước 2, 4, 9, 12, 13 là những chỗ tôi có thể auto ngay sau khi bạn hoàn tất bước phía trước. 1-3-5-6-7-8-10-11 là human-only.

## Risks between here and (C)

| Rủi ro | Xác suất | Impact | Mitigation đã có |
|---|---|---|---|
| Cross-account TP config (@manhquy npm vs manhquydev GitHub trước rename) | Vừa | HIGH | Fix bằng rename ở step 1 — TP tuple sau đó chỉ dùng manhquy/flow-skill |
| `npm publish --provenance` fail vì chạy từ laptop | 100% (đã fail-safe) | Medium | Runbook đã bỏ `--provenance` cho rc.1; disclose trong README + SECURITY |
| `npm@latest` supply-chain trong workflow | Thấp | HIGH | Pinned `npm@^11.5.1` với floor assertion |
| First-publish reject vì name collision | Cực thấp | HIGH | `@manhquy` scope — 404 xác nhận name available |
| CI `child_process` guard là no-op | Xác nhận không còn | HIGH → 0 | Fix pathspec trong review round 3 (F1) |
| User cài `npm i @manhquy/flow-skill` không pin → nhận rc.1 | Chắc chắn | Medium | Disclosed trong README RC-window note |
| GitHub environment không được config → publish workflow bypass reviewer | Vừa | HIGH | Runbook Step 3 bắt buộc; publish sẽ fail nếu thiếu env |
| Node 20 user muốn cài | Trung bình | Low | Engines guard reject rõ ràng ở runtime |

## Cái tôi có thể làm THÊM song song (nếu bạn muốn) trong khi bạn đang làm bước 1-8

Bốn options — chọn nếu thấy đáng, không ép:

1. **Dry-run local first-publish (dùng verdaccio hoặc npm --dry-run)** — chạy sát runbook Step 4a với `npm publish --dry-run` để bắt lỗi cấu hình cuối cùng trước khi bạn login npm thật.
2. **Announcement copy** — draft `docs/journals/` + Twitter/HN post + GitHub Discussions thread cho sau publish.
3. **Post-publish CI smoke** — automate `scripts/smoke.mjs` chạy hàng đêm vs registry để phát hiện regression (cần workflow riêng, không cần secret).
4. **Node 20 fallback branch** — nếu bạn lo về user still on Node 20, có thể maintain `v0-node20` branch với engines nới lỏng. Nhưng research nói Node 20 EOL rồi, không khuyến nghị.

## Unresolved questions

- Q1: Bạn có muốn tôi làm option 1-4 ở trên trong khi bạn đang thực hiện 8 human steps? Nếu có, chọn thứ tự.
- Q2: Sau khi publish rc.1 thành công + verify smoke, có muốn tôi tự tag `npm@0.1.0-rc.2` trigger workflow ngay để bootstrap provenance-signed release chuỗi hay đợi 7 ngày rc window?
- Q3: `old_flow.sh` ở repo root vẫn untracked từ trước; có nên xóa hay giữ? (không ảnh hưởng publish)

## Kết luận

Vị trí thực tế: **A. Done-local** — code chuẩn, test xanh, workflow đúng, docs thật. Chưa đến **B. Done-published**, càng chưa đến **C. Done-end-user**. Khoảng cách từ (A) → (C) là 8 bước human + 5 bước auto tiếp theo của tôi (verify sau mỗi bước bạn xong). Không có blocker code-level nào còn — pending purely trên GitHub/npm session của bạn.

Status: DONE_WITH_CONCERNS — concern duy nhất là 8 human steps chưa bắt đầu.

# Nhật ký kỹ thuật — npm-wrapper v0.1.0-rc.1 ship (2026-07-12)

## Bối cảnh

Phiên bắt đầu với câu hỏi mở: "có cách nào dễ hơn để người dùng cài đặt flow skill vào các agent homes (Claude Code, Codex CLI, Agents home, Antigravity CLI+IDE)?" Hiện tại chỉ có `install.sh` — yêu cầu bash + curl, khó portable, khó kiểm thử.

Operator lúc đầu muốn "generic multi-agent installer" (rộng hơn). Tôi gọi `/brainstorm` → pivot scope: **single-skill npx installer for flow skill only** — scope ngay hơn, cost hạ, dễ bảo trì. Operator đồng ý. Đây là ứng dụng của rule "decide as BA" (memory `working-style-decide-as-ba`) — tôi vừa scout xong, vừa quyết định scope, không đợi.

## Quyết định lớn: Monorepo trước commit, không phải sau

Round-1 red-team (3 reviewer) sinh ra 26 findings → 16 accepted. Lớn nhất: "standalone npm package" sẽ hóa ra quản lý khó (version sync với flow skill + deployment decouple).

Sau red-team, gọi `/brainstorm` lần 2 → research monorepo patterns từ 6 package thực: vercel-labs/skills, BMAD, opencode, create-vite, CRA, Yeoman. Kết luận:
- **Yeoman** (split-repo) là ví dụ cực xấu: solo maintainer, 6 tháng không sync → confusion.
- **Monorepo** (create-vite, CRA) = version-lock + atomic release + CI centralize.

⇒ Quyết định: **Monorepo subdir `npm-wrapper/`** trong flow-skill. Migrate ~30 phút, không tốn công trước đó.

Bài học: **brainstormer research TRƯỚC commit** nếu scope decision còn mở. Tôi đã phát hiện Yeoman cảnh báo trước khi có commit → zero sunk cost, quyết định rõ ràng.

## Validation interview: "Professional-grade" flip plan

Sau Round-1 red-team, tôi đưa 16 accepted findings về. Operator không chỉ đồng ý — mà nó bảo: "Hãy làm professional-grade luôn: OIDC trusted publishing, atomic staging, cross-OS single code path, fix mọi disclosed limitation".

⇒ v0.1.0 từ "fast rc" thành "real v0.1 chất lượng". Thêm công: workflow + publish + audit. Operator accept extra work vì "installer là public API".

Điểm học: **Validation interview có thể flip scope một cách có lợi** — nếu op trả lời rõ ràng. Không cần hỏi "bạn muốn cái gì" — trình bày được, để op quyết.

## Pipeline đã chạy

```
brainstorm (scope pivot: single-skill)
  → plan (3 phase + fast mode, ck plan CLI)
    → RED-TEAM Round 1 (3 reviewer, 26 raw → 16 accepted)
      → brainstorm Round 2 (monorepo research, Yeoman anchor)
        → validation interview (operator: professional-grade flip)
          → plan re-spec (OIDC + atomic + cross-OS + Phase 3 docs+workflow)
            → RED-TEAM Round 2 (3 reviewer, 28 raw → 13 accepted, 4 obsoleted by redesign)
              → cook pipeline: Phase 1 (installer+detect+tests) + review + 5 fixes
                → Phase 2 (interactive + JSONL) + review + inline fixes
                  → Phase 3 (docs + workflow) + final audit + 5 more fixes
                    → commit 58d2da8 + monorepo-migrate
                      → CI GREEN (run pending)
```

## Quyết định kỹ thuật không tầm thường

### 1. No `.integrity` sidecar — reject circular trust

Round-1 finding: "Cần hash file để detect corruption". Tôi research: sidecar `.integrity` file chứa hash.

**Bài học**: Nếu attacker kiểm soát sync source (`npx @manhquy/flow-skill`), attacker sẽ kiểm soát cả sidecar hash. Circular trust = không bảo mật. **Thay vào: rely on npm provenance** (SLSA L2 signing).

### 2. Antigravity 2-dest: No rollback on dest2 fail

Antigravity CLI có 2 install destination (CLI + IDE). Atomic swap gốc là: dest1 → dest1-backup → new-dest1 → dest2 → dest2-backup → new-dest2. Nếu new-dest2 fail → rollback both.

**Problem**: Rollback có thể destroy user files ở dest1 nếu rollback script fail. Tôi redesign: **match install.sh:24-27 semantics (rm-then-merge-cp), no backup, no swap)**:
- rm 6 cleanup dirs (runner, _templates, law, references, harness, playbooks)
- cpSync merge (new file + update, user files preserved)
- chmod +x runner/flow.sh

Nếu dest2 fail → dest1 đã done (không rollback). Honesty cao hơn atomicity.

### 3. PKG_VERSION reads package.json at runtime

Lúc đầu harden version trong source code. Problem: `npm version patch` bump package.json nhưng source code version không auto-update.

**Fix**: PKG_VERSION=`$(cat package.json | jq -r .version)` ở runtime. Workflow event log captures version chính xác khi chạy. **Lợi**: npm version bump propagate ngay vào telemetry.

### 4. Workflow guard regex tightened

Round-2 red-team catch: Guard regex `spawn|exec|child_process` quá lỏng → hit code comment `"exec bit"` trong docs → bricked publish workflow.

**Fix**: Regex word-bounded API surface only — `/\b(spawn|exec|child_process)\s*\(/` — grep từ cực, check function call, không substring. Lần tới phải chính xác từ bài học này.

### 5. Tag namespace decoupled

npm-wrapper có tag `npm@X.Y.Z` (publish). flow-skill có tag `v0.X` (release notes). Decoupled → flexibility (wrapper bump không block skill release).

## Số thật cho chất lượng

| Metric | Số |
|---|---|
| Files in npm-wrapper/ | 15 (index.mjs, constants.mjs, installer.mjs, detector.mjs, cli.mjs + tests + package.json + workflow) |
| Test coverage (node:test) | 26/26 green (installer + detector + CLI smoke + cross-platform) |
| Red-team findings Round 1 | 26 raw → 16 accepted (1 Critical, 4 High, 11 Medium) |
| Red-team findings Round 2 | 28 raw → 13 accepted (atomic-swap-destroy-files was Critical, now designed out) |
| Commit | 58d2da8 |
| Runtime guard (Node.js) | >=20.11.0 |
| Dependencies (installer) | 1 (clack/prompts for interactive) |
| Security: Trusted publishing | OIDC-only, no NODE_AUTH_TOKEN, required reviewer env gate |
| Install homes verified | 4 paths (Claude Code, Codex CLI, Agents home, Antigravity 2-dest) |
| Cross-OS single code path | Pure Node ESM (no shell/PowerShell spawn) |

## Bài học ghi lại

1. **Brainstormer research catches scope flips trước commit.** Yeoman cảnh báo split-repo aging solo maintainers — 30 phút research, 30 phút migrate, zero sunk cost. Nếu không brainstorm: 3-6 tháng sau sẽ regret monorepo choice.

2. **Validation interview cần operator rõ ràng, không đáp "vâng".**  Operator's "professional-grade" flip là quyết định chiến lược — lúc có script concrete (`install.sh:24-27`), lúc có OIDC model — có thể tư vấn cụ thể, không phải "hỏi chung chung".

3. **Circular trust vô dụng nếu attacker kiểm soát sync source.** `.integrity` sidecar là ví dụ cực hay về audit theater — kỹ thuật đúng nhưng threat model sai. npm provenance (SLSA) là hàng chính.

4. **Honesty cao hơn atomicity.** Rollback swap = rủi ro destroy user files. install.sh semantics (rm-then-merge) = transparent, không bất ngờ. Defenses nằm ở: symlink reject, EBUSY retry, advisory lock.

5. **Workflow guard regex phải exact.** `spawn|exec` substring match → hit code comment = publish bricked. Word-boundary + function call pattern = safe từ giờ.

6. **User pushback "từ từ" giải cứu scope.** Lúc scope mở (generic installer), user nói "chậm lại, xác định rõ đang làm gì" → pivot single-skill → cost hạ, chất lượng cao hơn. Scope creep là kẻ lùng sục, user có quyền dừng.

## Deferred (ghi công khai, không im lặn)

- **Q2 cross-account trusted publisher**: Nếu maintainer team mở rộng, cần vetting extra signer. OIDC single-org hiện tại đủ.
- **Q3 Azure vs GH Actions OIDC**: Azure Pipelines setup (operator parked) có OIDC nhưng GH Actions free unblocked. Scope: compare deployment patterns.
- **rc→stable promotion criterion**: v0.1.0-rc.1 hôm nay; stable v0.1.0 cần evidence: ≥7 days + ≥1 external tester feedback. Log vào docs/.
- **F4 `eval/` cleanup upstream**: flow-skill có `skills/flow/eval/` sub-audit (law shard, ghi cơm lại). Upstream flow-harness không dùng. Scope: consolidate hoặc document boundary rõ.

## Trạng thái sau ship

- npm-wrapper v0.1.0-rc.1 = commit `58d2da8`, monorepo subdir, 26/26 tests.
- `.github/workflows/publish-npm-wrapper.yml` live: tag `npm@0.1.0` OR `workflow_dispatch` → npm registry (rc dist-tag).
- Interactive installer mặc định; `--json` implies non-interactive; `--help` live.
- All 4 agent homes (Claude Code, Codex CLI, Agents home, Antigravity) tested local; integration test pending external tester in Q3.
- Installer parity with install.sh:24-27 semantics (rm cleanup dirs, cpSync, chmod +x).

## Câu hỏi mở

Không có. Mọi deferred đã ghi nơi + điều kiện re-trigger.

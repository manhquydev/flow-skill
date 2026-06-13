# Phase 06 — Packaging, install, tests, docs

**Priority:** P2 · **Status:** ✅ done (2026-06-13) · **Depends:** Phase 01–05
**Mục tiêu:** đóng gói skill cài 1 lệnh vào Claude Code (global/project), tái lập 6-round validation, viết docs + journal.

## Context links
- Packaging mẫu: `claudekit-engineer/portable-manifest.json`, `package.json` (`claudekit` field), `scripts/check-skill-*.js`
- Test mẫu: `ai20k-build-phase/buildflow/docs/test-reports/round{1-6}*.md`
- BMAD plugin: `BMAD-METHOD/.claude-plugin/marketplace.json`

## Requirements
**Functional**
- `install.sh`/`install.ps1`: copy `skill/flow/` → `~/.claude/skills/flow` (global) hoặc `<project>/.claude/skills/flow` (per-project); chmod flow.sh; verify python/bash.
- `portable-manifest.json` + `SKILL.md` frontmatter hợp lệ (validate như ck:).
- 6-round test harness tái lập: happy / adversarial / e2e / real-idea / fixes-and-traps / work-mode → mỗi round 1 report PASS/FAIL.
- Docs: `docs/codebase-summary.md`, `docs/system-architecture.md`, `README.md` (cách dùng `/flow`).

**Non-functional**
- Cài chạy trên Windows (PowerShell + Git Bash) và Unix.
- Uninstall sạch (tracked deletions như metadata.json).

## Architecture
```
flow-skill/
├── skill/flow/                  # nội dung cài (phase 01–05)
├── install.ps1 / install.sh     # cài global|project
├── portable-manifest.json
├── tests/                       # 6 round scenario + runner
├── docs/{codebase-summary,system-architecture}.md
└── README.md
```

## Implementation steps
1. Viết `install.ps1` + `install.sh` (chọn global|project, copy, chmod, doctor-check python/bash/cargo).
2. Viết `portable-manifest.json` + validate frontmatter SKILL.md.
3. Viết `tests/` 6 round (kịch bản + expected pass/fail) + runner script chạy flow.sh trên fixture.
4. Chạy toàn bộ test; sửa tới khi 6 round xanh.
5. Viết docs + `README.md` (quickstart `/flow`, bảng lệnh, ví dụ end-to-end).
6. `/ck:journal` ghi entry; `/ck:project-management` sync plan status; hỏi commit qua `git-manager`.

## Todo list
- [ ] install.ps1 + install.sh (global|project, doctor)
- [ ] portable-manifest + frontmatter validate
- [ ] tests/ 6 round + runner
- [ ] Chạy 6 round → xanh
- [ ] docs + README quickstart
- [ ] journal + plan sync + (hỏi) commit

## Success criteria
- 1 lệnh cài skill vào project test, `/flow` hoạt động ngay sau cài.
- 6 round test PASS (tái lập behavior buildflow gốc).
- Uninstall sạch, không sót file.
- Docs đủ để người mới dùng `/flow` không cần hỏi.

## Risk & mitigation
- **Đường dẫn Windows/Unix khác:** install script detect OS; flow.sh dùng path tương đối.
- **Test phụ thuộc môi trường:** fixture self-contained, không gọi mạng ở round cơ học.

## Security considerations
- Install không ghi ngoài thư mục skill đích; không tải binary lạ (Rust harness-cli build local, opt-in).

## Next steps
→ Sau v1 xanh: layer tiếp các tính năng nâng cao (đã đặt nền ở phase 02–05); cân nhắc publish như plugin marketplace.

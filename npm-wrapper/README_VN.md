# @manhquy/flow-skill

Cài skill **flow** vào coding agent bằng một lệnh.

| | |
|---|---|
| **Package** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) (installer CLI) |
| **GA hiện tại** | **0.4.1** — ships skill product **v0.27.0** |
| **Nền tảng** | macOS · Linux · Windows (cùng code path Node) |
| **Yêu cầu** | Node.js **≥ 22.14** |
| **Source** | [github.com/manhquydev/flow-skill](https://github.com/manhquydev/flow-skill) |

flow là harness build có cổng (`/flow`): ý tưởng → cổng trung thực → bằng chứng done thật. Package này chỉ **cài** skill đó vào skill home của agent.

---

## Lệnh chuẩn

```bash
# Khuyến nghị — luôn gắn @latest để npx không dùng cache cũ
npx @manhquy/flow-skill@latest
```

| Bước | Chi tiết |
|------|----------|
| 1 | Tải dist-tag **`latest`** từ npm registry |
| 2 | Multi-select tương tác các agent detect được (Claude luôn được đề xuất) |
| 3 | Copy cây `skills/flow` vào từng đích đã chọn |
| 4 | In hướng dẫn sau reload (`/flow`, `$flow`, …) |

**Sau cài:** restart hoặc reload agent (xem [Sau khi cài](#sau-khi-cài)).

### Xác nhận version

```bash
npx @manhquy/flow-skill@latest --help
# expect: flow-skill v0.4.x (ships skill v0.27.x)
```

### Lệnh hay dùng

```bash
# Không prompt (Claude + agent đã detect)
npx @manhquy/flow-skill@latest --yes

# Một hoặc nhiều target
npx @manhquy/flow-skill@latest --yes --target claude
npx @manhquy/flow-skill@latest --yes -t claude -t codex
npx @manhquy/flow-skill@latest --yes -t claude,codex

# Mọi target được hỗ trợ
npx @manhquy/flow-skill@latest --yes --all

# Skill Claude trong repo (dễ commit)
npx @manhquy/flow-skill@latest --yes --project --dir .

# Chỉ xem kế hoạch, không ghi đĩa + JSONL (CI)
npx @manhquy/flow-skill@latest --yes --all --dry-run --json
```

### Tùy chọn

| Flag | Ý nghĩa |
|------|---------|
| `-y`, `--yes` | Bỏ prompt; cài selection mặc định (detected + Claude) |
| `-t`, `--target <name>` | Target (lặp được hoặc comma-separated) |
| `--all` | Mọi target, kể cả chưa detect |
| `--project` | Scope project — chỉ Claude → `<dir>/.claude/skills/flow` |
| `--dir <path>` | Thư mục project (kéo theo `--project`; mặc định: cwd) |
| `--json` | JSONL events (`plan`, `install:*`, `summary`) |
| `--dry-run` | In plan; không ghi đĩa |
| `-h`, `--help` | Help |

### Targets

| Tên | Đích | Detection |
|-----|------|-----------|
| `claude` | `~/.claude/skills/flow` | `~/.claude` (luôn được đề xuất) |
| `codex` | `~/.codex/skills/flow` | `~/.codex/skills` |
| `agents` | `~/.agents/skills/flow` | `~/.agents/skills` |
| `antigravity` | `~/.gemini/antigravity-cli/skills/flow` **và** `~/.gemini/config/skills/flow` | một trong hai path |
| `cursor` | `~/.cursor/skills/flow` | `~/.cursor/skills` |

`--project` **chỉ** hỗ trợ `claude`. Kết hợp target khác → exit `2`.

### Quy tắc

| Nên | Không |
|-----|--------|
| `npx @manhquy/flow-skill@latest` | Bare `npx @manhquy/flow-skill` (cache npx có thể cũ) |
| **Chạy** CLI để copy skill | Chỉ `npm i` (chỉ thêm package; không cài skill vào agent home) |
| Pin installer `@0.4.1` nếu cần cố định | Pin npm `@0.27.0` (version **skill** ≠ version package) |
| Ưu tiên `@latest` / `@0.4.x` | `@rc` (đã retire / tụt hậu) |

**Hai trục version:** `package.json` = installer CLI; `SKILL.md` metadata = skill product. Cả hai hiện trong `--help` và event JSONL `plan` (`version` + `skillVersion`).

---

## Sau khi cài

| Agent | Bước tiếp |
|-------|-----------|
| Claude Code | Gõ `/flow` |
| Codex CLI | Restart Codex một lần → `$flow` |
| Antigravity | Restart IDE / `agy` → `/flow` |
| Agents home | Reload tool nếu không tự nhận skill mới |
| Cursor | Reload Cursor; kiểm panel agent skills |
| Bất kỳ | `/flow doctor` (hoặc `runner/flow.sh doctor`) |

### Kiểm tra trên đĩa (Claude global)

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

---

## Gỡ cài

```bash
rm -rf ~/.claude/skills/flow
rm -rf ~/.codex/skills/flow
rm -rf ~/.agents/skills/flow
rm -rf ~/.cursor/skills/flow
rm -rf ~/.gemini/antigravity-cli/skills/flow
rm -rf ~/.gemini/config/skills/flow
# project scope:
rm -rf <project>/.claude/skills/flow
```

---

## Xử lý sự cố

| Hiện tượng | Cách xử lý |
|------------|------------|
| Agent không có `/flow` sau `npm i` | Chạy `npx @manhquy/flow-skill@latest` (phải **execute** installer) |
| Skill cũ sau khi “cài lại” | Luôn dùng `@latest`; tránh bare package name |
| `No matching version found` với `@0.27.0` | Đó là version **skill**. Dùng `@latest` hoặc `@0.4.x` |
| Node quá cũ | Cài Node ≥ 22.14 (`nvm install 22`, v.v.) |
| Windows `EBUSY` / `EPERM` | Đóng agent đang giữ file trong skill dir; chạy lại |
| Stale install lock | Xóa `<parent>/.flow-skill.installing.lock` nếu reclaim thất bại |

---

## JSONL (`--json`)

```jsonl
{"event":"plan","version":"0.4.1","skillVersion":"0.27.0","dryRun":false,"scope":"global","targets":["claude"]}
{"event":"install:start","target":"claude","dests":["~/.claude/skills/flow"]}
{"event":"install:done","target":"claude","dests":["~/.claude/skills/flow"],"result":"success","error":null,"warnings":[]}
{"event":"summary","success":true,"total":1,"attempted":1,"installed":1,"failed":0,"skipped":0,"aborted":false}
```

Exit codes: `0` success · `1` target failure · `2` bad usage · `130` SIGINT.

Contract additive: field mới có thể xuất hiện; field hiện có không đổi tên/xóa.

---

## Provenance & bảo mật

Bản publish từ CI có [npm provenance](https://docs.npmjs.com/generating-provenance-statements). Mô hình đe dọa và báo cáo: [SECURITY.md](./SECURITY.md).

## License

MIT © 2026 manhquy

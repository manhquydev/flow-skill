# @manhquy/flow-skill

Cài skill **flow** vào coding agent bằng một lệnh.

| | |
|---|---|
| **Package** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) (installer CLI) |
| **GA hiện tại** | **0.4.1** — ships skill product **v0.27.0** |
| **Nền tảng** | macOS · Linux · Windows (cùng code path Node) |
| **Yêu cầu** | Node.js **≥ 22.14** |
| **Source** | [github.com/manhquydev/flow-skill](https://github.com/manhquydev/flow-skill) |

flow là harness build có cổng (`/flow`). Package này chỉ **cài** skill đó vào skill home của agent.

---

## Lệnh chuẩn

```bash
# Khuyến nghị — luôn gắn @latest để npx không dùng cache cũ
npx @manhquy/flow-skill@latest
```

| Bước | Chi tiết |
|------|----------|
| 1 | Tải dist-tag **`latest`** từ npm |
| 2 | Multi-select agent (Claude luôn được đề xuất) |
| 3 | Copy `skills/flow` vào từng đích |
| 4 | In hướng dẫn gọi sau reload (`/flow`, `$flow`, …) |

**Sau cài:** restart/reload agent (xem [Sau khi cài](#sau-khi-cài)).

### Xác nhận version

```bash
npx @manhquy/flow-skill@latest --help
# expect: flow-skill v0.4.x (ships skill v0.27.x)
```

### Lệnh hay dùng

```bash
# Không prompt (Claude + agent đã detect)
npx @manhquy/flow-skill@latest --yes

# Target rõ ràng
npx @manhquy/flow-skill@latest --yes --target claude
npx @manhquy/flow-skill@latest --yes -t claude -t codex
npx @manhquy/flow-skill@latest --yes -t claude,codex

# Cả 5 target
npx @manhquy/flow-skill@latest --yes --all

# Skill trong repo (chỉ Claude)
npx @manhquy/flow-skill@latest --yes --project --dir .

# Chỉ xem kế hoạch + JSONL (CI)
npx @manhquy/flow-skill@latest --yes --all --dry-run --json
```

### Tùy chọn

| Flag | Ý nghĩa |
|------|---------|
| `-y`, `--yes` | Bỏ prompt; cài selection mặc định |
| `-t`, `--target <name>` | Target (lặp hoặc comma) |
| `--all` | Mọi target, kể cả chưa detect |
| `--project` | Scope project — chỉ Claude → `<dir>/.claude/skills/flow` |
| `--dir <path>` | Thư mục project (kéo theo `--project`) |
| `--json` | JSONL events |
| `--dry-run` | Không ghi đĩa |
| `-h`, `--help` | Help |

### Targets

| Tên | Đích | Detection |
|-----|------|-----------|
| `claude` | `~/.claude/skills/flow` | `~/.claude` |
| `codex` | `~/.codex/skills/flow` | `~/.codex/skills` |
| `agents` | `~/.agents/skills/flow` | `~/.agents/skills` |
| `antigravity` | 2 path dưới `~/.gemini/…` | CLI hoặc IDE skills |
| `cursor` | `~/.cursor/skills/flow` | `~/.cursor/skills` |

`--project` **chỉ** hỗ trợ `claude` (exit `2` nếu kết hợp target khác).

### Quy tắc

| Nên | Không |
|-----|--------|
| `npx @manhquy/flow-skill@latest` | Bare package name (cache npx) |
| **Chạy** CLI | Chỉ `npm i` |
| Pin `@0.4.0` nếu cần | Pin `@0.27.0` trên npm (version skill) |
| `@latest` | `@rc` |

**Hai trục version:** package = installer; skill = `SKILL.md`. Cả hai hiện trong `--help` và event `plan` (`version` + `skillVersion`).

---

## Sau khi cài

| Agent | Bước tiếp |
|-------|-----------|
| Claude Code | Gõ `/flow` |
| Codex | Restart Codex → `$flow` |
| Antigravity | Restart IDE/`agy` → `/flow` |
| Agents / Cursor | Reload tool; kiểm panel skill |
| Bất kỳ | `/flow doctor` |

```bash
grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

---

## Gỡ cài

```bash
rm -rf ~/.claude/skills/flow ~/.codex/skills/flow ~/.agents/skills/flow
rm -rf ~/.cursor/skills/flow
rm -rf ~/.gemini/antigravity-cli/skills/flow ~/.gemini/config/skills/flow
rm -rf <project>/.claude/skills/flow
```

---

## Xử lý sự cố

| Hiện tượng | Cách xử lý |
|------------|------------|
| Có package nhưng không có `/flow` | Chạy `npx @manhquy/flow-skill@latest` |
| Skill cũ sau khi “cài lại” | Luôn `@latest` |
| `No matching version` với `@0.27.0` | Dùng `@latest` / `@0.4.x` (version skill ≠ package) |
| Node quá cũ | Nâng Node ≥ 22.14 |
| Windows EBUSY | Đóng agent đang giữ file skill; chạy lại |

---

## JSONL · provenance · license

Xem bản [English README](./README.md) cho bảng event JSONL, provenance, và [SECURITY.md](./SECURITY.md).

MIT © 2026 manhquy

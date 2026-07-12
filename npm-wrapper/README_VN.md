# @manhquy/flow-skill

Trình cài đặt một-lệnh sao chép skill [flow](https://github.com/manhquy/flow-skill) vào (các) coding agent của bạn.

- Pure Node — chạy trên macOS, Linux, Windows (cmd, PowerShell 5.1/7, Git Bash) với cùng một code path.
- Multi-select tương tác hoặc chế độ CI không tương tác.
- Bảo toàn file người dùng đã thêm ngoài 6 subdir mà skill sở hữu.
- Ship kèm [npm provenance](https://docs.npmjs.com/generating-provenance-statements) qua GitHub Actions trusted publishing.

## Cài đặt

```
# Pin semver (khuyến nghị)
npx @manhquy/flow-skill@0.1.x
```

Prompt tương tác sẽ hỏi cài vào agent nào. Chọn một hoặc nhiều, xác nhận, xong.

> **Chú ý**: pin `@0.1.x` (hoặc phiên bản cụ thể) thay vì `@latest`. Xem [SECURITY.md](./SECURITY.md).

## Non-interactive

```
# Chọn mặc định (Claude + những agent detect được)
npx @manhquy/flow-skill@0.1.x --yes

# Target rõ ràng
npx @manhquy/flow-skill@0.1.x --yes -t claude -t codex
npx @manhquy/flow-skill@0.1.x --yes -t claude,codex           # Dạng comma OK

# Ép cài cả 4 target dù không detect
npx @manhquy/flow-skill@0.1.x --yes --all

# Project scope (chỉ Claude — xem bên dưới)
npx @manhquy/flow-skill@0.1.x --yes --project --dir .

# JSONL cho CI
npx @manhquy/flow-skill@0.1.x --yes --all --dry-run --json
```

## Targets

| Tên | Nhãn | Đích | Marker phát hiện |
|---|---|---|---|
| `claude` | Claude Code | `~/.claude/skills/flow` | bất kỳ presence của `~/.claude` (Claude luôn pre-check) |
| `codex` | Codex CLI | `~/.codex/skills/flow` | `~/.codex/skills` |
| `agents` | Agents home | `~/.agents/skills/flow` | `~/.agents/skills` |
| `antigravity` | Antigravity (CLI + IDE) | `~/.gemini/antigravity-cli/skills/flow` **và** `~/.gemini/config/skills/flow` | `~/.gemini/antigravity-cli` **hoặc** `~/.gemini/config/skills` |

Scope `--project` ghi vào `<dir>/.claude/skills/flow` và chỉ hỗ trợ target `claude`. Kết hợp `--project` với target khác → exit code `2`.

## Sau khi cài

- Claude Code: gõ `/flow`.
- Codex CLI: gõ `$flow` (restart Codex 1 lần để load).
- Antigravity: `/flow` trong IDE.
- Chẩn đoán: chạy `/flow doctor` từ agent.

## Gỡ cài đặt

Xóa dir target:

```
rm -rf ~/.claude/skills/flow
rm -rf ~/.codex/skills/flow
rm -rf ~/.agents/skills/flow
rm -rf ~/.gemini/antigravity-cli/skills/flow
rm -rf ~/.gemini/config/skills/flow
```

## Yêu cầu

- Node.js **>= 20.11.0**

## Bảo mật

Xem [SECURITY.md](./SECURITY.md).

## License

MIT © 2026 manhquy

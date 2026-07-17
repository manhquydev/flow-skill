# @manhquy/flow-skill

Trình cài đặt một-lệnh sao chép skill [flow](https://github.com/manhquydev/flow-skill) vào (các) coding agent của bạn.

- Pure Node — chạy trên macOS, Linux, Windows (cmd, PowerShell 5.1/7, Git Bash) với cùng một code path.
- Multi-select tương tác hoặc chế độ CI không tương tác.
- Bảo toàn file người dùng đã thêm ngoài 6 subdir mà skill sở hữu.
- Ship kèm [npm provenance](https://docs.npmjs.com/generating-provenance-statements) qua GitHub Actions trusted publishing (từ rc.2+).

## Cài đặt

```
# Kênh pre-release (hiện tại — v0.1.0-rc.2)
npx @manhquy/flow-skill@rc
```

Prompt tương tác hỏi cài vào agent nào. Chọn một hoặc nhiều, xác nhận, xong.

> **Giai đoạn RC**: pin `@rc` (dist-tag) hoặc phiên bản cụ thể `@0.1.0-rc.2`. `npx @manhquy/flow-skill@0.1.x` chỉ dùng được sau khi stable `0.1.0` publish — semver range **không** match pre-release theo mặc định. Xem [SECURITY.md](./SECURITY.md).

## Non-interactive

```
# Chọn mặc định (Claude + những agent detect được)
npx @manhquy/flow-skill@rc --yes

# Target rõ ràng
npx @manhquy/flow-skill@rc --yes -t claude -t codex
npx @manhquy/flow-skill@rc --yes -t claude,codex           # Dạng comma OK

# Ép cài cả 5 target dù không detect
npx @manhquy/flow-skill@rc --yes --all

# Project scope (chỉ Claude — xem bên dưới)
npx @manhquy/flow-skill@rc --yes --project --dir .

# JSONL cho CI
npx @manhquy/flow-skill@rc --yes --all --dry-run --json
```

## Targets

| Tên | Nhãn | Đích | Marker phát hiện |
|---|---|---|---|
| `claude` | Claude Code | `~/.claude/skills/flow` | bất kỳ presence của `~/.claude` (Claude luôn pre-check) |
| `codex` | Codex CLI | `~/.codex/skills/flow` | `~/.codex/skills` |
| `agents` | Agents home — cũng là thư mục [Agent-Skills](https://agentskills.io) chung mà các tool tuân chuẩn khác đọc | `~/.agents/skills/flow` | `~/.agents/skills` |
| `antigravity` | Antigravity (CLI + IDE) | `~/.gemini/antigravity-cli/skills/flow` **và** `~/.gemini/config/skills/flow` | `~/.gemini/antigravity-cli` **hoặc** `~/.gemini/config/skills` |
| `cursor` | Cursor | `~/.cursor/skills/flow` | `~/.cursor/skills` (không bao giờ dùng thư mục config `~/.cursor` trần — ai dùng Cursor cũng có) |

Scope `--project` ghi vào `<dir>/.claude/skills/flow` và chỉ hỗ trợ target `claude`. Kết hợp `--project` với target khác → exit code `2`.

## Sau khi cài

Skill vừa cài xong sẽ không được agent nhận ra cho tới khi agent reload — dòng cuối cùng của
installer nói rõ việc cần làm cho đúng target đã cài:

- Claude Code: gõ `/flow`.
- Codex CLI: gõ `$flow` (restart Codex 1 lần để load skill mới).
- Antigravity: restart/reload IDE (hoặc restart `agy`) để load skill mới, rồi gõ `/flow`.
- Agents home: restart/reload tool nếu nó không tự nhận skill mới.
- Cursor: **đã xác nhận cài đúng chỗ, chưa xác nhận runner chạy độc lập** — Cursor không có
  CLI headless để tự động kiểm (khác `agy -p` của Antigravity hay `codex exec` của Codex);
  restart/reload Cursor sau khi cài rồi kiểm tra panel Agent xem có skill `flow` không.
- Chẩn đoán: chạy `/flow doctor` từ agent.

## Gỡ cài đặt

Xóa dir target:

```
# Global installs
rm -rf ~/.claude/skills/flow
rm -rf ~/.codex/skills/flow
rm -rf ~/.agents/skills/flow
rm -rf ~/.gemini/antigravity-cli/skills/flow
rm -rf ~/.gemini/config/skills/flow

# Project scope (chỉ Claude)
rm -rf <project>/.claude/skills/flow
```

## JSONL contract

`--json` stream một JSON object mỗi dòng. Xem [README.md § JSONL contract](./README.md#jsonl-contract) cho bảng đầy đủ event/field/exit code. Tóm tắt:

- `plan` — event đầu tiên; chứa `version`, `dryRun`, `scope`, `targets`.
- `install:start` / `install:done` — một cặp mỗi target; `install:done.result` = `success` hoặc `failed`.
- `summary` — event cuối cùng; `success`, `total`, `attempted`, `installed`, `failed`, `skipped`, `aborted`.
- Exit codes: `0` OK · `1` ≥1 target fail · `2` sai flag/target · `130` Ctrl+C.

Hợp đồng additive trong `0.1.x` — field mới có thể thêm, field cũ không rename/xóa.

## Troubleshooting

- **`EBUSY`/`EPERM` giữa install trên Windows**: một agent đang giữ handle vào file trong destination. Đóng agent + re-run. Installer đã retry 100/300/900 ms trước khi báo error.
- **Advisory lock cũ**: run trước crash. Run mới tự phát hiện PID dead → reclaim. Trường hợp hiếm (PID được recycle bởi process khác đang chạy): xóa `<parent-of-dest>/.flow-skill.installing.lock`.
- **`No matching version found` với `@0.1.x`**: cài pre-release qua stable range. Dùng `@rc` hoặc `@0.1.0-rc.N` cho tới khi stable `0.1.0` ship.
- **Node quá cũ** (`requires Node.js >=22.14.0`): update bằng `nvm install 22`, `fnm install 22`, hoặc installer chính thức của Node. Node 20 hết vòng đời từ 4/2026; npm OIDC Trusted Publishing cần npm >=11.5.1 (bundle theo Node 22.14+).

## Yêu cầu

- Node.js **>= 22.14.0** — Node 20 hết vòng đời từ 4/2026, và publish workflow cần npm >=11.5.1 (bundle theo Node 22.14+) cho OIDC Trusted Publisher

## Provenance

Mỗi phiên bản publish có [npm provenance](https://docs.npmjs.com/generating-provenance-statements) attestation. Verify:

```
npm view @manhquy/flow-skill@<version> dist.attestations.provenance
```

> **Ngoại lệ RC-window**: `v0.1.0-rc.1` được publish thủ công từ máy developer để bootstrap npm
> Trusted Publisher (TP không thể bind tới package chưa tồn tại) — bản này không có provenance.
> Từ `v0.1.0-rc.2` trở đi, mọi bản publish đều qua CI workflow với OIDC và có attestation
> SLSA Build Level 2 đầy đủ.

## Bảo mật

Threat model + WILL/WON'T list + kênh report — xem [SECURITY.md](./SECURITY.md). Tóm tắt: pure Node, không network call, không spawn shell/PowerShell, không postinstall hook, không chạm settings/hooks/MCP config.

## License

MIT © 2026 manhquy

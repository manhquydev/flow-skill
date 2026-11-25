<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/manhquydev/flow-skill/master/brand/brand-lockup-dark.svg">
    <img src="https://raw.githubusercontent.com/manhquydev/flow-skill/master/brand/brand-lockup-light.svg" alt="flow — gated build harness for coding agents" width="560">
  </picture>
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/@manhquy/flow-skill"><img src="https://img.shields.io/npm/v/@manhquy/flow-skill?color=cb3837&style=flat-square" alt="npm version"></a>
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/node-%3E%3D22.14-brightgreen?style=flat-square" alt="Node.js >= 22.14"></a>
  <a href="https://github.com/manhquydev/flow-skill/blob/master/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License: MIT"></a>
  <a href="https://flowskill.io.vn"><img src="https://img.shields.io/badge/docs-flowskill.io.vn-blueviolet?style=flat-square" alt="Documentation"></a>
</p>

# @manhquy/flow-skill

CLI cài đặt chính thức cho **Flow** — harness build có cổng hướng dẫn coding agent từ ý tưởng đến phần mềm sẵn sàng production thông qua các cổng kiểm định trung thực và có bằng chứng xác thực.

[English](./README.md) · [Tiếng Việt](./README_VN.md)

---

## Bắt đầu nhanh

```bash
npx @manhquy/flow-skill@latest
```

Trình cài đặt tương tác tự động nhận diện các coding agent đã cài đặt, sao chép gói skill `/flow` vào thư mục skill tương ứng và giúp bạn sẵn sàng chỉ sau vài giây.

---

## Hỗ trợ Coding Agent & Mục tiêu

| Agent | Thư mục Skill | Lệnh kích hoạt |
|---|---|---|
| **Claude Code** | `~/.claude/skills/flow` | `/flow` |
| **Cursor** | `~/.cursor/skills/flow` | Agent Skills panel |
| **Codex CLI** | `~/.codex/skills/flow` | `$flow` |
| **Antigravity** | `~/.gemini/antigravity-cli/skills/flow` | `/flow` |
| **OMP** | `~/.omp/agent/skills/flow` | `/flow` |
| **Universal Agents** | `~/.agents/skills/flow` | Tự động nhận diện |

---

## Lệnh thông dụng & Tùy chọn

```bash
# Cài đặt tương tác (khuyến nghị)
npx @manhquy/flow-skill@latest

# Tự động / không hỏi lại (tất cả agent đã nhận diện + Claude)
npx @manhquy/flow-skill@latest --yes

# Chỉ định target cụ thể
npx @manhquy/flow-skill@latest --yes --target claude,cursor

# Phạm vi dự án (chỉ Claude Code — cài vào .claude/skills/flow trong repo hiện tại)
npx @manhquy/flow-skill@latest --yes --project --dir .

# Xem trước kế hoạch cài đặt mà không ghi file
npx @manhquy/flow-skill@latest --yes --all --dry-run
```

### Bảng tùy chọn CLI

| Tùy chọn | Mô tả |
|---|---|
| `-y, --yes` | Cài đặt không cần qua các bước nhắc tương tác |
| `-t, --target <name>` | Chỉ định target cụ thể (phân cách bằng dấu phẩy hoặc lặp lại flag) |
| `--all` | Cài đặt cho tất cả các target được hỗ trợ |
| `--project` | Cài đặt vào repository dự án cục bộ (`.claude/skills/flow`) |
| `--dry-run` | Xem trước kế hoạch cài đặt mà không ghi đĩa |
| `--json` | Xuất các sự kiện JSONL cho CI/tự động hóa |
| `-h, --help` | Hiển thị trợ giúp CLI |

---

## Lần chạy đầu & Các bước tiếp theo

Sau khi cài đặt hoàn tất, hãy khởi động lại hoặc tải lại coding agent trong **thư mục chính** của dự án (không mở trong thư mục con). Codex CLI dùng `$flow`; các agent dùng slash command (Claude Code, Antigravity, OMP) dùng `/flow`:

1. **Bắt đầu bằng cách chat Tiếng Việt hoặc English:**
   - `/flow mình muốn làm web nhắc bài tập cho lớp` (Codex: `$flow mình muốn làm...`)
   - `/flow I want to build a class homework tracker web app`
   - Hoặc chạy `/flow assess` trước nếu thư mục đã có sẵn code.
2. **Chọn tốc độ phù hợp với bạn:** Trả lời **đồng ý (yes)** để bật **`work` mode** (AI hỏi 5 câu ngắn, soạn nháp các bước `00–05` và dừng chờ bạn duyệt) hoặc giữ **`teach` mode** (bạn tự điền file kế hoạch) — cả hai chế độ đều giữ nguyên 100% cổng kiểm tra.
3. **Các lệnh thường dùng:**
   - Codex: `$flow`; agent dùng slash command: `/flow` — kiểm tra giai đoạn hiện tại và xem điều gì đang chặn tiến trình
   - Codex: `$flow next`; agent dùng slash command: `/flow next` — đánh giá tiêu chí cổng và chuyển sang giai đoạn tiếp theo
   - Codex: `$flow doctor`; agent dùng slash command: `/flow doctor` — kiểm tra môi trường và tính toàn vẹn của gói skill đã cài đặt

### Khi cổng báo `FAIL`

- Xem đúng số dòng `L<line>` được chỉ ra trong thông báo `FAIL`.
- Thay thế trọn cụm `[FILL: ...]` (xóa luôn cả dấu ngoặc vuông `[` `]`) và đánh dấu ô kiểm `- [x]` (chữ `x` thường), hoặc gõ `/flow mode work` (Codex: `$flow mode work`) để AI hỗ trợ soạn nháp cùng bạn.
- Chạy lại `/flow next` (Codex: `$flow next`) cho các cổng lập kế hoạch.
- Để hoàn tất card đầu tiên (`PASS: C-001 is valid (status: done)`):
  1. Chạy lệnh tạo file bằng chứng thật ngoài thực tế (ví dụ: `mkdir -p evidence && node -e "console.log('ready')" > evidence/cli-smoke.log && cat evidence/cli-smoke.log`).
  2. Trong `cards/C-001.md`, tick mọi ô Verify `- [x]` và **thay thế hoàn toàn dòng `(empty until done)`** dưới `## Evidence` bằng `evidence/cli-smoke.log`, kết quả lệnh (`ready`), và `exit 0` (chỉ đưa đường dẫn file `.js` chỉ đạt `1/2` và vẫn `FAIL`).
  3. Chạy `/flow card done C-001` (Codex: `$flow card done C-001`) để chuyển sang `status: done` và kiểm gate — hoặc tự đổi `status: done` trong `cards/C-001.md` rồi chạy `/flow check C-001` (Codex: `$flow check C-001`, chỉ kiểm tra trạng thái hiện tại của card).

---

## Phiên bản & Khả năng tương thích

| | |
|---|---|
| **Mục tiêu phát hành** | npm **1.0.1** / skill **v1.0.1** — kênh dự kiến `latest`; không phải biên nhận đã phát hành |
| **Node.js** | `>= 22.14.0` (trình cài đặt) |
| **Môi trường chạy (Flow v1)** | Python `>= 3.7` từ [python.org](https://www.python.org/) (`sqlite3` có sẵn) · Windows: [Git for Windows](https://git-scm.com/) (Git Bash) |
| **Tài liệu** | [flowskill.io.vn](https://flowskill.io.vn) |
| **Kho lưu trữ** | [GitHub: manhquydev/flow-skill](https://github.com/manhquydev/flow-skill) |
| **Giấy phép** | MIT |

Bản phát hành đã xác minh ngày 2026-10-30: GitHub phát hành skill v1.0.0 (2026-10-24) và npm installer 1.0.0 (2026-10-25); registry xác nhận `latest` là 1.0.0. Xem [hướng dẫn migration](https://github.com/manhquydev/flow-skill/blob/master/docs/migration-v1.md) để biết cặp rollback trước v1 đã xác minh.

---

## Xử lý sự cố & Câu hỏi thường gặp

- **Agent không nhận lệnh `/flow`:** Hãy chắc chắn rằng bạn chạy qua lệnh `npx @manhquy/flow-skill@latest`. Nếu chỉ chạy `npm install @manhquy/flow-skill` đơn thuần, npm chỉ tải package về `node_modules` mà không thực thi cài đặt để sao chép skill vào thư mục của agent.
- **Cập nhật Flow:** Chạy lại lệnh `npx @manhquy/flow-skill@latest` bất cứ lúc nào. Luôn gắn `@latest` để đảm bảo `npx` không dùng bản lưu cache cũ.
- **Yêu cầu Node.js & môi trường chạy:** Trình cài đặt yêu cầu Node.js >= 22.14 LTS (`node --version`). Khi chạy các lệnh `/flow`, bạn cần Python >= 3.7 từ python.org (`sqlite3` đi kèm sẵn; trên Windows hãy tránh alias `python` rỗng của Microsoft Store) và **Git for Windows (Git Bash)** nếu dùng Windows. Gõ `/flow doctor` bất cứ lúc nào để kiểm tra toàn bộ môi trường.
- **Gỡ cài đặt:** Xóa thư mục skill khỏi các đường dẫn agent mà bạn đã cài:
  ```bash
  rm -rf ~/.claude/skills/flow ~/.cursor/skills/flow ~/.codex/skills/flow ~/.agents/skills/flow ~/.gemini/antigravity-cli/skills/flow ~/.omp/agent/skills/flow
  ```

---

## Bảo mật & Nguồn gốc xuất xứ

Các gói được phát hành từ CI đều có [npm provenance](https://docs.npmjs.com/generating-provenance-statements) xác thực. Mô hình đe dọa, chính sách bảo mật và bảo đảm chuỗi cung ứng: [SECURITY.md](./SECURITY.md).

## Giấy phép

[MIT](./LICENSE) © 2026 manhquy

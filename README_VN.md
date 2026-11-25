<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="brand/brand-lockup-dark.svg">
    <img src="brand/brand-lockup-light.svg" alt="flow — gated build harness for coding agents" width="560">
  </picture>
</p>

# flow — harness build có cổng cho coding agent

*English: [README.md](README.md).*

[![npm](https://img.shields.io/npm/v/@manhquy/flow-skill?label=npm&color=cb3837)](https://www.npmjs.com/package/@manhquy/flow-skill)
[![website](https://img.shields.io/badge/website-flowskill.io.vn-1aa3c4)](https://flowskill.io.vn)
[![tests](https://img.shields.io/badge/tests-manifest.txt-brightgreen)](tests/manifest.txt)
[![CI](https://github.com/manhquydev/flow-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/manhquydev/flow-skill/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Flow sở hữu cổng và biên nhận, không bao giờ sở hữu runtime
([ADR định danh](docs/adr/0001-discipline-layer-identity.md)). Cổng cơ học
(`flow.sh`) và cổng ngữ nghĩa (`SKILL.md`) phải cùng đồng ý trước khi một
stage tiến. Kill tại một cổng là kết quả hợp lệ, được tôn trọng.

`/flow` đưa sản phẩm từ ý tưởng tới bằng chứng done thật. Chat là cửa mặc
định; lệnh gõ vẫn dùng được. Độc lập — không bắt buộc AgentKit hay claudekit.

## Hiểu đơn giản

Flow là danh sách kiểm tra chất lượng từng bước cho trợ lý AI lập trình của bạn
(**Ý tưởng -> Kế hoạch -> Việc nhỏ -> Bằng chứng chạy thật**) để AI không đoán
mò hay báo "xong rồi" khi chưa chạy được. Phù hợp cho lập trình viên, học sinh
và người chưa biết code học Vibe Coding — chat tự nhiên bằng Tiếng Việt hoặc English.

| | |
|---|---|
| **Skill product** | Mục tiêu phát hành **v1.0.1** (không phải biên nhận đã phát hành) |
| **npm installer** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) — mục tiêu phát hành **1.0.1**, kênh dự kiến `latest` (không phải biên nhận đã phát hành) |
| **Website** | **[flowskill.io.vn](https://flowskill.io.vn)** |
| **Test / CI** | [`tests/manifest.txt`](tests/manifest.txt) · Ubuntu · macOS · Windows |
| **License** | MIT |

Bản phát hành đã xác minh ngày 2026-10-30: GitHub phát hành skill v1.0.0 (2026-10-24) và npm installer 1.0.0 (2026-10-25); registry xác nhận `latest` là 1.0.0. Xem [hướng dẫn migration](docs/migration-v1.md) để biết cặp rollback trước v1 đã xác minh.

## Tài liệu

[English](https://flowskill.io.vn/) ·
[Tiếng Việt](https://flowskill.io.vn/vi/) ·
[Docs](https://flowskill.io.vn/docs/) ·
[Tài liệu](https://flowskill.io.vn/vi/docs/)

## Cài đặt

**Yêu cầu:**
- [Node.js](https://nodejs.org/) **>= 22.14** (để chạy trình cài đặt)
- [Python](https://www.python.org/) **>= 3.7** tải từ python.org (`sqlite3` có sẵn, không cần `pip install`; trên Windows hãy tránh alias `python` rỗng từ Microsoft Store)
- **Git for Windows (có sẵn Git Bash)** nếu bạn dùng Windows ([git-scm.com](https://git-scm.com/))

Bạn có thể chạy `/flow doctor` (Codex: `$flow doctor`) bất cứ lúc nào để kiểm tra máy đã đủ môi trường chưa.

```bash
npx @manhquy/flow-skill@latest
```

Luôn dùng `@latest`. Đừng chỉ `npm i` package — lệnh đó không copy skill.
Version skill trong lịch sử không nhất thiết là version package npm để pin.

Skill product và npm installer nay dùng chung một SemVer; `SKILL.md` là nguồn chuẩn.
`--help` giữ banner tương thích với hai giá trị bằng nhau:
`flow-skill v<package-version> (ships skill v<skill-version>)`.

Hướng dẫn: [Cài đặt và lần chạy đầu](https://flowskill.io.vn/vi/docs/tutorials/install-and-first-run/).
Flag: [npm-wrapper/README_VN.md](./npm-wrapper/README_VN.md).

## Lần chạy đầu

1. Mở công cụ AI trong **thư mục chính** của dự án (không mở trong thư mục con), nơi Flow dùng hoặc tạo `flow/` và `cards/`.
2. Chat tự nhiên bằng Tiếng Việt hoặc English (Codex dùng `$flow`): ví dụ `/flow mình muốn làm web nhắc bài tập cho lớp` hoặc `/flow I want to build a class homework tracker web app` (hoặc gõ `/flow assess` nếu thư mục đã có code sẵn).
3. Chọn cách làm phù hợp với bạn: trả lời **đồng ý (yes)** để bật **`work` mode** (AI hỏi 5 câu ngắn, soạn nháp các bước `00–05` rồi dừng chờ bạn duyệt) hoặc giữ **`teach` mode** (bạn tự điền file: xóa trọn cụm ngoặc `[FILL: ...]`, sau đó đổi `- [ ]` thành `- [x]`). Cả hai chế độ đều giữ nguyên 100% cổng kiểm tra. Chi tiết: [hướng dẫn](https://flowskill.io.vn/vi/docs/tutorials/install-and-first-run/).

## Giải nghĩa nhanh thuật ngữ

| Thuật ngữ | Nghĩa dễ hiểu |
|---|---|
| `Gate` | Chốt kiểm tra trước khi qua bước mới; cả script (`flow.sh`) và luật AI (`SKILL.md`) phải cùng đạt. |
| `Kill at a gate` | Chủ động dừng sớm ý tưởng chưa khả thi để đỡ tốn công làm tiếp (**không** xóa file của bạn). |
| `Card (C-001)` | Một phần việc nhỏ, kiểm thử được, tạo ra sau khi các bước lập kế hoạch `00–05` qua cổng (hoặc `debt-skip`). |
| `ADR & Contract` | Ghi chú ngắn về lựa chọn công nghệ (`04-adr`) và đầu vào/đầu ra thống nhất (`05-contract`) trước khi code. |
| `World-state proof` | Bằng chứng chạy thật (link sống hoặc file `evidence/cli-smoke.log` có thật + kết quả lệnh & `exit 0`), thay thế `(empty until done)`. |
| `Resume / Worktree` | `/flow resume` giúp làm tiếp phiên trước; worktree là bản sao thư mục tách riêng để làm song song an toàn. |

## Hằng ngày

```
/flow            status [--json] — đang ở đâu, cái gì chặn
/flow next       kiểm gate + mở stage kế
/flow assess     đánh giá brownfield
/flow card       tạo build card
/flow card done C-001  tick Verify - [x], thay (empty until done) bằng proof -> PASS done
/flow check C-001      kiểm trạng thái hiện tại (nếu done: cần status: done + Verify + proof)
/flow auto       build tự động (HALT nhóm bảo mật)
/flow doctor     kiểm môi trường
/flow resume    tiếp tục dự án Flow hiện có trong session mới (chỉ đọc)
```

Bảng đầy đủ: [`skills/flow/SKILL.md`](skills/flow/SKILL.md) ·
[docs/reference/commands](https://flowskill.io.vn/vi/docs/reference/commands).

## Đóng góp

Xem [`CONTRIBUTING.md`](CONTRIBUTING.md) để biết hướng dẫn cài đặt dev local, quy ước code và quy trình PR.

```bash
bash tests/run_all.sh    # bộ test từ tests/manifest.txt
```

## Giấy phép

[MIT](LICENSE) © 2026 manhquydev.

Ghi chú phát hành: [`CHANGELOG.md`](./CHANGELOG.md).

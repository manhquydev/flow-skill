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

| | |
|---|---|
| **Skill product** | Mục tiêu phát hành **v1.0.0** (không phải biên nhận đã phát hành) |
| **npm installer** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) — mục tiêu phát hành **1.0.0**, kênh dự kiến `latest` (không phải biên nhận đã phát hành) |
| **Website** | **[flowskill.io.vn](https://flowskill.io.vn)** |
| **Test / CI** | [`tests/manifest.txt`](tests/manifest.txt) · Ubuntu · macOS · Windows |
| **License** | MIT |

## Tài liệu

[English](https://flowskill.io.vn/) ·
[Tiếng Việt](https://flowskill.io.vn/vi/) ·
[Docs](https://flowskill.io.vn/docs/) ·
[Tài liệu](https://flowskill.io.vn/vi/docs/)

## Cài đặt

**Yêu cầu:** [Node.js](https://nodejs.org/) **≥ 22.14** để cài đặt; thao tác sản phẩm Flow v1 yêu cầu Python **≥ 3.7** (chỉ thư viện chuẩn). Đây là yêu cầu mục tiêu trước phát hành cho đến khi triển khai v1 vượt qua các cổng nghiệm thu.

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

Mở session agent mới trong thư mục cấp cao nhất của dự án, nơi Flow tạo `flow/` và `cards/`
khi bạn bắt đầu sử dụng (nếu đang ở trong thư mục con, chuyển về thư mục gốc repository
trước) — nói bạn muốn build gì, rồi gõ `/flow`
(Codex: `$flow`). Chi tiết:
[hướng dẫn](https://flowskill.io.vn/vi/docs/tutorials/install-and-first-run/).

## Hằng ngày

```
/flow            status [--json] — đang ở đâu, cái gì chặn
/flow next       kiểm gate + mở stage kế
/flow assess     đánh giá brownfield
/flow card       tạo build card
/flow check C-001  validate card (done = bằng chứng thế giới thật)
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

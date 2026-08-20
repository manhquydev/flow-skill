# flow — harness build có cổng cho coding agent

*English: [README.md](README.md).*

[![npm](https://img.shields.io/npm/v/@manhquy/flow-skill?label=npm&color=cb3837)](https://www.npmjs.com/package/@manhquy/flow-skill)
[![website](https://img.shields.io/badge/website-flowskill.io.vn-1aa3c4)](https://flowskill.io.vn)
[![tests](https://img.shields.io/badge/tests-manifest.txt-brightgreen)](tests/manifest.txt)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions%20%C2%B7%203%20OS-blue)](.github/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Flow sở hữu cổng và biên nhận, không bao giờ sở hữu runtime
([ADR định danh](docs/adr/0001-discipline-layer-identity.md)). Cổng cơ học
(`flow.sh`) và cổng ngữ nghĩa (`SKILL.md`) phải cùng đồng ý trước khi một
stage tiến. Kill tại một cổng là kết quả hợp lệ, được tôn trọng.

`/flow` đưa sản phẩm từ ý tưởng tới bằng chứng done thật. Chat là cửa mặc
định; lệnh gõ vẫn dùng được. Độc lập — không bắt buộc AgentKit hay claudekit.

| | |
|---|---|
| **Skill product** | **v0.31.0** |
| **npm installer** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) **0.7.x** (`@latest` 0.7.0; `@next` prerelease 0.7.1-next.0 ship skill ở trên) |
| **Website** | **[flowskill.io.vn](https://flowskill.io.vn)** |
| **Test / CI** | [`tests/manifest.txt`](tests/manifest.txt) · Ubuntu · macOS · Windows |
| **License** | MIT |

## Tài liệu

[English](https://flowskill.io.vn/) ·
[Tiếng Việt](https://flowskill.io.vn/vi/) ·
[Docs](https://flowskill.io.vn/docs/) ·
[Tài liệu](https://flowskill.io.vn/vi/docs/)

## Cài đặt

**Yêu cầu:** [Node.js](https://nodejs.org/) **≥ 22.14**.

```bash
npx @manhquy/flow-skill@latest
```

Luôn dùng `@latest`. Đừng chỉ `npm i` package — lệnh đó không copy skill.
Đừng pin `@0.31.0` trên npm — đó là version skill, không phải installer.

Hai số version (cố ý): package npm = installer CLI; skill product =
`SKILL.md` `metadata.version`. `--help` in cả hai:
`flow-skill v0.7.1-next.0 (ships skill v0.31.0)`.

Hướng dẫn: [Cài đặt và lần chạy đầu](https://flowskill.io.vn/vi/docs/tutorials/install-and-first-run/).
Flag: [npm-wrapper/README_VN.md](./npm-wrapper/README_VN.md).

## Lần chạy đầu

Mở session agent mới, nói bạn muốn build gì, rồi gõ `/flow`
(Codex: `$flow`). Chi tiết:
[hướng dẫn](https://flowskill.io.vn/vi/docs/tutorials/install-and-first-run/).

## Hằng ngày

```
/flow            status — đang ở đâu, cái gì chặn
/flow next       kiểm gate + mở stage kế
/flow assess     đánh giá brownfield
/flow card       tạo build card
/flow check C-001  validate card (done = bằng chứng thế giới thật)
/flow auto       build tự động (HALT nhóm bảo mật)
/flow doctor     kiểm môi trường
```

Bảng đầy đủ: [`skills/flow/SKILL.md`](skills/flow/SKILL.md) ·
[docs/reference/commands](https://flowskill.io.vn/vi/docs/reference/commands).

## Đóng góp

```bash
bash tests/run_all.sh    # bộ test từ tests/manifest.txt
```

Ghi chú phát hành: [`CHANGELOG.md`](./CHANGELOG.md).

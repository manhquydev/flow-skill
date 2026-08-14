---
title: "CLI cài đặt"
description: "Lệnh npx cài skill flow, hai số version nó báo, và bảng flag đầy đủ sống ở đâu."
lang: vi
---

## Lệnh

```bash
npx @manhquy/flow-skill@latest
```

Cần [Node.js](https://nodejs.org/) **22.14 trở lên**. Luôn ghi `@latest` — lệnh trần `npx @manhquy/flow-skill` có thể lấy từ cache npx và chạy bản cũ.

## Nó báo gì

```bash
npx @manhquy/flow-skill@latest --help
# flow-skill v0.7.0 (ships skill v0.30.0)
```

`0.7.0` là installer CLI này. `0.30.0` là skill product nó copy lên đĩa. Xem [Phiên bản: npm installer vs skill product](/vi/docs/explanation/versions-npm-vs-skill).

## Biến thể thường dùng

Sao nguyên; đừng paraphrase nghĩa flag. `--project` chỉ áp cho `claude`.

```bash
npx @manhquy/flow-skill@latest --yes
npx @manhquy/flow-skill@latest --yes --target claude
npx @manhquy/flow-skill@latest --yes -t claude -t codex
npx @manhquy/flow-skill@latest --yes --all
npx @manhquy/flow-skill@latest --yes --project --dir .
npx @manhquy/flow-skill@latest --yes --all --dry-run --json
```

## Bảng flag đầy đủ

Bảng flag chuẩn — chạy không tương tác, chọn target, cài theo project, dry run, JSON — được giữ cùng installer:

**[npm-wrapper/README_VN.md](https://github.com/manhquydev/flow-skill/blob/master/npm-wrapper/README_VN.md)**

File đó là nguồn sự thật cho nghĩa flag. Không nhân bản ở đây, nên không lệch hạn sử dụng ở đây. Bỏ qua bảng version trong file đó — dùng số live `0.7.0` / `0.30.0` ở trên.

## Package

[`@manhquy/flow-skill` trên npm](https://www.npmjs.com/package/@manhquy/flow-skill)

## Xem thêm

- [Cài đặt và lần chạy đầu](/vi/docs/tutorials/install-and-first-run)
- [Đường dẫn cài đặt](/vi/docs/reference/install-paths)
- [Khắc phục cài đặt](/vi/docs/how-to/troubleshoot-install)

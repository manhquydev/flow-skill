---
title: "Phiên bản: npm installer vs skill product"
description: "flow có hai số version cố ý. Một số version CLI installer, số kia version skill gác cổng build của bạn."
lang: vi
---

`flow` publish hai số version, và chúng không khớp. Đó là **cố ý**, không phải drift.

| Cái gì | Hiện tại | Nó version cái gì |
|---|---|---|
| **Skill product** | `0.30.0` | Các cổng, `SKILL.md`, runner, references, templates — thứ phán build của bạn. |
| **npm installer** | `0.7.0` | CLI `@manhquy/flow-skill` copy skill vào agent home. |

Kiểm cả hai từ máy của bạn chứ không từ tài liệu nào:

```bash
npx @manhquy/flow-skill@latest --help
# flow-skill v0.7.0 (ships skill v0.30.0)

grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
# version: "0.30.0"
```

## Vì sao hai số

Chúng version artifact khác nhau với nhịp đổi khác nhau.

```
  monorepo skills/flow/  --npm run sync-->  npm-wrapper/skills/flow  --npm pack-->  registry
         |                                         |
         | install.sh / agent skill homes          | npx @manhquy/flow-skill@latest
         v                                         v
  ~/.claude/skills/flow                     same tree via installer CLI
```

Skill product là harness. Version của nó dẫn check coherence và trường telemetry ghi trong lớp bền vững, nên dự án luôn nói được ngữ nghĩa cổng nào nó được build dưới. Nó đổi mỗi khi cổng, stage, hoặc playbook tham chiếu đổi — nghĩa là thường xuyên.

Package npm chỉ version **installer CLI**: detect agent, multi-select tương tác, file copy đi đâu, các flag. Bề mặt đó nhỏ và ổn định. Publish installer version mới vì luật cổng đổi sẽ nói dối về cái gì đã đổi, và buộc user lý luận về một số không nói gì với họ.

Gộp hai số nghĩa là hoặc bump installer mỗi lần đổi cổng, hoặc đóng băng version cổng theo nhịp phát hành installer. Cả hai tệ hơn giải thích một bảng.

## Sai lầm chuyện này gây ra, và cách tránh

Mode fail là pin nhầm số:

```bash
# SAI — 0.30.0 là skill product, không phải version package npm đã publish
npx @manhquy/flow-skill@0.30.0

# Đúng — pin installer nếu cần bản cố định
npx @manhquy/flow-skill@0.7.0

# Tốt hơn cho hầu hết mọi người
npx @manhquy/flow-skill@latest
```

Luôn dùng `@latest` khi muốn skill mới nhất. Lệnh trần `npx @manhquy/flow-skill` có thể lấy từ cache npx và âm thầm chạy bản cũ. Tag `@rc` đã retire; đừng dùng.

## Số nào quan trọng với bạn

Nếu bạn **dùng** flow, skill product là số mô tả trải nghiệm — nó nói bạn có cổng nào và lệnh nào. Version installer chỉ quan trọng khi debug lần cài hoặc pin một bản.

Nếu bạn **báo vấn đề**, đưa cả hai. `--help` in chúng cùng một dòng, đó là lý do dòng đó tồn tại.

## Kiểm drift trong một dự án

```
/flow coherence
```

Gắn cờ lệch version giữa các trường version khai báo — lát cắt doc-versus-code rẻ của lattice drift. Chỉ cảnh báo: gắn cờ, không tự sửa.

## Xem thêm

- [CLI cài đặt](/vi/docs/reference/install-cli)
- [Cài đặt và lần chạy đầu](/vi/docs/tutorials/install-and-first-run)
- [Nhật ký thay đổi](/vi/docs/reference/changelog)

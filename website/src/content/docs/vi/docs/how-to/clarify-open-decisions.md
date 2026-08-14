---
title: "Làm rõ quyết định còn mở"
description: "Tìm và chốt quyết định sản phẩm chưa xong đang nằm trong Scope, PRD, và Contract."
lang: vi
---

Quyết định sản phẩm chưa xong sống thành bullet `- [ ]` dưới heading `## Open decisions` trên artifact Scope, PRD, và Contract. Chúng được đếm bởi *cùng* scanner ô mà các cổng đã dùng, nghĩa là quyết định chưa chốt thật sự chặn stage chứ không ngồi trong comment không ai đọc. `/flow clarify` in các bullet sót đó, scoped đúng section, và luôn exit 0 — nó là máy in cố vấn, không phải cổng thứ hai. Chốt chúng là nghi thức write-back có biên, opt-in: đi từng bullet, ghi quyết định vào artifact, rồi tick ô. Không gì về `clarify` là điều kiện tiên quyết của `/flow next`; scanner cổng đang ép các ô vốn đã là điều kiện đó.

Nghi thức write-back:
[`skills/flow/references/clarify.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/clarify.md)

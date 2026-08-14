---
title: "Ma trận loại dự án"
description: "Seam contract, bằng chứng done, và trình tự card cho web, cli, library, và skill."
lang: vi
---

Đặt bằng `/flow project-type <web|cli|library|skill>`, lưu trong `PROJECT_TYPE`, mặc định `web`.

| Loại | Seam contract (stage 05) | Bằng chứng done | Trình tự card |
|---|---|---|---|
| `web` | HTTP endpoint — method, path, auth, request, response; OpenAPI được phục vụ | URL đã deploy live cộng output `curl` thật | scaffold và `/healthz`, lát cắt dọc, backend, contract test, UI mock, frontend, e2e |
| `cli` | Lệnh, flag, shape output, exit code | Tool cài được và một lần gọi thật trả output và exit code đúng | scaffold cộng một lệnh thật, nhóm subcommand, test, smoke cài trên thư mục sạch |
| `library` | Bề mặt public API — hàm và type export kèm shape | Public API import được, ví dụ dùng chạy được, đạt ngưỡng coverage | scaffold cộng core API, các vòng API, test, ví dụ dùng chạy được, dry-run publish |
| `skill` | Lệnh và file mà agent đọc | Cài vào skill home và một lần chạy thật đạt done-definition của chính nó | scaffold cộng một lệnh chạy được, references và law, cài, một lần chạy dogfood |

Hằng số trên cả bốn loại: mọi requirement map tới một interface, mọi interface có shape viết trước code, contract là seam, và “tests pass” hoặc “merged” không bao giờ là done.

Nguồn, kể cả hương vị web đã biết của một số wording cổng stage-05:
[`skills/flow/references/project-types.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/project-types.md)

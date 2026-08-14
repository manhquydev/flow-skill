---
title: "Workspace nhiều agent"
description: "Cho mỗi agent một git worktree riêng để một lần đổi nhánh không lật mọi terminal."
lang: vi
---

`/flow workspace add|list|enter|remove|check|doctor` cấp một `git worktree` mỗi agent, giải bẫy một agent đổi nhánh thì mọi terminal khác lật theo. Mỗi worktree có HEAD, index, và file riêng trong khi chia sẻ object store. `add <branch>` tạo cây với port-offset riêng và in khối cd/env dán-là-chạy; `list` hiện ai ở đâu; `enter <branch>` in lại môi trường cho terminal crash; `check <branch> --card` gắn cờ trùng nhánh và overlap allowed-files *trước* khi bạn launch; `remove` dỡ mà không bao giờ auto-force, và `doctor` đối soát cây/bản ghi mồ côi. git là registry và lock thật — việc nó từ chối checkout cùng một nhánh hai lần mới bảo vệ bạn; side-file `.flow/workspaces.jsonl` chỉ thêm metadata vendor, card, port, task phía trên.

Chi tiết subcommand:
[`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md)

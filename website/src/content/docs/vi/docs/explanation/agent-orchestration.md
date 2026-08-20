---
title: "Điều phối agent"
description: "Stage ủy thác cho agent chuyên khi chúng tồn tại và rơi về hành vi built-in khi không. Cổng không bao giờ dịch."
lang: vi
---

Mỗi stage có thể ủy thác phần soạn cho agent chuyên, và rơi về hành vi built-in khi không cái nào được cài, đó là thứ giữ `flow` portable chứ không phụ thuộc registry agent của ai khác. Thang ưu tiên là agent chuyên trước, rồi skill tương đương, rồi fallback built-in. Bản đồ stage gần đúng như bạn kỳ vọng: research tới researcher, scope và PRD tới planner, ADR tới architect, contract tới kernel hướng spec, build tới fullstack developer, review tới code reviewer hoặc review đối kháng ba lớp, verify live tới tester.

Luật làm chuyện này an toàn là một câu: **agent gắn vào được, cổng cố định.** Cổng giống nhau trên mọi path, nên agent thiếu không bao giờ hạ thanh và agent fancy không bao giờ nâng pass nó không đáng. Ủy thác cũng cô lập ngữ cảnh by design: subagent chỉ nhận task, file, tiêu chí chấp nhận, và trích law hoặc contract liên quan, không bao giờ lịch sử session, và trả một trong một tập nhỏ phán `DONE`, `DONE_WITH_CONCERNS`, `BLOCKED`, `NEEDS_CONTEXT`. Sau mọi ủy thác cổng chạy, thử thách ngữ nghĩa được áp, hook bền vững được ghi, và path nào thực sự chạy được thông báo.

Trang này là nhà operator cho bề mặt power quanh luật đó: một worktree mỗi agent, engine phụ tùy chọn, vòng recall/promote, và biên nhận gắn fingerprint. Sơ đồ maintainer ở repo; chỉ link ở chân trang.

## Workspace nhiều agent {#multi-agent-workspace}

Nhiều agent trên nhiều terminal cùng một checkout là bẫy: một đứa đổi nhánh thì mọi terminal khác lật theo. `/flow workspace` cấp mỗi agent một `git worktree` riêng (HEAD, index, file riêng, chia sẻ object store) để chuyện đó không xảy ra.

```
/flow workspace add <branch>
/flow workspace add <branch> --card C-NNN --vendor <name> --task "<one line>" --copy-env
/flow workspace list
/flow workspace enter <branch>
/flow workspace check <branch> --card C-NNN
/flow workspace remove <branch>
/flow workspace doctor
```

- `add <branch>` tạo cây với port-offset riêng (hai server local không đụng nhau) và in khối `cd`/env dán-là-chạy. Cờ tùy chọn ghim card, nhãn vendor, một dòng task, và có copy env sang cây mới hay không.
- `list` hiện ai ở đâu.
- `enter <branch>` in lại môi trường cho terminal crash.
- `check <branch> --card` gắn cờ trùng claim nhánh và overlap allowed-files *trước* khi bạn launch. Hãy chạy. Conflict lúc merge sau này nghĩa là check đó bị bỏ hoặc bị lách.
- `remove` dỡ cây và không bao giờ auto-force. Git từ chối thì bạn gỡ; `flow` không `--force` hộ.
- `doctor` đối soát cây và bản ghi mồ côi.

git mới là registry và lock thật. `git worktree list` là live; việc git từ chối checkout cùng một nhánh hai lần mới bảo vệ bạn. Side-file `.flow/workspaces.jsonl` chỉ thêm metadata vendor, card, port, task phía trên.

Dùng các verb này để journal không thủng. `git worktree add` trần không ghi gì.

## Engine thứ hai {#second-engine}

OpenAI Codex (plugin `openai-codex`) là engine thứ hai tùy chọn. Google Antigravity (CLI `agy` hoặc IDE Antigravity) là engine thứ ba tùy chọn. Cả hai là vendor thêm, dùng cùng những thời điểm giá trị cao, để một lần review được phán bởi model ít khi chung điểm mù. Không cái nào thay thang agent chuyên → skill → built-in. Engine mặc định vẫn là thang đó. Vắng Codex hay Antigravity không bao giờ làm hỏng lần chạy.

`flow` phân biệt *installed* với *usable*. Installed nghĩa là thư mục plugin, binary, hoặc IDE có mặt. Usable thêm đòi probe rẻ không tính phí báo engine thật sự ready và đã login. Chỉ engine usable mới được route tới. Nếu không, `flow` degrade lặng-mà-có-báo về thang bình thường, và cổng không dịch.

Antigravity nhận probe nghiêm nhất trong hai cái, vì lý do đo được: `agy -p` trả exit code 0 với stdout rỗng ngay cả khi chưa login, lỗi chỉ nằm trong file log. Nên `flow` chỉ route sang Antigravity khi output mong đợi không rỗng, không bao giờ dựa exit code (exit code nói dối). Capture headless trên platform đó không đáng tin, nên mặc định được hỗ trợ là interactive: chạy review trong IDE Agent Manager hoặc terminal thật rồi dán kết quả lại. Kết quả Gemini rỗng nghĩa là "review không sẵn" và không bao giờ là duyệt.

Vì lời gọi tính phí và vì diff cùng trích contract hoặc PRD rời máy, đúng ba trigger mở cost gate:

1. Deadlock two-strikes: agent cùng-model bị chặn hai lần. Antigravity là engine phụ đi sau: nó bắn ở đây sau Codex nếu cả path cùng-model và engine thứ hai đều kẹt.
2. Review card security-class.
3. Operator opt-in tường minh ("review this on Codex", "review this on Antigravity", `/flow … codex`, `/flow … antigravity`).

Không bắn mọi stage theo mặc định. Với codebase nhạy, regulated, hoặc NDA, hãy opt-in có biết: chọn Codex gửi brief đó tới OpenAI theo điều khoản retention của plan bạn; chọn Antigravity gửi tới Google theo plan Gemini. Auth ủy thác hết cho plugin hoặc cho `agy` / IDE. `flow` không đọc, không lưu, không log credential đó.

Parity cổng là tuyệt đối. Codex hoặc Antigravity soạn hoặc phê; cùng cổng stage vẫn phán. Review cross-model hỗ trợ triage. Không bao giờ tự pass và không bao giờ tự fail một card.

Sau mỗi lần dùng, `flow` báo engine nào chạy (hoặc tầng không sẵn và đã degrade sang đâu). Run vẫn đọc được.

## Vòng kiến thức {#knowledge-loop}

Cửa sổ conversation quên. Harness bền vững (store SQLite cộng `RETRO.md`, `DEBT.md`, và `playbooks/`) là vòng khép kín capture, reuse, improve, nên dự án do agent lái tích lũy trải nghiệm như một đội người.

Capture do engine bắn chứ không tự nguyện:

- tiến qua stage 01 seed một intake
- lần check card pass ghi trace được chấm tier
- skip có chủ đích ghi debt

Reuse là `/flow recall`. Chạy lúc bắt đầu stage hoặc card, trước khi soạn gì. Nó đọc lại debt đang mở, retro gần nhất, scope card trước, friction và backlog harness, sức khỏe audit, và playbook đã promote, để work bắt đầu với nỗi đau cũ trong tầm mắt thay vì phát hiện lại.

Improve cũng cơ học: `harness audit` chấm entropy và drift, `harness propose` đào friction lặp thành backlog cải tiến khi pattern bắn ít nhất hai lần, và `harness decision outcome` đóng vòng dự-đoán versus thực-tế.

Ritual vào lại giữa chừng bắt đầu bằng `resume` rồi `recall` nằm ở
[Resume giữa chừng](/vi/docs/how-to/resume-mid-project/#recall-and-promote).

### Promote {#promote}

Khi bài học lớn hơn một dự án, nâng nó:

```
/flow promote <playbook.md>
```

Lệnh copy playbook vào KB liên-dự-án tại `~/.claude/flow/playbooks`. Từ đó `recall` hiện nó mọi nơi chứ không chỉ nơi nó được học.

## Thực thi có attest {#attested-execution}

Khi lần chạy đã tự chủ, "cái này đã được review" phải nghĩa là thứ script kiểm được. Control plane attested-execution phát biên nhận gắn fingerprint: biên nhận `semantic_gate` cho stage hoặc card đã review, biên nhận `live_verify` cho lần deploy đã check, gắn fingerprint của thứ chúng duyệt.

```
/flow attest semantic --stage <stage> --revision <rev> --owner <manifest>
/flow attest semantic --card <id> --base <rev> --revision <rev> --owner <manifest>
/flow attest live-verify <id> --revision <rev> --owner <manifest>
/flow attest status [<stage|card>]
/flow attest recover <C-NNN> --mark-failed
```

Mint chạy trên blob đã commit ở một revision cụ thể, không phải thứ bẩn trong working tree. Biên nhận live đòi đúng HEAD tip cộng fingerprint tính lại, nên sửa file sau khi duyệt làm mất hiệu lực lần duyệt thay vì thừa kế lặng lẽ. `status` nói biên nhận còn hiện hành hay không. `recover … --mark-failed` là lối Must-ask khi live verify kẹt giữa chừng: đánh dấu attempt đó fail, không mint pass.

Khi `/flow auto` đang bật, `check`, lần flip card do CLI sở hữu, sẵn sàng dependency, và gỡ worktree đã merge đều đòi biên nhận hiện hành. `/flow auto stop` trả bạn về mode thủ công chỉ-cảnh-báo. Không có đường tắt ẩn. Luật HALT của auto, kể cả HALT security-class, ở [Khi việc phải dừng](/vi/docs/explanation/auto-tiers-and-security-halts/).

Biên nhận phát hiện **subject staleness**. Chúng không xác thực actor và không chống host thù địch. Chúng canh vòng tự chủ đừng tiêu thụ lần duyệt đã cũ của chính nó.

---

Nhà maintainer (không phải trang công khai): [`skills/flow/SKILL.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/SKILL.md), [`skills/flow/references/codex-integration.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/codex-integration.md), [`skills/flow/references/antigravity-integration.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/antigravity-integration.md), [`skills/flow/references/attestations.md`](https://github.com/manhquydev/flow-skill/blob/master/skills/flow/references/attestations.md). Sơ đồ maintainer cần: [`docs/system-architecture.md`](https://github.com/manhquydev/flow-skill/blob/master/docs/system-architecture.md).

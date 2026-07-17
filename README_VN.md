# flow — skill "build có cổng kiểm soát" cho Claude Code

*Read this in [English](README.md).*

[![npm](https://img.shields.io/npm/v/@manhquy/flow-skill?label=npm&color=cb3837)](https://www.npmjs.com/package/@manhquy/flow-skill)
[![tests](https://img.shields.io/badge/tests-34%20suites%20%2F%20926%20checks-brightgreen)](tests/)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions%20%C2%B7%203%20OS-blue)](.github/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

`/flow` đưa một sản phẩm từ **ý tưởng đến bằng chứng "done" thật** qua các **cổng (gate) trung
thực** — một URL đã deploy cho web, "cài + chạy được" cho CLI, public API + coverage cho
library, một lần chạy thật cho skill Claude Code. **Chỉ cần chat** — trò chuyện tự nhiên là cửa
vào mặc định (concierge tự định tuyến việc bạn muốn làm tới bước kế tiếp đúng); các lệnh gõ tay
(`/flow next`, `/flow card`...) vẫn dùng được cho người quen. **Độc lập**: chỉ cần cài flow là
đủ, mọi nghi thức cổng đều có sẵn ngay trong flow — ck: và BMAD chỉ là bổ trợ tùy chọn, không
bắt buộc. Bổ sung **lớp harness bền vững** (intake / story / trace / decision / backlog), điều
phối agent đa nhà cung cấp (Claude + Codex GPT-5.x + Antigravity Gemini-3 → gate đối kháng ba mô
hình), và nhận biết loại dự án.

## Cài nhanh

```bash
npx @manhquy/flow-skill@rc
```

Cross-OS (macOS · Linux · Windows), Node ≥22.14 thuần, tương tác multi-select. Xem
[Các cách cài](#các-cách-cài) để biết flag non-interactive cho CI, dev checkout, và installer
bash / PowerShell.

## Bắt đầu nhanh — chỉ cần chat

Không cần học lệnh nào. Sau khi cài, mở session Claude Code mới trong dự án và nói thẳng điều
bạn muốn:

> "Tôi muốn build app quản lý kho cho cửa hàng."

Concierge chạy `flow.sh status` (bằng chứng cơ học, không đoán mò), hỏi đúng một câu ("để tôi
soạn nháp từng bước, anh duyệt nhé?"), rồi dẫn bạn tới cổng Scope — không cần gõ lệnh `/flow`
nào. Vẫn thích gõ lệnh tay? Vẫn hoạt động y hệt như tài liệu bên dưới; concierge không bao giờ
chen ngang một lệnh `/flow <verb>` tường minh. Xem đầy đủ luật định tuyến tại
[`references/concierge.md`](skills/flow/references/concierge.md).

## Trạng thái

| Trường | Giá trị |
|---|---|
| Phiên bản | **v0.22.0** (2026-07-16) |
| npm package | [`@manhquy/flow-skill@0.1.0-rc.1`](https://www.npmjs.com/package/@manhquy/flow-skill) — LIVE |
| Test | 34 bộ / 926 check xanh |
| CI | GitHub Actions · Ubuntu · macOS · Windows (Azure Pipelines chuyển thành fallback dự phòng) |
| License | MIT |

Release notes trong [`CHANGELOG.md`](./CHANGELOG.md); nhật ký session trong [`docs/journals/`](./docs/journals/).


## Triết lý cốt lõi
- **"Done" = bằng chứng thật ngoài đời**, không phải "tests pass" / "đã merge". Mỗi card khai báo
  done-evidence (URL bấm được, curl thật, dòng DB) TRƯỚC khi build.
- **Hai lớp**: runner bash (cơ học, exit 0/1) bắt những thứ "gian lận được" (ô gate chưa tick,
  `[FILL]`, evidence rỗng); SKILL.md (Claude) là người gác cổng ngữ nghĩa (research bịa,
  scope "dìm hạng", evidence giả). Gate qua khi **cả hai** đồng ý.
- **Kill tại gate là kết quả hợp lệ** — giết một ý tưởng yếu ở Scope là rẻ và khôn ngoan.

## Có gì trong repo

```
flow-skill/
├── skills/flow/                 # skill cài được  (-> ~/.claude/skills/flow)
│   ├── SKILL.md                 # điều phối lệnh + gác cổng ngữ nghĩa + orchestration agent
│   ├── runner/flow.sh           # engine gate (exit 0/1): status/next/assess/card/check/mode/project-type/
│   │                            #   skip/ready/workspace/auto/recall/unlock/harness/debt/design/contract/
│   │                            #   tokens/coherence/consistency/constitution/promote/doctor/usage/retro/
│   │                            #   loop-prep/loop-log (bọc ck-loop)
│   ├── _templates/              # 00-idea .. 05-contract + 00-inspect + card
│   ├── law/                     # CLAUDE.md (luật build-session), DESIGN.md (luật UI), RETRO.md
│   ├── references/              # 21 playbook ngữ nghĩa (gates, agents, loop, design, project-types,
│   │                            #   concierge, native-rituals, forge-idea)
│   ├── eval/                    # fixture behavioral-eval: artifact-vs-gate + bộ chấm định tuyến v0.22
│   ├── harness/                 # lớp bền vững: flow_harness.py + _db.py + _domain.py + schema
│   └── playbooks/               # tri thức stack "trả giá mới có" (đọc trước, đúc kết sau)
├── .claude-plugin/              # plugin.json + marketplace.json (cài kiểu plugin/marketplace)
├── install.sh / install.ps1     # cài một lệnh (toàn máy hoặc theo dự án)
├── tests/run_all.sh             # 34 bộ test / 926 check
└── docs/                        # kiến trúc + tóm tắt codebase
```

## Độc lập theo thiết kế (v0.22)

Chỉ cần cài flow là có đủ trải nghiệm **đầy đủ** — không cần bộ kit nào khác. 5 nghi thức cổng
từng dựa vào skill ngoài (tùy chọn) giờ có **nghi thức bản địa** ngay trong flow
(`references/native-rituals.md`): tranh luận đa vai trò @ ADR, phân rã edge-case @ Contract,
bảo mật STRIDE @ Review, retro có số liệu @ Retro, và giao thức lặp bản địa @ Build/Verify. Nếu
máy có sẵn `ck-predict`/`ck-scenario`/`ck-security`/`ck-loop` của claudekit hay skill `retro`
của BMAD, chúng được đề xuất như **lựa chọn phong phú hơn** — không bao giờ bắt buộc, cổng
không bao giờ phụ thuộc vào chúng. Nghi thức thứ sáu, `references/forge-idea.md`, được chuyển
thể từ `bmad-forge-idea` của BMAD-METHOD (MIT) để tra vấn/dò bền ý tưởng ở giai đoạn Idea/Scope
trước khi chốt.

---

# Cài đặt

`/flow` là một **skill portable** — một thư mục có `SKILL.md` mà cùng định dạng chạy được trên
Claude Code **và** Codex CLI (và các agent đọc SKILL.md khác). Cài một lần, installer tự đặt vào
mọi harness bạn có:

| Harness | Thư mục cài | Gọi bằng |
|---|---|---|
| **Claude Code** | `~/.claude/skills/flow/` (hoặc `<project>/.claude/skills/flow/`) | `/flow` |
| **Codex CLI** | `~/.codex/skills/flow/` | `$flow` |
| **Agents / claudekit** | `~/.agents/skills/flow/` | tùy host |
| **Antigravity** | `~/.gemini/antigravity-cli/skills/flow/` (CLI) · `~/.gemini/config/skills/flow/` (IDE) | tự khớp (`agy inspect`) |

Chạy như nhau trên **macOS, Linux (Ubuntu), Windows**.

## Yêu cầu

| Công cụ | Bắt buộc? | Để làm gì | macOS | Ubuntu | Windows |
|---|---|---|---|---|---|
| **bash** | **Bắt buộc** | engine gate là script bash | có sẵn (3.2) | có sẵn | Git Bash (Git for Windows) |
| **python3** | Khuyến nghị | lớp harness bền vững (sqlite3) | `brew install python` | `sudo apt install python3` | python.org / winget |
| **git** | Tuỳ chọn | build song song bằng worktree + `/flow auto` | có sẵn / Xcode CLT | `sudo apt install git` | Git for Windows |
| **cargo** | Tuỳ chọn | chỉ cho power-path harness Rust | — | — | — |

> Không có python thì **engine gate vẫn chạy đầy đủ**; chỉ lớp ghi durable tự tắt. `sqlite3` nằm
> sẵn trong thư viện chuẩn của python trên cả ba HĐH — không cần cài riêng. bash 3.2 mặc định của
> macOS dùng tốt (`/flow` tránh tính năng bash-4).

## Cài theo nền tảng

### macOS
```bash
brew install python            # hoặc: xcode-select --install
cd /path/to/flow-skill
bash install.sh global         # -> ~/.claude/skills/flow
bash ~/.claude/skills/flow/runner/flow.sh doctor
```
Lưu ý: `grep` BSD trên macOS không có `-P`, nên phần kiểm emoji của `flow design` tự bỏ qua êm
(mọi thứ khác vẫn chạy).

### Linux (Ubuntu / Debian)
```bash
sudo apt update && sudo apt install -y bash python3 git
cd /path/to/flow-skill
bash install.sh global
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

### Windows
Cần **Git for Windows** (cung cấp Git Bash). Cài python từ python.org (tick "Add to PATH") hoặc
`winget install Python.Python.3.12` — tránh bản Microsoft Store stub.
```powershell
cd C:\path\to\flow-skill
pwsh .\install.ps1 global       # -> %USERPROFILE%\.claude\skills\flow  (PowerShell 7+)
```
```bash
# hoặc từ Git Bash:
cd /c/path/to/flow-skill
bash install.sh global
bash ~/.claude/skills/flow/runner/flow.sh doctor
```

## Các cách cài

**A. npm — một lệnh, cross-OS** (khuyến nghị, đã LIVE trên [@manhquy/flow-skill](https://www.npmjs.com/package/@manhquy/flow-skill)):
```bash
npx @manhquy/flow-skill@rc                # kênh pre-release (hiện tại: 0.1.0-rc.2)
# Sau khi stable publish: npx @manhquy/flow-skill@0.1.x
```
Pure Node (>= 22.14.0), tương tác multi-select 5 target (Claude Code, Codex CLI, Agents home —
cũng là thư mục Agent-Skills chung mà các tool tuân chuẩn khác như Cursor đọc — Antigravity
CLI + IDE, Cursor), chạy giống nhau trên macOS + Linux + Windows.
Non-interactive cho CI:
```bash
npx @manhquy/flow-skill@rc --yes                    # cài vào target được detect + Claude
npx @manhquy/flow-skill@rc --yes -t claude -t codex # target rõ ràng
npx @manhquy/flow-skill@rc --yes --all              # ép cả 5 target
npx @manhquy/flow-skill@rc --yes --all --dry-run --json  # preview JSONL cho CI
```
Xem [npm-wrapper/README.md](./npm-wrapper/README.md) để biết đầy đủ flag, hợp đồng JSONL và troubleshooting.

> **Dev checkout** (chỉ dành cho contributor): `git clone https://github.com/manhquydev/flow-skill && cd flow-skill/npm-wrapper && npm install && npm run sync && npm link` rồi `flow-skill --help`.

**B. Script cài (dùng cho dev/repo checkout)** — cài vào **mọi harness đang có** + chạy doctor:
```bash
bash install.sh global            # ~/.claude/skills/flow (luôn) + ~/.codex/skills/flow
                                  #   + ~/.agents/skills/flow  (chỉ thêm nếu harness đó tồn tại)
bash install.sh global codex      # target 1 harness: claude | codex | agents
bash install.sh project [dir]     # <dir>/.claude/skills/flow (một dự án, commit được)
# Windows PowerShell: pwsh install.ps1 global | pwsh install.ps1 global codex | pwsh install.ps1 project [dir]
```
Repo là single source of truth — **chạy lại installer sau mỗi lần update** để đồng bộ mọi
harness (không lệch giữa bản Claude Code và Codex).

> **Windows:** dùng **`pwsh install.ps1 global`**, đừng dùng `bash install.sh` — trong PowerShell
> `bash` trần có thể là **WSL**, sẽ cài vào filesystem WSL (`/home/...`) thay vì home Windows.
> Chỉ chạy `bash install.sh` từ **Git Bash**.

**C. Plugin / marketplace** (chia sẻ giữa nhiều máy / cả team):
```
/plugin marketplace add <path-hoặc-git-url-tới-flow-skill>
/plugin install flow@flow-marketplace
```
**C. Thủ công** — copy `skills/flow/` vào `~/.claude/skills/flow/` và `chmod +x` runner trên macOS/Linux.

## Kích hoạt & kiểm tra
- **Claude Code:** thư mục skill **mới** cần khởi động lại Claude Code một lần để nó theo dõi; sửa
  skill đang theo dõi thì áp dụng ngay trong phiên. Gõ **`/flow`**.
- **Codex CLI:** Codex nạp danh mục skill **lúc khởi động**, nên **thoát hẳn rồi mở lại Codex** sau
  khi cài, rồi gõ **`$flow`** (hoặc `/skills` để xác nhận có `flow`). Codex gọi skill bằng tiền tố
  `$` — `$flow`, `$flow next`, `$flow assess` — không phải `/flow`.
- Kiểm môi trường bất kỳ lúc nào: `bash ~/.claude/skills/flow/runner/flow.sh doctor`.
- **Gọi runner thủ công trên Windows (PowerShell/cmd/Codex):** dùng launcher, KHÔNG dùng `bash`
  trần — `~/.codex/skills/flow/runner/flow.cmd doctor`. Trong PowerShell, `bash` trần thường là
  WSL, không đọc được path `C:/` → báo "No such file or directory"; `flow.cmd` tự tìm Git Bash.
  (Trong Bash tool của Claude Code thì `bash …/flow.sh` vẫn OK vì đó là Git Bash.)

## Khắc phục sự cố
| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| `\r: command not found` / `bad interpreter` | line-ending CRLF (clone trên Windows) | repo ép LF qua `.gitattributes`; clone lại, hoặc `sed -i 's/\r$//' runner/flow.sh` |
| `/flow` không hiện | thư mục skill mới chưa được theo dõi | khởi động lại Claude Code một lần sau khi cài lần đầu |
| `durable layer DISABLED` trong doctor | không tìm thấy python | cài python3 (xem theo nền tảng) hoặc bỏ qua — engine vẫn chạy |
| `flow design` không thấy emoji trên macOS | grep BSD không có `-P` | bình thường; phần còn lại của design check vẫn chạy |
| PowerShell lỗi parse `??` | PowerShell 5.1 | dùng `pwsh` (PowerShell 7+) hoặc `install.sh` trong Git Bash |

---

## Bắt đầu nhanh (`/flow ...`)
```
/flow                  đang ở đâu, cái gì đang chặn, tóm tắt bộ nhớ
/flow assess           brownfield: tạo + gate bản đánh giá hiện trạng của repo có sẵn
/flow project-type cli chọn bạn đang build gì (web|cli|library|skill) -> đổi định nghĩa "done"
/flow next             kiểm gate stage hiện tại, mở stage kế (hoặc liệt kê cái còn thiếu)
/flow recall           đọc lại tri thức trước (debt/retro/card-trước/friction/playbooks) TRƯỚC khi làm
/flow card             tạo build card (sau khi mọi gate planning đã qua)
/flow check C-001      kiểm card (done = bằng chứng thật, không phải "tests pass")
/flow auto             chạy build tự động (Tier-A auto-merge xanh, HALT ở nhóm bảo mật)
/flow loop-prep C-001  lặp-tới-mục-tiêu-số: worktree + Verify/Guard cho skill ck-loop
/flow contract|tokens|coherence|consistency   drift/coverage checks (path-resolution · design token · version · map FR liên-artifact)
/flow doctor           kiểm môi trường trên macOS/Linux/Windows
```

## Lệnh (đầy đủ)

"Bắt đầu nhanh" ở trên là đường đi thường gặp; đây là tham chiếu đầy đủ — cả 28 lệnh engine dispatch (`bash skills/flow/runner/flow.sh <command>`):

| Lệnh | Làm gì |
|---|---|
| `/flow resume` | **Bản tóm tắt câu chuyện phiên, chỉ đọc, để vào lại một dự án giữa chừng**: phiên trước (chỉ tên lệnh, không bao giờ in raw args), card đang làm + dwell, trạng thái gate, một dòng `NEXT ->`. Chạy lệnh này ĐẦU TIÊN khi nhặt lại một dự án đã có mà quên hết ngữ cảnh. |
| `/flow` *(status)* | Đang ở đâu? Cái gì đang chặn? Một dòng `NEXT ->` (dùng chung helper với `resume`), dwell ở stage hiện tại, danh sách card (tóm gọn khi quá 10 card) + một dòng tóm tắt bộ nhớ |
| `/flow next` | Kiểm gate hiện tại; nếu qua, mở stage kế (hoặc bắt đầu ở 00) |
| `/flow assess` | Brownfield: tạo + gate bản đánh giá hiện trạng (`flow/00-inspect.md`) trước khi plan |
| `/flow card` | Tạo build card kế tiếp (sau khi mọi gate planning đã qua) |
| `/flow card start\|done C-NNN` | Tùy chọn: đánh dấu card "in flight" / flip `done` do CLI sở hữu (gate như `check`, revert nếu fail). Song song với sửa tay. |
| `/flow check C-NNN` | Kiểm một card (FILL/status/sections/done-evidence) |
| `/flow mode [teach\|work]` | Xem/đặt ai viết artifact ở gate |
| `/flow project-type [t]` | Xem/đặt loại dự án (`web\|cli\|library\|skill`); đổi done-evidence |
| `/flow skip <stage> --reason` | Vượt qua một gate có DEBT đang mở khớp (không áp dụng cho nhóm bảo mật) |
| `/flow ready` | Liệt kê card todo build được + gợi ý an-toàn-song-song |
| `/flow workspace add\|list\|enter\|remove\|check\|doctor` | **Cô lập đa-agent bằng worktree** — mỗi agent một `git worktree` để nhiều agent (Claude/Codex/Antigravity, nhiều terminal) chạy song song mà không "một con đổi nhánh → tất cả đổi theo". `add` tạo worktree + port-offset riêng + khối cd/env dán-là-chạy; `list` xem ai-ở-đâu; `check` cảnh báo trùng nhánh/allowed-files trước khi chạy; `remove`/`doctor` dọn + đối soát an toàn. git là registry; side-file `.flow/workspaces.jsonl` giữ vendor/card/port/task |
| `/flow auto` | Preflight một lần chạy tự động (điều phối nằm trong SKILL.md) |
| `/flow loop-prep <card> [--metric][--iterations][--guard]` | Plumbing cho skill `ck-loop` — worktree cô lập + lệnh Verify dạng số suy ra từ Allowed files của card + tự kiểm precondition Phase-0. ck-loop vẫn là engine iterate nguyên bản. |
| `/flow loop-log <card> --iterations N --start M --end K --outcome converged\|circuit-broke\|no-improve` | Ghi một lần chạy ck-loop đã xong vào usage-log telemetry (exit code 0/1/2) |
| `/flow recall` | Đọc lại tri thức trước (debt/retro/card-trước/friction/playbooks) trước khi làm |
| `/flow unlock` | Xoá khoá concurrency của dự án này (sau session crash/bỏ dở) |
| `/flow harness <args>` | Chuyển tiếp xuống CLI lớp bền vững (intake/story/trace/decision/backlog/query/audit/propose) |
| `/flow debt add\|list` | Ghi/liệt kê các skip gate có chủ đích trong `DEBT.md` (nhóm bảo mật = chỉ operator) |
| `/flow design <file>` | Kiểm `DESIGN.md` cơ học trên file UI (emoji/`{{}}`/từ-engine/gradient) |
| `/flow contract` | Lệch base-URL client vs prefix path server (path-resolution; web) |
| `/flow tokens` | Token khai báo trong `DESIGN.md` vs CSS thực dùng (lệch design-system) |
| `/flow coherence` | Lệch version giữa các trường version khai báo (doc-vs-code) |
| `/flow consistency` | Phủ liên-artifact: mỗi `FRn` trong PRD phải được một card `implements:` và một interface trong contract phục vụ; success metric có số; quét placeholder (cố vấn) |
| `/flow constitution` | Kiểm các bất biến per-dự-án operator tự viết trong `flow/constitution.md` (cấu trúc + grep-marker; cố vấn, **không** phải gate của `next`) |
| `/flow eval [--stage 01\|02\|card] [--fixture <id>] [--n 3]` | **Bằng chứng hành vi cho gate ngữ nghĩa**: LLM có thật sự phát hiện fixture rỗng-nhưng-pass-cơ-học không? Opt-in, **tính phí**, skip sạch 0 lệnh gọi nếu thiếu CLI `claude`. Xem `references/gate-eval.md` (ngưỡng dưới của fresh judge, không phải self-challenge ở work-mode). |
| `/flow eval --report` | Offline, 0 lệnh gọi: scorecard batch hoàn chỉnh gần nhất + drift so với batch hoàn chỉnh trước đó |
| `/flow promote <file>` | Copy một playbook vào KB liên-dự-án (`~/.claude/flow/playbooks`) |
| `/flow doctor` | Kiểm môi trường (bash/python/grep/git) trên macOS/Linux/Windows |
| `/flow usage [--global\|--prune]` | Tổng hợp usage-log JSONL thành analytics build: cycle-time, tỷ lệ fail gate, dwell theo stage + theo card, phân bố lệnh (chỉ lưu cục bộ) |
| `/flow retro` | In 3 câu hỏi retro |

## Các chế độ (Modes)

`/flow` có **4 trục chế độ độc lập** — đặt theo từng dự án, phối hợp tự do:

**1. Chế độ soạn thảo** — *ai viết artifact ở gate* (file `MODE`; mặc định `teach`)
- `teach` — **bạn** tự viết mỗi artifact; AI chỉ gác cổng (bắt nội dung rỗng/bịa).
- `work` — AI phỏng vấn bạn một lần, tự soạn stage 00–05, chỉ dừng ở bước duyệt scope, rồi giao
  bộ card. Gate ràng buộc như nhau ở cả hai.
- đặt: `/flow mode teach|work`

**2. Loại dự án** — *"done" nghĩa là gì* (file `PROJECT_TYPE`; mặc định `web`)

| Loại | done-evidence |
|---|---|
| `web` | URL đã deploy bấm được + output curl thật |
| `cli` | cài được + một lần gọi thật trả đúng output + exit code |
| `library` | import được public API + ví dụ dùng chạy được + đạt ngưỡng coverage |
| `skill` | cài vào `~/.claude/skills` + một lần chạy thật đạt done-definition của chính nó |

- đặt: `/flow project-type web|cli|library|skill` — đổi contract seam, trình tự card, và luật "done".

**3. Chế độ chạy** — *card được build thế nào*
- **thủ công** (mặc định) — bạn lái: `/flow card` → build → `/flow check`.
- **auto** — `/flow auto`: chạy tự động. **Tier-A** (xanh) auto-merge; **Tier-B** (sửa được) cho
  một subagent mới sửa một lần (hai-lần-là-dừng); **Tier-C nhóm bảo mật** (auth, tenancy, payment,
  data migration) **HALT** chờ chấp nhận rủi ro bằng văn bản trong `DEBT.md`.

**4. Greenfield vs brownfield** — *dự án mới vs có sẵn*
- **greenfield** (mặc định) — bắt đầu ở `/flow next` (stage 00-idea).
- **brownfield** — chạy `/flow assess` trước → bản đồ hiện trạng có gate `flow/00-inspect.md`
  (stack, chức năng / UI-UX so với mục tiêu sản phẩm, rủi ro, baseline test) trước khi plan. Có người duyệt.

> **Đồng thời (concurrency):** một session cho mỗi dự án. `flow/.lock` từ chối session thứ hai chạy
> song song (export `FLOW_SESSION_ID` ổn định để bảo vệ cứng); `/flow unlock` xoá khoá cũ.

## Vòng tri thức & drift checks

Lớp harness bền vững (`.flow/harness.db` + `RETRO.md`/`DEBT.md`/`playbooks/`) là **vòng khép kín
capture → reuse → improve** — agent tích luỹ và tái dùng kinh nghiệm như một đội ngũ người thật:

- **Capture (engine tự ghi):** `/flow next` qua stage 01 seed một `intake`; `/flow check` (done)
  ghi một `trace` được chấm tier; `/flow debt` ghi các skip có chủ đích.
- **Reuse:** `/flow recall` đọc lại tất cả — debt đang mở, retro gần đây, Scope của card trước,
  friction/backlog của harness, điểm sức khoẻ audit, và playbooks — để bắt đầu stage/card với "nỗi
  đau cũ" trong tầm mắt. `/flow status` hiện một dòng tóm tắt bộ nhớ.
- **Improve:** `/flow harness audit` chấm điểm entropy/drift; `/flow harness propose [--commit]` gom
  friction/intervention lặp lại thành backlog cải tiến (xác định, kích hoạt khi ≥2);
  `/flow harness decision outcome` đóng vòng dự-đoán-vs-thực-tế; `/flow retro` nêu các đề xuất.
- **Liên-dự-án:** `/flow promote <playbook.md>` copy một bài học khó-kiếm vào
  `~/.claude/flow/playbooks` để `recall` hiện nó ở **mọi** dự án, không chỉ dự án này.

**Drift checks (chỉ cảnh báo — gắn cờ, không tự sửa):**
- `/flow contract` — lệch base-URL client vs **prefix** path phía server (lớp double-`/api`,
  mixed-prefix mà oasdiff/Pact/Spectral bỏ sót).
- `/flow tokens` — token khai báo trong DESIGN.md vs CSS thực dùng (chưa-dùng + **lệch giá trị** + orphan).
- `/flow coherence` — lệch version giữa các trường version khai báo (lát cắt doc-vs-code rẻ).
- `/flow consistency` — phủ liên-artifact: mỗi `FRn` trong PRD được một card claim và một interface
  phục vụ, success metric có số, không còn placeholder (xương sống truy vết, được cơ-giới-hoá). Trục
  còn thiếu của lattice drift: coherence=version, contract=URL, tokens=design, consistency=các artifact
  có truy vết tới nhau không.

## Codex — engine thứ hai khác hãng (v0.4+)

Thang agent của `/flow` là **ck: → bmad-\* → built-in**. v0.4 thêm tầng thứ 4 **khác hãng**:
OpenAI **Codex (GPT-5.x)** qua plugin `openai-codex` của Claude Code. Đây là *engine thứ hai* —
một model thực sự khác, dùng ở vài thời điểm mà điều đó đáng giá hơn một lượt Claude nữa — **không
thay thế** và **không bắt buộc**.

**Vì sao cần hãng thứ hai.** Harness một-hãng khiến người-viết và người-review dùng chung một model,
nên các điểm-mù tương quan lọt qua gate xanh. Một engine khác là cách rẻ nhất để bịt khe hở cùng-hãng
mà không làm yếu gate nào. Trong chính lần dogfood của dự án, một review cross-model bằng Codex bắt
được **2 lỗi thật** (lỗ hổng detect installed-vs-usable + một cost-gate sai) mà các lượt cùng-model
đã bỏ sót — xem `docs/quality-metrics.md`.

**Detect-and-degrade (vắng mặt không bao giờ làm hỏng run).** Hai trạng thái:
- **INSTALLED** — `codex:codex-rescue` có trong registry *hoặc* thư mục plugin tồn tại. Cần, chưa đủ.
- **USABLE** — INSTALLED **và** một probe rẻ, không tính phí pass: `codex-companion.mjs setup --json`
  báo `ready` + `auth.loggedIn`. (`setup --json`, **không phải** `status` — `status` không có trường auth.)

`/flow` chỉ route sang Codex khi **USABLE**; nếu không sẽ degrade lặng-mà-có-báo về `ck:→bmad→built-in`
và ghi lại lý do. Codex vắng mặt không bao giờ gây lỗi cứng.

**Cost gate — đúng 3 trigger** (Codex tính phí GPT-5.x; engine mặc định vẫn là ck:):
1. **two-strikes deadlock** — một agent cùng-model BLOCKED hai lần (Tier-B repair bằng engine mới),
2. **review card lớp bảo mật** (auth / tenancy / payments / data-migration),
3. **operator opt-in tường minh** — vd *"draft stage này bằng Codex"*, hoặc chọn làm drafter chính.

**Gate parity tuyệt đối.** Codex DRAFT hoặc CRITIQUE; gate gốc (`flow.sh` + `gate-rules.md`) vẫn là
người phán xử. Review cross-model **chỉ hỗ trợ triage — không bao giờ tự pass/fail** một card.

**Ranh giới tin cậy (đọc trước khi bật trên code nhạy cảm).**
- *Auth* giao hoàn toàn cho plugin (`codex login` / `OPENAI_API_KEY` / ChatGPT sub). `/flow` không
  bao giờ đọc, lưu, hay log credential Codex.
- *Dữ liệu* — chọn Codex sẽ **gửi** ScopedBrief (diff + trích contract/PRD/law) tới API của OpenAI
  theo điều khoản retention/training của gói OpenAI của bạn. Dù xử lý secret hoàn hảo, *code và spec*
  vẫn rời máy. Với codebase chịu quản lý / NDA, hãy opt-in một cách hiểu biết; cost gate giữ bề mặt
  phơi nhiễm mặc định ở mức nhỏ.

Engine nào chạy luôn được thông báo, vd `review via Codex cross-model lens (needs-attention, 2 findings)`.
Spec đầy đủ: `skills/flow/references/codex-integration.md`.

## Demo — minh hoạ thật (chạy trên bản đã cài)

Đây là transcript thật từ việc lái `/flow` đã cài (xem `e2e-drive.sh` kiểu `tests/`).

### Demo 1 — build web app (happy path: đi qua gate → card → done)
```
$ /flow next                         # mở stage 00 (idea); điền, tick ô gate
$ /flow next   (x6, điền dần)         # Research → Scope → PRD → ADR → Contract
PASS: stage 05-contract gate clean. Planning is COMPLETE.
$ /flow card                         # -> cards/C-001.md
$ /flow check C-001                  # sau khi build + dán evidence thật
PASS: C-001 is valid (status: done).
```

### Demo 2 — build CLI / skill (done-evidence tự đổi, không cần URL)
```
$ /flow project-type cli
$ /flow project-type
project type: cli (default web)
  done-evidence for 'cli': the tool installs and a real invocation returns the expected output + exit code
```

### Demo 3 — gate chặn bạn một cách trung thực (và KILL là kết quả hợp lệ)
```
$ /flow next                         # chưa điền gì
FAIL: gate for stage 00-idea is not clean.
  [x] unchecked gate boxes:
      L4:- [ ] The pitch below is 3 sentences, no more
  [x] unfilled [FILL] placeholders:
      L10:[FILL: sentence 1 — who has the problem]
Fix the above, then run '/flow next' again. (Kill at a gate is also valid.)
```

### Demo 4 — "done" phải là bằng chứng thế-giới-thật, không phải "tests pass"
```
$ /flow check C-001                  # status: done, nhưng Evidence vẫn "(empty until done)"
  [x] status is 'done' but ## Evidence is empty (paste world-state proof: URL/curl/DB row)
FAIL: C-001 has gate violations (above).
```

### Demo 5 — skip hợp lệ một gate không phù hợp (debt + skip)
```
$ /flow debt add "skip 01-research" "internal tool, no public market" "before public release"
$ /flow skip 01-research --reason "internal tool, no public market"
PASS: stage 01-research debt-skipped (logged) -> 02-scope available. planning_complete now tolerates it.
# (contract stage 05 KHÔNG BAO GIỜ skip được; lý do thuộc nhóm bảo mật sẽ HALT)
```

### Demo 6 — harness bền vững + design check
```
$ /flow harness intake --type change_request --summary "add login" --flags auth
PASS: intake #1 -> lane=high_risk          # auth là hard gate -> tự nâng cấp
$ /flow design page.html                    # kiểm UI tĩnh trước một card frontend
  [x] emoji / smart arrows (DESIGN.md: never): L1:<h1>My Workshop 🎉</h1>
  [x] raw {{ }} template outside a power surface: L2:<p>Welcome {{ user.name }}</p>
```

> Đã kiểm chứng: một e2e happy/edge đầy đủ (22 check) chạy xanh trên một bản cài per-project mới
> trên Windows/Git Bash; bộ test dev là 34 bộ (`bash tests/run_all.sh`).

## Các loại dự án
`/flow project-type <web|cli|library|skill>` đổi Contract seam, trình tự card, và **"done" nghĩa là
gì** theo loại (web: URL live; cli: cài + chạy + exit code; library: public API + coverage; skill:
cài + chạy thật). Xem `skills/flow/references/project-types.md`.

## Cách hoạt động (hai lớp)
- **`runner/flow.sh`** — engine gate xác định: bắt những thứ gian lận được (ô chưa tick, `[FILL]`,
  evidence rỗng), exit 0/1.
- **`SKILL.md`** (Claude) — người gác cổng ngữ nghĩa: bắt cái script không bắt được (research bịa,
  scope dìm hạng, evidence "thế giới thật" vs "tests pass").
Gate qua chỉ khi **cả hai** đồng ý. Lớp `harness/` là bộ nhớ ngoài sống qua nhiều session.

## Chạy test
```bash
bash tests/run_all.sh    # 34 bộ test / 926 check; cần bash (+ python cho bộ harness/propose)
```

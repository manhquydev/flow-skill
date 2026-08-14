# flow — harness build có cổng cho coding agent

*English: [README.md](README.md).*

[![npm](https://img.shields.io/npm/v/@manhquy/flow-skill?label=npm&color=cb3837)](https://www.npmjs.com/package/@manhquy/flow-skill)
[![tests](https://img.shields.io/badge/tests-48%20suites-brightgreen)](tests/)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions%20%C2%B7%203%20OS-blue)](.github/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

`/flow` đưa sản phẩm từ **ý tưởng → bằng chứng done thật** qua các cổng trung thực (URL deploy,
CLI cài-chạy, library API, hoặc skill chạy thật). Chat là cửa mặc định; lệnh gõ
(`/flow next`, …) vẫn dùng được. **Độc lập** — không bắt buộc AgentKit/claudekit. Review
đa model (Claude · Codex · Antigravity) khi có.

| | |
|---|---|
| **Skill product** | **v0.28.1** |
| **npm installer** | [`@manhquy/flow-skill`](https://www.npmjs.com/package/@manhquy/flow-skill) **0.5.x** (ship skill ở trên) |
| **Test / CI** | 48 suite · Ubuntu · macOS · Windows |
| **License** | MIT |

**Website:** [flowskill.io.vn](https://flowskill.io.vn) (Cloudflare Pages). Không dùng hostname preview `*.pages.dev` làm site công khai.

---

## Cài đặt (khuyến nghị)

**Yêu cầu:** [Node.js](https://nodejs.org/) **≥ 22.14**.

### Lệnh chuẩn (copy nguyên)

```bash
# Luôn dùng @latest để npx lấy bản mới (tên package trần có thể trúng cache cũ).
npx @manhquy/flow-skill@latest
```

Diễn biến:

1. Tải installer GA hiện tại từ npm (dist-tag `latest`).
2. Hỏi tương tác các agent detect được trên máy.
3. Copy skill vào từng home (vd. `~/.claude/skills/flow`).

Sau đó **restart/reload agent** và gọi:

| Agent | Sau khi cài |
|--------|-------------|
| Claude Code | gõ `/flow` |
| Codex CLI | restart một lần, gõ `$flow` |
| Cursor / Agents home | reload tool, mở skill flow |
| Antigravity | restart IDE/`agy`, rồi `/flow` |

### Biến thể thường dùng

```bash
# Không prompt: Claude + agent đã detect
npx @manhquy/flow-skill@latest --yes

# Chỉ định agent
npx @manhquy/flow-skill@latest --yes --target claude
npx @manhquy/flow-skill@latest --yes -t claude -t codex

# Cả 5 target (claude, codex, agents, antigravity, cursor)
npx @manhquy/flow-skill@latest --yes --all

# Skill trong repo (Claude project scope)
npx @manhquy/flow-skill@latest --yes --project --dir .

# Xem kế hoạch, không ghi đĩa (CI)
npx @manhquy/flow-skill@latest --yes --all --dry-run --json

# Xác nhận phiên bản installer + skill trong tarball
npx @manhquy/flow-skill@latest --help
# expect: flow-skill v0.5.x (ships skill v0.28.x)
```

### Kiểm tra sau cài

```bash
npx @manhquy/flow-skill@latest --help

grep -E '^\s*version:' ~/.claude/skills/flow/SKILL.md | head -1
# expect: version: "0.28.1"  (hoặc skill product hiện tại)

bash ~/.claude/skills/flow/runner/flow.sh doctor
# expect: READY
```

### Quy tắc

| Nên | Không |
|-----|--------|
| **`@latest`** mỗi lần muốn bản mới | Bare `npx @manhquy/flow-skill` (cache npx) |
| **Chạy** CLI để skill vào agent home | Chỉ `npm i` — không copy skill |
| Pin installer `@0.5.1` nếu cần cố định | Pin npm `@0.28.1` (đó là version **skill**, không phải package) |
| `@latest` / `@0.5.x` | `@rc` (đã retire / cũ) |

**Hai số version (cố ý):** package npm = installer CLI; skill product = `SKILL.md` metadata.
`--help` in cả hai: `flow-skill v0.5.1 (ships skill v0.28.1)`.

Chi tiết flag: [npm-wrapper/README_VN.md](./npm-wrapper/README_VN.md).

---

## Bắt đầu nhanh

Sau cài, mở session agent **mới** trong project:

> "Tôi muốn build app quản lý kho cho cửa hàng."

Concierge đọc `flow.sh status` (ground truth cơ học), hỏi một câu đồng ý, rồi dẫn tới cổng
tiếp. Lệnh `/flow …` tường minh luôn thắng chat. Chi tiết:
[`skills/flow/references/concierge.md`](skills/flow/references/concierge.md).

**Ý chính:** done = bằng chứng thế giới thật; cổng cơ học + cổng ngữ nghĩa phải cùng pass;
kill tại gate là hợp lệ.

Release: [`CHANGELOG.md`](./CHANGELOG.md) · quy trình: [`docs/release-process.md`](./docs/release-process.md).


## Cài vào đâu

| Agent | Path | Gọi |
|-------|------|-----|
| Claude Code | `~/.claude/skills/flow` (hoặc project `.claude/skills/flow`) | `/flow` |
| Codex CLI | `~/.codex/skills/flow` | `$flow` (restart Codex sau cài) |
| Agents home | `~/.agents/skills/flow` | theo host |
| Antigravity | `~/.gemini/antigravity-cli/skills/flow` + `~/.gemini/config/skills/flow` | `/flow` sau reload |
| Cursor | `~/.cursor/skills/flow` | panel agent skills sau reload |

**Phụ thuộc runtime skill (sau cài):** bash (Git Bash trên Windows), python3 khuyến nghị cho harness durable, git tùy chọn cho worktree/`auto`. Không có python thì cổng vẫn chạy; lớp SQLite tắt.

---

## Cách cài khác

Ưu tiên **npm** ở trên. Thêm cho contributor / offline:

```bash
# Từ git checkout — script cài (đồng bộ agent homes + doctor)
bash install.sh global                 # hoặc: pwsh install.ps1 global  (Windows)
bash install.sh project [dir]          # skill Claude theo project

# Plugin / marketplace (Claude Code)
/plugin marketplace add <path-hoặc-url-tới-repo-này>
/plugin install flow@flow-marketplace

# Thủ công: copy skills/flow/ → ~/.claude/skills/flow/ và chmod +x runner/flow.sh
```

Trên Windows, ưu tiên `pwsh install.ps1` hoặc đường npm. Trong PowerShell, `bash` trần có thể là WSL (filesystem sai); dùng `runner/flow.cmd` khi gọi runner ngoài Git Bash của Claude.

**Chỉ dev:** `git clone … && cd npm-wrapper && npm i && npm run sync && npm link`.

---

## Khắc phục sự cố

| Hiện tượng | Cách xử lý |
|------------|------------|
| Không có `/flow` sau `npm i` | Chạy `npx @manhquy/flow-skill@latest` (phải **execute** CLI) |
| Skill cũ sau “cài lại” | Luôn `@latest`; tránh bare package name |
| Claude / Codex không list skill | Restart agent **một lần** sau cài lần đầu |
| `flow.sh: No such file` trên PowerShell | Dùng `…/runner/flow.cmd` (không dùng WSL `bash`) |
| `durable layer DISABLED` | Cài python3, hoặc bỏ qua (cổng cơ học vẫn chạy) |
| CRLF / bad interpreter | Repo ép LF qua `.gitattributes`; clone lại nếu cần |

---

## Lệnh hằng ngày

```
/flow            status — đang ở đâu, cái gì chặn
/flow next       kiểm gate + mở stage kế
/flow assess     đánh giá brownfield
/flow card       tạo build card
/flow check C-001  validate card (done = bằng chứng thế giới thật)
/flow auto       build tự động (HALT nhóm bảo mật)
/flow doctor     kiểm môi trường
```

Codex dùng `$flow` thay `/flow`. Đầy đủ: [`skills/flow/SKILL.md`](skills/flow/SKILL.md).

## Tham chiếu lệnh

Engine dispatch (`bash …/runner/flow.sh <command>`):

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

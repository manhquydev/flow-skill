# Brainstorm: hướng phát triển tiếp theo cho flow

**Ngày:** 2026-08-11
**Trạng thái:** Đề xuất để operator duyệt
**Phạm vi:** Chọn hướng sản phẩm kế tiếp; không implement
**Baseline:** flow skill v0.27.0, npm installer v0.4.1, 48 test suites green

## Kết luận ngắn

Nên chọn **Attested Execution — biến trust policy thành control-plane enforcement** làm
hướng phát triển kế tiếp.

Flow hiện đã có planning gates, durable harness, worktrees, auto tiers, multi-model review,
eval và CI đa nền tảng. Khoảng trống có giá trị cao nhất không phải thêm agent, model, MCP
server hay stage mới. Khoảng trống là một số transition quan trọng vẫn dựa vào agent nhớ và
làm đúng policy:

- mechanical gate có thể advance trước khi semantic review được persist;
- auto Tier-C halt chỉ nằm trong hướng dẫn, chưa phải preflight bắt buộc;
- done evidence vẫn là text có thể tạo decoy hợp lệ;
- durable verification có đường chạy arbitrary shell và nhiều write path chưa được redaction;
- AI review tạo finding nhưng chưa có receipt gắn với đúng artifact/diff đã review.

Primitive nên thêm là **hash-bound attestation receipt**: bằng chứng có cấu trúc, gắn với
đúng artifact/diff/commit, actor/model, loại gate, command/probe và kết quả. State transition
chỉ dùng receipt còn hiệu lực; sửa artifact làm receipt cũ stale.

## Brainstorm contract

### Outcome

Flow trở thành portable trust control plane cho AI coding agents: Claude, Codex, Gemini,
IDE agent, CLI agent hay CI đều có thể draft/review khác nhau, nhưng transition quan trọng
chỉ xảy ra khi có attestation phù hợp với artifact hiện tại.

### Constraints

- Standalone; không hard-depend AgentKit, MCP server, model vendor hay cloud service.
- Bash là mechanical floor; Python/SQLite tiếp tục optional và graceful-degrade.
- Giữ project types, teach/work, manual/auto và worktree contracts hiện hữu.
- Reviewer/model chỉ informs; mechanical state machine quyết theo receipt contract.
- Tier-C vẫn cần operator authority; model không tự chấp nhận security exposure.
- Không làm giảm tính portable trên Linux, macOS và Windows Git Bash/PowerShell launcher.
- YAGNI, KISS, DRY: một attestation primitive dùng lại cho semantic gate, risk và verify.

### Non-goals

- Xây coding agent/IDE mới.
- Xây MCP gateway/marketplace hoặc tự quản OAuth của MCP ecosystem.
- Tích hợp mọi model mới hay thêm reviewer thứ tư.
- Full token billing platform hoặc tự đoán giá vendor.
- Vector memory, full trajectory warehouse, CrewAI-style persona fan-out.
- Clone Spec Kit/OpenSpec hoặc đổi artifact model 00–05.
- Bật graph executor mặc định trong cùng release.

### Acceptance criteria

1. Một hướng chính được chọn, tối đa ba hướng được so sánh.
2. Hướng chọn giải quyết gap đã kiểm chứng trong source, không dựa vào trend/FOMO.
3. Có vertical slice đủ nhỏ để chuyển thẳng sang `ak:plan`.
4. Có success metrics executable/observable.
5. Có roadmap sau release để context/MCP/CI trend vẫn được hấp thụ đúng thứ tự.

## Bằng chứng đã xác nhận

### Repo hiện tại

1. `SKILL.md` nói gate chỉ pass khi mechanical và semantic cùng đồng ý, nhưng `cmd_next`
   scan mechanical rồi scaffold successor ngay. Semantic review diễn ra sau command.
2. Card template chưa có persisted `risk` metadata; `cmd_auto` chỉ kiểm planning complete
   và có card. Tier-C classification/halt nằm trong `auto-run.md`.
3. Done evidence đã có multi-signal floor, nhưng tài liệu chủ động thừa nhận decoy URL +
   positive token vẫn có thể mechanical PASS.
4. Eval chỉ bao phủ Research, Scope và card; PRD/ADR/Contract chưa có behavioral fixtures.
5. Harness đã có kind-aware tool registry, risk lanes, traces, decisions, usage events và
   graph journal. Không cần tạo control plane thứ hai.
6. `story verify` có thể thực thi stored shell command; safe boundary hiện giả định
   operator-authored input.
7. Release/docs coherence có drift thật: installer package là 0.4.1 trong khi
   `docs/quality-metrics.md` còn ghi 0.4.0.

### Tín hiệu ecosystem 2026

- Coding environments đang hội tụ vào composition: project guidance, skills, MCP,
  subagents, hooks và durable memory là các lớp khác nhau.
- MCP 2026 tăng capability nhưng đồng thời tăng yêu cầu auth, permissions, statelessness
  và cache semantics. Flow nên consume capability, không sở hữu transport.
- Frontier models phân tầng theo reasoning effort/cost. Hard-wire model selection sẽ nhanh
  stale; persisted outcome metadata bền hơn.
- Context engineering nhấn mạnh stable prefixes, compaction, memory và tool-output clearing.
  Flow có thể chuẩn hóa context pack sau khi trust receipts ổn định.
- AI code review trong GitHub vẫn advisory, không approve/block merge. Điều này khớp với
  gate parity hiện tại của flow.
- OSS agents cho thấy terminal-first, read-only planning agent, repo-map và spec-driven
  workflows đều hữu ích, nhưng không tạo moat bằng verifiable transition.

## Ba hướng khả thi

### A. Attested Execution / Trust Control Plane

**Nội dung**

- persisted risk classification cho card;
- hash-bound semantic attestation cho stage/card;
- structured verification receipt cho auto/live done;
- operator override/debt reference cho Tier-C;
- stale receipt invalidation khi artifact/diff thay đổi;
- CI/eval fixtures cho forged, stale và missing receipts.

**Lợi ích**

- Đóng gap ngay tại lời hứa cốt lõi "both layers agree".
- Dùng được với mọi agent/model/IDE/CI.
- Tăng mức tin cậy của auto/parallel, nơi failure có blast radius lớn nhất.
- Tạo substrate tự nhiên cho PR review, cost attribution và MCP capability sau này.

**Chi phí/rủi ro**

- Chạm state transition và backward compatibility.
- Receipt schema thiết kế quá rộng sẽ biến thành workflow engine.
- Cần migration path cho project đang chạy giữa stage/card.

**Cách giữ nhỏ**

- Chỉ hai receipt types đầu tiên: `semantic_gate` và `live_verify`.
- Risk vocab đóng: `standard|security-class|unknown`.
- `unknown` fail-closed trong auto, manual vẫn có operator override có lý do.
- Không tạo remote service, dashboard hay generalized policy language.

### B. Context Pack + Cost Intelligence

**Nội dung**

- deterministic scoped brief manifest;
- stable-prefix ordering cho prompt caching;
- tool-output compaction/clearing guidance;
- context/token/model/effort metadata per stage/card;
- optional cost budget/hard stop.

**Lợi ích**

- Giảm context rot và chi phí;
- cải thiện handoff giữa agent/model;
- trực tiếp khai thác trend prompt caching và long-running agents.

**Chi phí/rủi ro**

- Flow skill không kiểm soát cache implementation của host/vendor.
- Token/cost metadata không đồng nhất giữa subscription CLI, API và IDE.
- Tối ưu cost trước khi state trust chắc có thể làm agent sai nhanh và rẻ hơn.

**Kết luận**

Đáng làm thứ hai. Context pack nên dùng artifact hashes và receipt references từ hướng A,
thay vì phát minh một context identity riêng.

### C. Ecosystem Interoperability

**Nội dung**

- MCP capability/permission registry;
- GitHub PR check/comment adapter;
- Spec Kit/OpenSpec assess/import;
- thêm agent homes và OSS agent compatibility.

**Lợi ích**

- Tăng adoption và distribution;
- đưa flow vào workflow hiện hữu thay vì yêu cầu greenfield;
- PR/CI bridge làm evidence dễ thấy với team.

**Chi phí/rủi ro**

- Nhiều adapter, maintenance liên tục;
- MCP auth/security surface lớn;
- dễ biến flow thành integration catalog;
- adoption tăng trước khi trust invariant hoàn chỉnh sẽ khuếch đại failure.

**Kết luận**

Làm thứ ba, chọn adapter theo usage evidence. GitHub/CI bridge có ưu tiên cao hơn full MCP
hosting hoặc SDD schema import.

## Ma trận quyết định

Thang 1–5; điểm cao tốt. Trọng số phản ánh vision hiện tại: trust và standalone trước.

| Tiêu chí | Trọng số | A: Attested execution | B: Context/cost | C: Interop |
|---|---:|---:|---:|---:|
| Đóng gap cốt lõi đã xác minh | 30% | 5 | 3 | 2 |
| Tăng trust cho auto/parallel | 25% | 5 | 3 | 2 |
| Bền qua nhiều model/vendor | 15% | 5 | 4 | 3 |
| Fit standalone/portability | 10% | 4 | 4 | 3 |
| Effort-to-impact | 10% | 4 | 3 | 3 |
| Adoption/narrative | 10% | 4 | 3 | 5 |
| **Điểm trọng số** | **100%** | **4.7** | **3.25** | **2.65** |

## Đề xuất: release kế tiếp là Attested Execution

### Product statement

> Flow không tin transition vì agent nói đã review hoặc verify. Flow nhận một receipt gắn
> với đúng artifact/diff hiện tại; receipt stale hoặc thiếu thì transition không được dùng
> trong auto.

### Vertical slice đề xuất

#### Wave 0 — trust hygiene trước khi mở enforcement

1. Constrain `story verify`: named/allowlisted verify commands hoặc explicit unsafe mode;
   root-pinned cwd, timeout và output cap.
2. Centralized redaction cho durable free-text writes.
3. Release-doc coherence check: skill version, npm version, test count, install command và
   prerelease tag policy.

Wave 0 là hygiene, không phải narrative release.

#### Wave 1 — card risk becomes state

1. Card có `risk: standard|security-class|unknown` và `risk-reason`.
2. `card` scaffold mặc định `unknown`; agent/operator phải classify.
3. `/flow auto` hard-stop khi còn `unknown` hoặc `security-class` thiếu operator
   acknowledgement/DEBT reference.
4. `/flow ready` hiển thị risk và lý do block.

#### Wave 2 — attestation receipt

Receipt tối thiểu:

```text
kind
subject_type
subject_id
subject_hash
verdict
actor
engine
evidence_ref
timestamp
override_ref
```

- `semantic_gate`: stage/card semantic review đã pass hoặc operator override.
- `live_verify`: command/probe/target có kết quả được runner capture.
- Artifact/diff thay đổi làm receipt stale.
- Không lưu secret/raw unbounded output; lưu digest + bounded excerpt + artifact path.

#### Wave 3 — enforce một đường trước

1. Enforce bắt buộc trên `/flow auto` trước.
2. Manual/teach mode hiển thị warning + guided attestation, chưa hard-break ngay.
3. Sau một release telemetry và migration ổn, cân nhắc enforce planning `next`.

Thứ tự này tránh breaking toàn bộ manual flow trong lần đầu.

#### Wave 4 — behavioral proof

- stale-hash receipt bị từ chối;
- forged/missing receipt không unblock auto;
- Tier-C không có operator authority phải HALT;
- sound receipt cho golden card pass;
- live verify command timeout/non-zero không mint PASS;
- Contract stage có sound/hollow eval fixture đầu tiên;
- Linux/macOS/Windows suites green.

## Vì sao không chọn các trend khác trước

### Không chọn MCP-first

Flow đã có kind/capability-aware registry. Thêm MCP server/auth layer lúc này tăng attack
surface nhưng không sửa transition trust. Sau Attested Execution, registry chỉ cần thêm
permission/risk metadata và receipt từ tool calls.

### Không chọn model-routing-first

Model mới thay đổi nhanh. Flow đã có Codex/Antigravity cost gates và graceful degradation.
Moat không phải chọn đúng model release; moat là model nào cũng phải trả về evidence cùng
contract.

### Không chọn context-caching-first

Stable prompt prefix và compaction có ROI, nhưng host mới là nơi điều khiển cache. Flow nên
chuẩn hóa context manifest sau khi subject hashes/receipt references tồn tại; lúc đó cache
identity không bị làm hai lần.

### Không chọn PR-review-first

AI review comment không phải approval. PR adapter trước receipt chỉ tạo thêm prose. Khi đã
có attestation, GitHub Check có thể hiển thị đúng verdict + subject hash + evidence link.

### Không chọn graph-default-on

Graph executor là journal/recovery substrate tốt nhưng không tự tạo trustworthy verdict.
Enforcement primitive nên ổn trước; graph có thể lưu receipt transition sau.

## Roadmap sau hướng được chọn

### v0.28 — Attested Execution

- Wave 0–4 ở trên;
- auto-first enforcement;
- trust scorecard.

### v0.29 — Context Pack & Model Economics

- deterministic ScopedBrief manifest;
- stable common prefix + volatile tail;
- tool-output compaction policy;
- model/effort/token metadata khi host cung cấp;
- budget hard-stop optional, không đoán giá.

### v0.30 — Ecosystem Bridges

- GitHub Check/PR adapter trước;
- MCP permission/capability metadata, consume-only;
- Spec Kit/OpenSpec brownfield discovery/import nếu telemetry chứng minh nhu cầu;
- agent-home expansion chỉ khi có install/support demand.

## Không nên làm

- Gom A+B+C vào một major release.
- Dùng LLM judge receipt mà không có artifact hash.
- Để agent tự classify Tier-C rồi tự override.
- Lưu raw prompts/tool outputs/secrets vào SQLite.
- Tạo generalized policy DSL.
- Hard-code pricing hoặc benchmark model vào state machine.
- Thêm model reviewer chỉ để có logo thứ tư.
- Dùng MCP làm dependency để chạy core gates.

## Work checklist cho `ak:plan`

- [ ] Chốt trust invariant và backward-compatible enforcement boundary
- [ ] Thiết kế card risk fields + migration/default behavior
- [ ] Thiết kế minimal receipt schema và subject hashing
- [ ] Chọn portable store/read format cho Bash floor
- [ ] Thiết kế operator acknowledgement + DEBT linkage
- [ ] Constrain harness verify execution
- [ ] Centralize durable redaction
- [ ] Implement auto preflight risk enforcement
- [ ] Implement receipt mint/validate/stale detection
- [ ] Add auto/live verify receipts
- [ ] Add Contract semantic eval fixtures
- [ ] Add cross-OS regression tests
- [ ] Add release-doc coherence gate
- [ ] Dogfood on at least one real skill project before manual-mode hard enforcement

## Success metrics

| Metric | Target |
|---|---|
| Auto cards with unknown risk | 100% blocked before dispatch |
| Security-class without operator authority | 100% HALT |
| Artifact changed after attestation | 100% receipt invalidated |
| Auto card done without valid live receipt | 100% rejected |
| Verify timeout/non-zero | 0 PASS receipts minted |
| Golden sound card flow | 100% passes |
| Existing manual projects | Migration documented; no silent corruption |
| Standalone | Core enforcement works without AgentKit/MCP/vendor service |
| CI | Existing 48 suites + new suites green on Ubuntu/macOS/Windows |
| Semantic eval | Contract sound/hollow fixtures majority-match baseline |
| Durable privacy | Known secret fixtures absent from DB/receipt store |

## Trade-offs chấp nhận

- Auto sẽ chậm hơn vì phải classify và mint evidence.
- Receipt UX ban đầu thêm ceremony; auto-only enforcement giảm blast radius.
- Hash-bound state cần migration và stale handling rõ.
- Một receipt chứng minh probe đã chạy, không chứng minh mọi business behavior đúng; fixture
  và semantic review vẫn cần.
- Manual mode chưa hard-enforce ngay nên sẽ có giai đoạn hai mức strictness.

## Giả định đã dùng

Ưu tiên sản phẩm hiện tại là tăng trust/autonomy cho solo power-user và team chạy nhiều
agent, cao hơn tăng install count ngắn hạn. Giả định này dựa trên architecture, các release
v0.26–v0.27 và câu hỏi nghiên cứu hiện tại.

## Câu hỏi chưa giải quyết

Không có câu hỏi chặn brainstorm. Trước khi lập plan cần operator xác nhận hoặc sửa đúng một
điểm: **chấp nhận auto-first enforcement và trì hoãn hard enforcement cho manual `next` sang
sau một release telemetry hay không.**

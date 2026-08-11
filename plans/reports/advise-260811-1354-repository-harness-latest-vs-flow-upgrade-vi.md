# Advise: repository-harness (mới nhất) → nâng cấp harness flow-skill

**Date:** 2026-08-11  
**Sources (OBSERVED this session):**
- `/home/manhquy/project/repository-harness` @ `8f78cbb` / merge PR #64 `1df6b30` (EOL protocol v1)
- ADR `docs/decisions/0027-end-protocol-v1-and-focus-repository-protocol.md`
- Core payload `scripts/harness-install-files.txt`, CLI `crates/harness` v0.1.8
- flow-skill workspace v0.26.0 (`skills/flow/SKILL.md`), durable layer + GAP-MATRIX-0.1.17
- Prior advise same day: `plans/reports/advise-260811-1050-flow-upgrade-harness-trust-vi.md` (hollow-done — **đã ship 0.26**)

**Mode:** advisory only — không implement.

**Assumption (user prior):** muốn xếp hạng full gap; constraint mặc định advise: **standalone + YAGNI**, không AgentKit, không require binary `harness` mới.

---

## 0. Floor (outcome thật)

**Goal end-state:** Operator / maintainer flow biết *chính xác* repository-harness mới khác gì, cái nào còn đáng port, cái nào là dead lineage — và có backlog xếp hạng để harness flow không còn “pin v1 chết” hay FOMO sync schema.

**Không phải goal:** “làm flow giống repository-harness” hay “cài `harness` Rust vào flow”.

---

## 1. Scout: repository-harness mới nhất là gì

### 1.1 Product boundary (sau 2026-08-10)

| Trước (historical) | Bây giờ (current tree) |
|--------------------|-------------------------|
| `harness-cli` + SQLite protocol v1 (intake/story/trace/changeset…) | **EOL** — archive pin last published `harness-cli-v0.1.22` |
| Control plane = system of record cạnh repo | **Repo = system of record** |
| Nhiều release train CLI | Một binary **`harness`** (core install/update) `v0.1.8` |

**ADR 0027 (Accepted):** protocol v1 + SQLite control plane end-of-life; current tree không maintain schema/compat/release train cho CLI đó; install/update **không** xóa legacy `harness.db` consumer (consumer-owned).

**HARNESS.md principle 7 + EOL note:** “Harness maintains only its core” / SQLite control plane = historical only.

### 1.2 CLI surface (Rust, clean architecture)

```
harness install | update [--continue|--abort] | status | doctor
(+ self-update từ release pointer harness-v*)
```

- Provenance: `.harness-core/` (manifest, base, transaction, conflict workspace)
- Update: three-way merge, freeze managed inputs, reject symlink replace, checksum + version identity
- Conflict: BASE/LOCAL/UPSTREAM/RESOLVED — **human owns material choice**; agent explain, không tự pick policy
- **Không** có: intake, story, trace, query matrix, changesets, orchestration

### 1.3 Installed core payload (guidance, không runtime)

Từ `harness-install-files.txt`:

- `AGENTS.md` entry (HARNESS block): read-only vs bounded change vs durable plan; authority stop; proof; no task DB
- `docs/WORKFLOW.md`, product/plans/decisions maps
- Templates: `exec-plan`, `decision`, `application-runbook`, **`harness-improvement`**
- Explicit-only skills: `onboard-repository`, `audit-onboarding-proposal`, `improve-harness`
- Optional add-on: `engineering-wisdom` (`--with-engineering-wisdom`)

### 1.4 Cơ chế “mới / sắc” đáng học (không phải binary)

| # | Mechanism | Evidence |
|---|-----------|----------|
| A | **Work-shape**: ephemeral vs one `docs/plans/active/` plan | WORKFLOW + AGENTS |
| B | **Authority stop** trước mutation khi material product choice open | 0019, AGENTS |
| C | **Completion = executable/observable proof**, không self-report | HARNESS principle 5 |
| D | **`$improve-harness`**: baseline → earliest gap → one intervention → **fresh-agent rerun** before claim keep | skill + template |
| E | **`$onboard-repository`**: read-only first, claim class (Authoritative/Observed/Derived/Decision required/Unknown), operational-path table, **evidence capsule v2** + patch digest, no-mutation gate | skill (rất dày) |
| F | **Safe core update**: 3-way + conflict workspace + release identity | 0024/0025 |
| G | **Explicit-only skills** — install ≠ activate | 0026, product profiles |
| H | **Application runbook** consumer-owned; template ≠ proof of operability | WORKFLOW + template |

### 1.5 Không còn là “upstream feature source” cho SQLite

Last historical CLI pin published: **0.1.22**. Flow vẫn document **0.1.14 / 0.1.17**.  
**DERIVED:** mọi “gap matrix vs 0.1.17” giờ là **historical comparison**, không còn upgrade path upstream.

---

## 2. Scout: flow-skill harness hiện tại

### 2.1 Ba lớp (vẫn đúng product)

1. **Semantic** — `SKILL.md` + references (judgment, auto tiers, concierge)
2. **Mechanical** — `runner/flow.sh` (gates, cards, done multi-signal floor v0.26)
3. **Durable** — `harness/flow_harness.py` + SQLite `.flow/harness.db` (port 001–005 + flow 009–012 + graph 014+)

### 2.2 Đã ship liên quan trust (đừng làm lại)

- **v0.24** trust-align: `story complete` only, no forge `last_verified_result=pass`
- **v0.25** graph executor opt-in
- **v0.26** hollow-done mechanical world-state signal score ≥2, ready/deps re-validate, auto-path tests

→ Principle **C** của repository-harness **đã được port theo kiểu flow** (card evidence), không cần “nâng cấp hollow-done lần 2” trừ khi eval residual.

### 2.3 Pin / narrative stale (debt thật)

| File | Claim | Reality |
|------|-------|---------|
| `skills/flow/harness/README.md` | Authority pins 0.1.14 / 0.1.17 | Upstream EOL; pins không còn product line |
| `GAP-MATRIX-0.1.17.md` | Gap vs live harness-cli | So sánh với **archive**, không phải current |
| `skills/harness-skill/SKILL.md` | Compliance gate `harness-cli` | Binary lineage dead; flow Python mới là live |
| Attribution SKILL.md | “harness layers from repository-harness” | Đúng historical; thiếu note product split 2026-08 |

### 2.4 Flow đã có “họ hàng” nhưng khác rigor

| repo-harness | flow tương đương | Gap |
|--------------|------------------|-----|
| WORKFLOW work-shape | full buildflow ladder + tiny/normal/high_risk lane | Flow **luôn** ceremony cho product build — đúng product; không copy “no plan for typo” vào core ladder |
| Authority stop | Tier-C security halt, constitution, DEBT | Ít formal **claim class** khi invent product policy ở Scope/PRD |
| improve-harness + fresh rerun | `propose` / backlog / friction / retro | **Thiếu** protocol “fresh agent rerun before claim harness improved” |
| onboard + evidence capsule | `/flow assess`, repo_map | Assess nhẹ hơn nhiều; không có capsule hash / no-mutation gate |
| 3-way self-update core | npm + install.sh overwrite | Không three-way merge skill files trong consumer project |
| engineering-wisdom | native-rituals / playbooks | Không cần pack generic SOLID |

---

## 3. Đối sánh có kết luận (2 hypotheses → 1)

**H1 — “Flow phải bám repository-harness mới = bỏ SQLite, chỉ docs protocol.”**  
Kill: flow’s product *is* a gated build control surface (stages/cards/auto). Repo-harness *explicitly rejected* being a task control plane. Bỏ durable layer = phá product.

**H2 — “Flow fork durable layer; port *principles/mechanisms* từ core mới; đóng sổ pin v1.”**  
Survives: matches ADR 0027 consumer note (legacy DB consumer-owned) + flow’s already-diverged schema 009–014.

**Verdict product:** Hai sản phẩm **bổ sung**, không thay thế.

```
repository-harness  →  “agent-ready repository” (map, authority, safe guidance update)
flow-skill          →  “honest ship from idea” (gates, cards, world-state done, optional durable memory)
```

---

## 4. Verdict (advise)

**Đúng hướng nâng cấp = re-author authority + port protocol rigor; sai hướng = sync harness-cli / rewrite flow thành repo-protocol-only.**

repository-harness mới **không** ship feature list cho flow durable SQLite. Nó ship:

1. xác nhận **control-plane song song là anti-pattern** cho *generic* agent work — flow phải **giữ** SQLite như *flow-owned product memory*, không “compatibility shim upstream”;
2. protocol **improve / onboard / authority / proof** sắc hơn flow hiện có ở vài seam;
3. installer/updater model — chỉ relevant nếu flow muốn safe update *skill payload* trong repo (thường **không** P0 cho skill global install).

Prior hollow-done advise (cùng ngày) **đã ship 0.26** → wave trust mechanical xong; wave tiếp theo sau repo-harness scout là **lineage honesty + improve/onboard rigor**.

---

## 5. Xếp hạng nâng cấp (P0 → P2)

### P0 — Phải làm (docs/authority, rủi ro thấp, chặn narrative sai)

1. **Supersede GAP-MATRIX-0.1.17**  
   - Title: historical archive vs `harness-cli-v0.1.22` max.  
   - State: **no further schema sync from upstream**.  
   - Declare schema bands: `001–005` frozen shared ancestry; `009–012` + `014+` flow-owned forever.

2. **Rewrite authority pins** trong `harness/README.md`, `harness-skill`, SKILL attribution  
   - Remove “trust pin 0.1.17” as live authority.  
   - Live authority = **flow durable CLI + mechanical runner + semantic gates**.  
   - Optional: “historical inspiration: repository-harness pre-EOL / ADR 0027”.

3. **Deprecate or reframe `skills/harness-skill`**  
   - Either: “legacy if `harness-cli` binary present (archive)”  
   - Or: redirect 100% to `/flow harness` Python.

4. **One short ADR/decision in flow** (optional but clean):  
   “Durable layer is flow product; repository-harness is peer methodology source, not dependency.”

**Không** ship code schema migration trong P0.

### P1 — ROI cao, port *cơ chế* (không binary)

5. **Native ritual: Improve-flow-harness** (port `$improve-harness` spirit)  
   - Trigger: explicit only (`/flow improve-harness` or ritual after repeated friction).  
   - Require: baseline → earliest gap owner → one intervention → **fresh session rerun** → keep/revise/remove.  
   - Wire lightly to existing `propose`/backlog (propose generates candidates; improve ritual is the evidence bar for *skill/template* changes).  
   - **Do not** auto-run after every retro.

6. **Assess claim classification (subset of onboard-repository)**  
   - On `/flow assess` / brownfield: force tags Authoritative | Observed | Derived | Decision required | Unknown.  
   - Gate semantic: never promote Observed→Authoritative in `00-inspect` without operator.  
   - Skip full evidence-capsule v2 machinery in v1 of this port (too heavy).

7. **Material-authority stop language** in gate-rules for Scope/PRD/Contract  
   - Mirror AGENTS: “if materially different product choices remain → stop, list choice + consequences”.  
   - Complements Tier-C; applies to *product ambiguity*, not only security keywords.

### P2 — Có giá trị, sau P0/P1 hoặc niche

8. **Evidence capsule lite** for assess proposals (hash destination + atomic claims) — only if assess false-confidence dogfood hurts.  
9. **Skill install 3-way / conflict** for project-local `.claude/skills/flow` — only if users report stomped local skill edits; most users use global skill home.  
10. **engineering-wisdom** — out of flow product; point to external pack if wanted.  
11. **Graph default-on** — still not justified by repo-harness changes (orthogonal).  
12. **Pull harness-cli 0.1.18–0.1.22 features** — only if a *specific* archived command still missing in Python **and** dogfood needs it; default **no**.

---

## 6. What you should NOT do

| Trap | Why |
|------|-----|
| Re-pin or re-integrate live `harness-cli` | EOL; no maintenance; schema already forked |
| Port changesets 006–013 from archive | Flow chose graph 014+; collision already documented |
| Drop `.flow/harness.db` to “be like new harness” | Destroys recall/usage/trace product |
| Require Rust `harness` binary for flow | Breaks standalone skill story |
| Clone full onboard-repository skill (400+ lines) wholesale | Weight >> value; subset claim class first |
| Treat 3-way core update as next npm feature without user pain | YAGNI |
| Second hollow-done mega-pass before P0 lineage docs | 0.26 just shipped; residual via fixtures only |
| AgentKit / kongming hard dep | Same as prior advise |

---

## 7. What could be better / cheaper

| Path | Effort | Impact |
|------|--------|--------|
| **A. P0 docs/authority only** | Low | Stops lying pins; unblocks honest roadmap |
| **B. A + improve-harness ritual** | Med | Quality bar for future skill edits (matches upstream’s best new process) |
| **C. A + assess claim classes** | Med | Brownfield honesty (onboard spirit without capsule) |
| **D. Full capsule + 3-way skill update** | High | Marginal unless dogfood demands |
| **E. Sync dead CLI** | Med–High | **Negative** impact |

**Recommended sequence:** A → B → C → (eval residual hollow) → D only if needed.

---

## 8. My take — route from here

```
Now (v0.26): hollow-done mechanical floor done
     │
     ▼
Wave Authority (docs): supersede GAP, kill live 0.1.17 pins, reframe harness-skill
     │
     ▼
Wave Protocol port: improve-flow-harness (fresh rerun) + assess claim classes
     │
     ▼
Wave residual trust: more FLAG fixtures / strategist ritual (from prior advise, not from repo-harness)
     │
     ▼
Wave optional: capsule lite / skill three-way only on evidence of pain
```

**One-line strategy:**  
*repository-harness mới = methodology + installer product; flow durable = owned fork. Port improve/onboard rigor; stop pretending schema upstream exists.*

---

## 9. Benefits

- Narrative đúng: không ship docs trỏ dead binary.  
- Maintainer không waste cycle “catch up 0.1.22 schemas”.  
- Skill evolution có **fresh-rerun** bar (upstream’s best process gift).  
- Brownfield assess ít bịa product policy.  
- Standalone preserved.

## 10. Trade-offs

- P0 “chỉ docs” không tăng feature demo — cần chấp nhận.  
- Improve-ritual thêm ceremony cho maintainer skill (đúng intentional).  
- Assess claim classes có thể chậm brownfield first pass (đổi lấy honesty).  
- Divergence with archive harness-cli becomes permanent and explicit (already true in schema).

---

## 11. Work checklist

- [ ] ADR/note: flow durable owned; repo-harness peer, not pin  
- [ ] Supersede `GAP-MATRIX-0.1.17.md` → historical + no-sync policy  
- [ ] Update `harness/README.md` authority table  
- [ ] Update `skills/harness-skill` + SKILL attribution  
- [ ] Grep kill live references to `harness-cli-v0.1.1[4-7]` as current authority  
- [ ] Spec improve-flow-harness ritual (template + when to invoke)  
- [ ] Spec assess claim classification in gate-rules / assess template  
- [ ] Material-authority stop bullets in Scope/PRD semantic challenges  
- [ ] Tests only if ritual becomes mechanical (docs-first OK)  
- [ ] CHANGELOG entry “authority reframe post repository-harness EOL” when ship

## 12. Success metrics

| Metric | Target |
|--------|--------|
| Live authority pins to EOL CLI in skill docs | **0** (`rg` clean except historical section) |
| GAP doc states “no upstream schema sync” | Present, first-screen |
| improve-harness claims without fresh rerun | Forbidden in ritual text |
| assess promotes Observed→policy without operator | Forbidden in gate-rules |
| Standalone install | Still no Rust harness required |
| Durable DB after upgrade docs | Existing projects open unchanged |

---

## Appendix A — Side-by-side surface map

| Concern | repository-harness now | flow now | Upgrade action |
|---------|------------------------|----------|----------------|
| Task/story DB | Removed | Python SQLite | Keep; own |
| Install/update guidance files | Rust 3-way | npm/install.sh | P2 optional |
| Completion proof | Principle only | Mechanical multi-signal + story complete | Maintain 0.26 |
| Self-improve harness | `$improve-harness` + rerun | propose/retro soft | **P1 port protocol** |
| Brownfield map | onboard + capsule | assess | **P1 claim classes** |
| Human material choice | Stop before edit | Tier-C + DEBT | **P1 product ambiguity stop** |
| Graph/orchestration | Explicit non-goal | Opt-in graph | Keep off-by-default |
| Engineering heuristics | Opt-in wisdom pack | playbooks/rituals | Skip |

## Appendix B — Claim types used in this report

| Type | Examples |
|------|----------|
| OBSERVED | ADR 0027 text; CLI subcommands; install file list; flow v0.26 CHANGELOG; pin strings in flow docs |
| DERIVED | “no schema upgrade path”; H1 killed; ranking A→B→C |
| PRIOR | Market 2026 harness narrative (not re-researched this pass) |
| ASSUMED | Default constraint standalone/YAGNI; user wants ranking over single-slice |

---

*End advise. Next useful command if accepted: `ak:plan` on Wave Authority only, or implement P0 docs slice.*

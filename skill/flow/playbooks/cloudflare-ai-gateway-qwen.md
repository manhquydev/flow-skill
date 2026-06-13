# Playbook: LLM agent in a Python/FastAPI backend via Cloudflare AI Gateway → Qwen (Workers AI)

Replicate in ~15 min. Copy-paste the skeleton, run the smoke tests, ship.

## When to use this
You want an LLM feature (classification, structured extraction, draft generation, summarization) in a backend, routed through **Cloudflare AI Gateway** for cost observability + a single seam, hitting **Workers AI** models (e.g. Qwen). No Anthropic/OpenAI key — just a **Cloudflare API token**.

---

## DECISION RULE — single call vs. deepagents agent (read first)
**Use a single structured-JSON call** (cheap model like `@cf/qwen/qwen2.5-coder-32b-instruct`) for **classify / extract / draft / summarize** — any one-shot transform. This is the common case; most "AI features" in a CRUD app are single calls.

**Use deepagents** (`@cf/qwen/qwen3-30b-a3b-fp8` + the content shim, see "deepagents" sections below) ONLY when the task needs **multi-step planning + tool use + sub-agents** — investigate-then-act, multi-source recap, retrieval-augmented chat.

**Don't pay the agent tax for a one-shot transform.** The ab-tickets triage feature is a single call, and that was the right call.

---

## ⚠️ THE CRITICAL GOTCHA — read first
**Qwen on Workers AI does NOT return OpenAI-style `tool_calls`.**

When you pass `tools` + `tool_choice`, the response has `tool_calls: null` and the model emits the "function call" as TEXT in `content`:

```
<function-name>triage</function-name>
<args-json-object>{"category":"repair","sentiment":"angry"}</args-json-object>
```

This **breaks any agentic framework that depends on real tool-calling** (deepagents / LangGraph tool loops, OpenAI-tool-calling clients). We caught this with a live smoke test *before* committing to the architecture.

**LESSON:** If your task is really "get structured output from ONE call" (classify / extract / draft / summarize), do NOT use a multi-step tool-calling agent framework with Qwen. Use a **single structured-JSON prompt** instead. Same user value, no non-determinism, no broken-tool-calling dependency. (This is the "re-architect C→B" move.)

**Always run the tool-calling smoke test (below) BEFORE building on any model you haven't used through this gateway.**

---

## The endpoint
CF AI Gateway exposes an **OpenAI-compatible** endpoint.

Base URL shape:
```
https://gateway.ai.cloudflare.com/v1/<ACCOUNT_ID>/<GATEWAY_NAME>/workers-ai/v1
```
then POST to `/chat/completions`.

- **Auth:** header `Authorization: Bearer <CLOUDFLARE_API_TOKEN>` — a CF API token with **Workers AI** permission.
- **Gateways:** an account can have multiple AI Gateways. Use a gateway with `authentication: false` for the simplest setup (no extra gateway key). List them:
  `GET /accounts/<ACCOUNT_ID>/ai-gateway/gateways`
- **Model ids on Workers AI:** see the model-selection table below. Defaults:
  - single structured-JSON call → `@cf/qwen/qwen2.5-coder-32b-instruct`
  - agentic / deepagents → `@cf/qwen/qwen3-30b-a3b-fp8`

---

## The working approach: single structured-JSON call
- System prompt: instruct the model to **"return ONLY valid JSON, no explanation, no markdown."** Put the exact JSON shape in the user prompt.
- **Quirk:** Workers AI may return `content` as an **already-parsed JSON object (dict)**, NOT a JSON string. Your parser MUST handle both — see `_coerce_content`.
- `response_format: {"type":"json_object"}` was **unreliable/errored** in our test. Rely on prompt instructions + the coerce helper instead.
- **Always normalize/validate** model output against your enums server-side; fall back to safe defaults (`"other"` / `"neutral"`) for off-enum values. Never trust raw output to match your schema.
- Qwen handles **Vietnamese** well (we generate Vietnamese draft replies).

---

## Which Workers AI model for tool-calling / agentic frameworks (deepagents)
Tested live through the CF AI Gateway OpenAI-compatible endpoint for REAL tool-calling support (does the model populate `tool_calls`, and does it survive a full deepagents loop):

| Model | Price (in/out per M tokens) | Raw `tool_calls` | Full deepagents loop | Verdict |
|---|---|---|---|---|
| `@cf/qwen/qwen2.5-coder-32b-instruct` | ~0.30 / (n/a) | ❌ emits call as TEXT `<tools>{...}</tools>`, `tool_calls=null` | ❌ breaks | DO NOT use for agents (fine for single structured-JSON calls) |
| `@cf/ibm-granite/granite-4.0-h-micro` | $0.017 / $0.112 | ✅ | ❌ returns malformed tool args (string not dict) → ValidationError | cheapest but too flaky for agent loops |
| `@cf/qwen/qwen3-30b-a3b-fp8` | $0.051 / $0.335 | ✅ | ✅ **WORKS** — valid args, completes graph | ✅ **RECOMMENDED** cheapest that actually works |
| `@cf/zai-org/glm-4.7-flash` | $0.061 / $0.40 | ✅ | ✅ works | ✅ runner-up |
| `@cf/openai/gpt-oss-20b` | $0.20 / $0.30 | ✅ | ❌ 400 (sends extra array content) | avoid via gateway |
| `@cf/meta/llama-3.3-70b-instruct-fp8-fast` | $0.293 / $2.253 | ✅ (advertised) | untested | pricey |

**KEY LESSON:** "supports function calling" in the model catalog does NOT mean it works through the gateway. Always smoke-test the FULL loop. The cheapest model that genuinely works with deepagents end-to-end is **`@cf/qwen/qwen3-30b-a3b-fp8`**. Use a cheap non-agentic model (`qwen2.5-coder`) for high-volume single-call triage, and `qwen3-30b` only for the agentic steps.

---

## deepagents + Workers AI: the content-blocks 400 gotcha + the fix
deepagents (via langchain `ChatOpenAI`) sends the SYSTEM message `content` as an ARRAY of content blocks: `[{"type":"text","text":"..."}]`. Workers AI's OpenAI-compat endpoint ONLY accepts `content` as a plain string, so it 400s:

```
AiError: Bad input: ... Type mismatch of '/messages/0/content', 'string' not in 'array'
```

**FIX** — a shim that flattens array content to a string before the request hits Workers AI. Monkeypatch the OpenAI client's `create` (import once, before constructing the agent):

```python
import openai
_orig = openai.resources.chat.completions.Completions.create
def _flatten(content):
    if isinstance(content, list):
        return "".join(b.get("text","") for b in content if isinstance(b, dict) and b.get("type")=="text")
    return content
def _patched(self, *a, **k):
    for msg in k.get("messages", []):
        if "content" in msg:
            msg["content"] = _flatten(msg["content"])
    return _orig(self, *a, **k)
openai.resources.chat.completions.Completions.create = _patched
```

With this shim + `qwen3-30b-a3b-fp8`, deepagents runs end-to-end on Cloudflare (tool executed, valid args, coherent Vietnamese answer).

> Note: a plain langchain `.invoke("string")` already sends string content fine — only deepagents' structured system prompt triggers the array. You only need the shim when running deepagents (or anything that builds multi-block content).

### deepagents setup that works
```python
from langchain_openai import ChatOpenAI
from deepagents import create_deep_agent
model = ChatOpenAI(model="@cf/qwen/qwen3-30b-a3b-fp8",
    base_url=f"https://gateway.ai.cloudflare.com/v1/{ACCT}/{GATEWAY}/workers-ai/v1",
    api_key=CF_API_TOKEN, temperature=0)
agent = create_deep_agent(model=model, tools=[...], system_prompt="...")
result = agent.invoke({"messages":[{"role":"user","content":"..."}]})
```
Versions tested: **deepagents 0.6.8, langchain-openai 1.3.0.**

### Tool-loop smoke test (before trusting a model for agents)
Run a real `agent.invoke(...)` with one trivial tool and assert: (a) the model populates `tool_calls`, (b) the args parse as a dict, (c) the graph completes. If any fail, the model is not agent-ready through the gateway regardless of the catalog claim.

---

## Architecture patterns that worked
- **Async after the write.** Run the LLM call in a FastAPI `BackgroundTasks` task AFTER the main DB write, so the user-facing request (e.g. ticket creation) NEVER blocks on the LLM. Create the record first with a stubbed `pending` AI block; the background task flips it to `done` or `failed`.
- **Store result as JSONB** (`ai` column) on the row:
  `{category, sentiment, draft_reply, faq_used, status: pending|done|failed, generated_at}`
- **Failure handling.** Wrap the whole triage in `try/except`; on ANY exception set `status="failed"` and **never raise to the caller**. The agent must never crash the main flow. Bad token → 401 → `status=failed`, record still intact.
- **Grounding without a vector DB (RAG-lite).** v1: pass a small FIXED set of hand-curated FAQ snippets in the prompt; have the model return which ids it used (`faq_used`). v2 (when the board can upload docs): store `@cf/baai/bge-m3` embeddings as a **JSONB float array** next to each snippet in Postgres and compute **cosine in-app** — no vector DB needed for a few hundred snippets. See the RAG-lite section below.
- **Safety: draft only.** The agent DRAFTS; a human approves before anything is sent to an end user. Never auto-send LLM output.

---

## RAG-lite: bge-m3 embeddings in Postgres + in-app cosine (no vector DB)
For a small corpus (building docs, FAQ, a few hundred snippets) you do NOT need a vector DB. Store embeddings as JSONB next to the text and compute cosine in Python. Fall back to the hardcoded FAQ when no docs are uploaded.

**Embeddings endpoint (same gateway, `/embeddings`):**
```python
import httpx
EMBED_MODEL = "@cf/baai/bge-m3"   # multilingual — handles Vietnamese
async def embed(texts: list[str]) -> list[list[float]]:
    url = settings.cf_ai_gateway_url.rstrip("/") + "/embeddings"
    async with httpx.AsyncClient(timeout=settings.agent_timeout_seconds) as client:
        resp = await client.post(url,
            headers={"Authorization": f"Bearer {settings.cf_ai_token}"},
            json={"model": EMBED_MODEL, "input": texts})
        resp.raise_for_status()
        data = resp.json()
    return [row["embedding"] for row in data["data"]]
```

**Storage:** SQLAlchemy `embedding: Mapped[list] = mapped_column(JSONB, default=list)`.

**In-app cosine top-K:**
```python
import math
def _cosine(a, b):
    if not a or not b: return 0.0
    dot = sum(x*y for x, y in zip(a, b))
    na = math.sqrt(sum(x*x for x in a)); nb = math.sqrt(sum(y*y for y in b))
    return dot/(na*nb) if na and nb else 0.0

TOP_K, MIN_SIM = 3, 0.30   # below MIN_SIM a snippet is too unrelated to inject
async def build_grounding(session, query_text):
    docs = (await session.execute(select(DocSnippet))).scalars().all()
    if not docs:
        return faq_block(), [], FAQ_IDS                      # fall back to hardcoded FAQ
    qv = await embed_one(query_text)
    scored = sorted(((_cosine(qv, d.embedding or []), d) for d in docs),
                    key=lambda t: t[0], reverse=True)
    top = [(s, d) for s, d in scored[:TOP_K] if s >= MIN_SIM]
    if not top:
        return faq_block(), [], FAQ_IDS | {d.id for d in docs}  # nothing relevant: FAQ not noise
    block = "\n".join(f"- [{d.id}] {d.title}: {d.content}" for _, d in top)
    return block, [d.id for _, d in top], {d.id for d in docs} | FAQ_IDS
```

Feed `block` into the user prompt as grounding; validate the model's `faq_used` against the returned valid-id set. When the corpus grows past a few thousand rows, swap the in-app cosine for `pgvector` — same shape, just move the math to SQL.

---

## Code skeleton (httpx async)

```python
# config.py
class Settings:
    cf_ai_gateway_url: str  # CF_AI_GATEWAY_URL = https://gateway.ai.cloudflare.com/v1/<acct>/<gw>/workers-ai/v1
    cf_ai_token: str        # CF_AI_TOKEN = Cloudflare API token (Workers AI perm)
    agent_model: str        # AGENT_MODEL = @cf/qwen/qwen2.5-coder-32b-instruct
    agent_timeout_seconds: float = 30.0

# agent.py
import json
import httpx
from datetime import datetime, timezone

CATEGORIES = {"repair", "billing", "complaint", "request", "other"}
SENTIMENTS = {"angry", "neutral", "happy"}

async def _call_qwen(system: str, user: str, max_tokens: int = 800) -> object:
    url = f"{settings.cf_ai_gateway_url}/chat/completions"
    payload = {
        "model": settings.agent_model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "max_tokens": max_tokens,
    }
    headers = {"Authorization": f"Bearer {settings.cf_ai_token}"}
    async with httpx.AsyncClient(timeout=settings.agent_timeout_seconds) as client:
        r = await client.post(url, json=payload, headers=headers)
        r.raise_for_status()
        content = r.json()["choices"][0]["message"]["content"]
        return _coerce_content(content)

def _coerce_content(content) -> dict:
    # Workers AI may return content as a dict OR a string.
    if isinstance(content, dict):
        return content
    s = content.strip()
    if s.startswith("```"):
        s = s.strip("`")
        if s.lower().startswith("json"):
            s = s[4:]
    return json.loads(s.strip())

def _normalize(raw: dict) -> dict:
    cat = raw.get("category")
    sent = raw.get("sentiment")
    return {
        "category": cat if cat in CATEGORIES else "other",
        "sentiment": sent if sent in SENTIMENTS else "neutral",
        "draft_reply": str(raw.get("draft_reply", "")),
        "faq_used": [x for x in raw.get("faq_used", []) if isinstance(x, str)],
    }

FAQ = [
    {"id": "faq-water", "topic": "Nước", "text": "Sự cố nước báo BQL tầng 1..."},
    # ... small hand-curated set
]

SYSTEM = (
    "Bạn là trợ lý phân loại ticket chung cư. "
    "Chỉ trả về JSON hợp lệ, không giải thích, không markdown."
)

def _user_prompt(ticket_text: str) -> str:
    faq = "\n".join(f'{f["id"]}: {f["topic"]} - {f["text"]}' for f in FAQ)
    return (
        f"FAQ:\n{faq}\n\n"
        f"Ticket: {ticket_text}\n\n"
        'Trả về JSON theo shape: '
        '{"category":"repair|billing|complaint|request|other",'
        '"sentiment":"angry|neutral|happy",'
        '"draft_reply":"<tiếng Việt>",'
        '"faq_used":["<faq id>"]}'
    )

async def triage_ticket(ticket_id: int):
    row = await load_ticket(ticket_id)          # your DB load
    try:
        raw = await _call_qwen(SYSTEM, _user_prompt(row.body))
        result = _normalize(raw)
        row.ai = {**result, "status": "done",
                  "generated_at": datetime.now(timezone.utc).isoformat()}
    except Exception:
        row.ai = {"category": None, "sentiment": None, "draft_reply": None,
                  "faq_used": [], "status": "failed",
                  "generated_at": datetime.now(timezone.utc).isoformat()}
    await commit(row)                           # never re-raise

# routes.py
@router.post("/tickets")
async def create_ticket(payload: TicketIn, background_tasks: BackgroundTasks):
    ticket = await db_create(payload, ai={"status": "pending"})  # stub first
    background_tasks.add_task(triage_ticket, ticket.id)          # async after write
    return ticket
```

---

## Deployment notes
- **Env vars:** `CF_AI_GATEWAY_URL`, `CF_AI_TOKEN` (the Cloudflare API token), `AGENT_MODEL`.
- **Confirm routing via gateway logs:**
  ```
  GET /accounts/<ACCOUNT_ID>/ai-gateway/gateways/<GW>/logs?per_page=5&order_by=created_at&order_by_direction=desc
  ```
  Shows `model`, `success`, `status_code`, `tokens_out` per request. Both 200 successes AND 401 failures appear here — good for confirming the request actually went through the gateway.

---

## Smoke tests (run these first)

```bash
BASE="https://gateway.ai.cloudflare.com/v1/<ACCOUNT_ID>/<GATEWAY_NAME>/workers-ai/v1"
TOKEN="<CLOUDFLARE_API_TOKEN>"
```

**1. Plain chat — confirms model + gateway + auth:**
```bash
curl -s "$BASE/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"@cf/qwen/qwen2.5-coder-32b-instruct",
       "messages":[{"role":"user","content":"Say hello in Vietnamese."}],
       "max_tokens":50}'
```

**2. Tool-calling — confirms THE GOTCHA. Expect `tool_calls: null` + the function call as TEXT in `content`:**
```bash
curl -s "$BASE/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"@cf/qwen/qwen2.5-coder-32b-instruct",
       "messages":[{"role":"user","content":"Triage: the elevator is broken and I am furious."}],
       "tools":[{"type":"function","function":{
         "name":"triage",
         "parameters":{"type":"object","properties":{
           "category":{"type":"string"},"sentiment":{"type":"string"}},
           "required":["category","sentiment"]}}}],
       "tool_choice":"auto",
       "max_tokens":200}'
```
Look at `choices[0].message`: `tool_calls` will be `null`, and `content` will hold
`<function-name>triage</function-name><args-json-object>{...}</args-json-object>`.
→ Do NOT build a tool-calling agent on this. Use approach #3.

**3. JSON output — the approach that works:**
```bash
curl -s "$BASE/chat/completions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"@cf/qwen/qwen2.5-coder-32b-instruct",
       "messages":[
         {"role":"system","content":"Return ONLY valid JSON, no explanation, no markdown."},
         {"role":"user","content":"Ticket: elevator broken, I am furious. Return {\"category\":\"...\",\"sentiment\":\"...\"}"}
       ],
       "max_tokens":200}'
```
Expect a clean JSON object in `content` (may already be parsed as a dict — handle both).

---

*Provenance: ab-tickets project, updated 2026-06 with deepagents model testing.*

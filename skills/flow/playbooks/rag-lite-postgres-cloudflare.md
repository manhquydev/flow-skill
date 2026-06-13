# RAG-lite — grounded LLM answers without a vector DB (Postgres + Cloudflare embeddings)

How to add Retrieval-Augmented Generation to a backend feature **without** Vectorize / pgvector
/ chunking pipelines / a doc-ingestion service. For a single tenant's handful-to-hundreds of
documents this is 80% of the value at ~5% of the infra. Verified in the ab-tickets project.

Pairs with: `cloudflare-ai-gateway-qwen.md` (the LLM-call side).

---

## Decision rule — do you even need a vector DB?

| Situation | Use |
|---|---|
| One tenant, ≤ a few hundred short docs/snippets, retrieve top-3 to ground one answer | **RAG-lite (this playbook)** — embeddings in Postgres JSONB, cosine in app |
| Thousands+ of docs, long documents needing chunking, multi-tenant at scale, sub-100ms retrieval | Real vector DB (Cloudflare Vectorize / pgvector / a managed RAG) |

Don't reach for a vector DB by reflex. Computing cosine over a few hundred 1024-float vectors in
Python is sub-millisecond. The vector DB earns its keep at scale, not at "ground this reply in
the building's rules."

---

## The shape

```
doc text ──embed(bge-m3 via CF gateway)──> 1024-float vector ──store──> Postgres JSONB column
query text ──embed──> qvec ──cosine vs every stored vec (in app)──> top-K ──inject into prompt
```

Two ways to consume the retrieved snippets:
1. **RAG-lite grounding (single call)** — fetch top-K, paste into ONE structured LLM call. Cheap,
   deterministic, no agent. Best for classify/draft/answer-this-one-thing. (C-011)
2. **RAG as an agent tool** — expose `search_docs(query)` as a tool a deepagents agent calls when
   *it* decides it needs policy context. Multi-step. Best for recap/investigate/chat. (C-013)

---

## Embeddings via Cloudflare AI Gateway (same seam as the chat model)

Model: `@cf/baai/bge-m3` — 1024-dim, multilingual (handles Vietnamese well), batch input.
OpenAI-compatible `/embeddings` endpoint on the same gateway base URL as chat.

```python
import httpx
EMBED_MODEL = "@cf/baai/bge-m3"

async def embed(texts: list[str]) -> list[list[float]]:
    url = settings.cf_ai_gateway_url.rstrip("/") + "/embeddings"
    async with httpx.AsyncClient(timeout=45) as client:
        r = await client.post(url,
            headers={"Authorization": f"Bearer {settings.cf_ai_token}"},
            json={"model": EMBED_MODEL, "input": texts})
        r.raise_for_status()
    return [row["embedding"] for row in r.json()["data"]]
```

Smoke test (confirm dim + that it works through YOUR gateway):
```bash
curl "$BASE/embeddings" -H "Authorization: Bearer $CF_TOKEN" \
  -d '{"model":"@cf/baai/bge-m3","input":["test một","test hai"]}' \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print('dim',len(d['data'][0]['embedding']))"
# -> dim 1024
```

---

## Storage — Postgres JSONB, no extension

```python
class DocSnippet(Base):
    __tablename__ = "doc_snippets"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    title: Mapped[str] = mapped_column(String(300))
    content: Mapped[str] = mapped_column(Text)
    embedding: Mapped[list] = mapped_column(JSONB, default=list)   # the 1024-float vector
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
```

Embed on insert (so retrieval is read-only):
```python
@router.post("/docs")
async def add_doc(payload: DocCreate, session = Depends(get_session)):
    vector = (await embed([f"{payload.title}\n{payload.content}"]))[0]   # embed title+content
    doc = DocSnippet(title=payload.title, content=payload.content, embedding=vector)
    session.add(doc); await session.commit(); await session.refresh(doc)
    return doc   # NOTE: response schema must NOT include `embedding` — don't leak the vector
```

GOTCHA: define a `DocOut` schema WITHOUT the `embedding` field, or the API leaks a 1024-number
array on every list call. Embed `title + content` together so a query matches on either.

---

## Retrieval — cosine top-K in app, with a fallback

```python
import math
TOP_K = 3
MIN_SIM = 0.30   # below this, a snippet is too unrelated to inject — skip it

def _cosine(a, b):
    if not a or not b: return 0.0
    dot = sum(x*y for x, y in zip(a, b))
    na = math.sqrt(sum(x*x for x in a)); nb = math.sqrt(sum(y*y for y in b))
    return dot/(na*nb) if na and nb else 0.0

async def build_grounding(session, query_text):
    docs = (await session.execute(select(DocSnippet))).scalars().all()
    if not docs:
        return faq_block(), [], FAQ_IDS                 # fallback A: no docs yet -> static FAQ
    qv = (await embed([query_text]))[0]
    scored = sorted(((_cosine(qv, d.embedding or []), d) for d in docs),
                    key=lambda t: t[0], reverse=True)
    top = [(s, d) for s, d in scored[:TOP_K] if s >= MIN_SIM]
    if not top:
        return faq_block(), [], FAQ_IDS                 # fallback B: nothing relevant -> FAQ
    block = "\n".join(f"- [{d.id}] {d.title}: {d.content}" for _, d in top)
    return block, [d.id for _, d in top], {d.id for d in docs} | FAQ_IDS
```

Three design points that matter:
- **MIN_SIM threshold.** Without it, you always inject the 3 "least bad" docs even when none are
  relevant — the model then hallucinates a connection. Below threshold, fall back to a generic
  FAQ (or nothing) instead of forcing irrelevant context.
- **Graceful fallback chain.** No docs uploaded → static FAQ. Docs exist but none match → FAQ.
  Only inject docs when genuinely similar. The feature must work from day-zero (empty corpus).
- **Return the matched ids.** Ask the LLM to echo which snippet ids it used (`faq_used`), then
  validate that echo against the real id set server-side. Gives you "grounded in: [doc X]"
  provenance for free, and catches the model inventing citations.

---

## Pattern 1 — RAG-lite grounding in a single structured call (C-011)

Inject the retrieved block into the SAME single-call prompt (see the gateway playbook for the
single-call + `_coerce_content` + enum-normalize approach). System prompt: *"Chỉ dùng thông tin
trong tài liệu được cung cấp; nếu không chắc, đề nghị chờ xác minh."* (Only use the provided docs;
if unsure, ask to wait for verification.)

Real result: pasted a building rule "không nuôi chó trên 20kg" → resident asks about a 25kg dog →
the grounded reply correctly said it exceeds the 20kg limit. That rule existed ONLY in the pasted
doc, nowhere in code. Same query with no matching doc fell back to the generic FAQ, no crash.

---

## Pattern 2 — RAG as a deepagents tool (C-013)

When the feature is agentic (the agent decides what it needs), expose retrieval as a tool instead
of pre-injecting. The agent calls `search_docs(query)` with its OWN query, possibly multiple times.

```python
def search_docs(query: str) -> str:
    """Tìm trong tài liệu/nội quy các đoạn liên quan tới truy vấn (RAG)."""
    # deepagents tools run SYNC -> use a short-lived sync psycopg connection + sync embed,
    # separate from the app's async engine. (asyncpg URL -> postgresql:// for psycopg.)
    docs = _fetch_docs_sync()
    qv = _embed_sync(query)
    top = sorted(((_cosine(qv, emb), t, c) for t, c, emb in docs), reverse=True)[:3]
    return "\n".join(f"[{t}] {c}" for s, t, c in top if s >= 0.25) or "Không tìm thấy."
```

Observed live: the recap agent called `list_open_tickets()`, saw fire + water complaints, then
**on its own** called `search_docs('fire safety')` AND `search_docs('water supply')` — two distinct
retrievals it chose based on what it found. That autonomy is the whole point of pattern 2; pattern 1
can't do it because the query is fixed before the call.

Sync-tool gotchas:
- deepagents tools are sync functions. Don't await inside them. Use `psycopg` (sync) + sync `httpx`
  for the embed, with a DSN derived from the async URL (`postgresql+asyncpg://` → `postgresql://`).
- Run the whole agent in `run_in_threadpool(...)` from the async endpoint so it doesn't block the
  event loop.
- JSONB vectors may come back as a Python list (SQLAlchemy) or a JSON string (raw psycopg) —
  `json.loads(emb) if isinstance(emb, str) else emb`.

---

## When to graduate to a real vector DB

Move off RAG-lite when any of these hits:
- Linear cosine scan gets slow (rule of thumb: > ~1–2k snippets per query).
- Documents are long and need **chunking** (RAG-lite assumes each row is one already-small snippet).
- You need filtered/metadata search, hybrid keyword+vector, or multi-tenant isolation at scale.
Then: Cloudflare Vectorize (stays on CF), or pgvector (stays in Postgres, adds an index). The
embed step (bge-m3 via the gateway) and the prompt-injection step are unchanged — only storage +
the top-K query move.

---

Provenance: ab-tickets project (Vietnamese apartment-ticket app), 2026-06. RAG-lite = card C-011;
RAG-as-agent-tool = card C-013. Stack: FastAPI + Postgres + Cloudflare Workers AI (bge-m3) via AI
Gateway. No Vectorize, no pgvector, no chunking.

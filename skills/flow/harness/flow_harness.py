#!/usr/bin/env python3
"""flow-harness - durable layer for the /flow skill (intake, story, trace, decision, backlog).

Default backend: this Python + stdlib sqlite3 implementation (no install needed).
Power-path backend: set FLOW_HARNESS_BACKEND=rust to forward argv to the compiled
repository-harness CLI (path via FLOW_HARNESS_CLI, default scripts/bin/harness-cli).

Run:  python flow_harness.py <command> [args]   (Git Bash on Windows / any POSIX)
DB:   <FLOW_PROJECT_ROOT>/.flow/harness.db   (override with --db)
"""

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys

import _db
import _domain as D
import _presence as P


def _flow_lineage_db(argv):
    """Path of a flow-lineage DB an external rust binary must not touch, else None.

    flow's Python port re-homed its accessed-count/usage migrations to versions 009-012,
    leaving 006-008 free. An upstream harness-cli only knows the shared 001-005 base; pointed
    at such a DB it sees MAX(version) >= 9, applies nothing, and would silently diverge if it
    later defines its own 006-008 (skipped because the version is already exceeded). The rust
    seam is frozen for flow-lineage DBs — detect them by the usage mirror or a re-homed version."""
    db_path = None
    for i, tok in enumerate(argv):
        if tok == "--db" and i + 1 < len(argv):
            db_path = argv[i + 1]
        elif tok.startswith("--db="):
            db_path = tok.split("=", 1)[1]
    if not db_path:
        db_path = _db.default_db_path()
    if not db_path or not os.path.exists(db_path):
        return None  # fresh/absent DB: nothing to protect yet
    try:
        con = sqlite3.connect(db_path)
        try:
            has_usage = con.execute(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name='usage_event'"
            ).fetchone() is not None
            row = con.execute("SELECT MAX(version) FROM schema_version").fetchone()
            maxv = (row[0] or 0) if row else 0
        finally:
            con.close()
    except sqlite3.Error:
        return None  # best-effort: unreadable -> let the CLI decide, never break the python path
    return db_path if (has_usage or maxv >= 9) else None


def _maybe_forward_to_rust(argv):
    if os.environ.get("FLOW_HARNESS_BACKEND", "python").lower() != "rust":
        return None
    conflict = _flow_lineage_db(argv)
    if conflict:
        sys.stderr.write(
            "flow-harness: refusing to forward to the rust backend.\n"
            f"  The DB at {conflict} uses flow's Python schema lineage (usage-log + re-homed\n"
            "  migrations 009-012). An external harness-cli only knows the shared 001-005 base and\n"
            "  would silently diverge on this DB. The rust seam is frozen for flow-lineage DBs.\n"
            "  Use the Python backend (unset FLOW_HARNESS_BACKEND) for this project.\n"
        )
        return 2
    cli = os.environ.get("FLOW_HARNESS_CLI")
    if not cli:
        root = os.environ.get("FLOW_PROJECT_ROOT") or os.getcwd()
        cand = os.path.join(root, "scripts", "bin", "harness-cli")
        cli = cand + (".exe" if os.name == "nt" else "")
    if not os.path.exists(cli):
        sys.stderr.write(
            f"flow-harness: FLOW_HARNESS_BACKEND=rust but binary not found ({cli}).\n"
            "Build it: cd repository-harness && cargo build --release -p harness-cli, "
            "then set FLOW_HARNESS_CLI to the binary. See harness/README.md.\n"
        )
        return 2
    return subprocess.call([cli] + argv)


def _jlist(s):
    if s is None:
        return None
    if isinstance(s, (list, tuple)):
        items = list(s)
    else:
        items = [x.strip() for x in str(s).split(",") if x.strip()]
    return json.dumps(items)


# --- usage signal: accessed_count (read-only reuse counter; NEVER deletes a row) ---
# Low access count is not evidence of low value: a rare one-time security lesson is recalled
# rarely BECAUSE it is rare. So security-class rows sort first and nothing is ever pruned by count.
# Mirrors flow.sh's canonical security-class Tier-C pattern, extended with JWT-class terms a
# title can carry. Over-classifying is safe here (security rows merely sort first); a buried
# security lesson is the real harm, so err broad.
_SECURITY_RE = re.compile(
    r"auth|authoriz|authorize|admin|tenan|payment|billing|password|token|secret|credential|"
    r"permission|role|rbac|login|pii|migrat|validation|jwt|oauth|session|crypto|encrypt", re.I)


def _is_security_text(*parts):
    return bool(_SECURITY_RE.search(" ".join(str(p) for p in parts if p)))


def _order_by_reuse(rows, sec_key):
    # security-class rows FIRST (never deprioritized by a low count), then most-reused-first,
    # then a stable id tiebreak. Pure ordering — never drops or deletes a row.
    return sorted(rows, key=lambda r: (0 if sec_key(r) else 1,
                                       -(r.get("accessed_count") or 0),
                                       str(r.get("id"))))


def _touch_accessed(con, table, ids):
    # increment the read counter for surfaced rows. `table` is a code literal, never user input.
    # Best-effort: a read-only / locked DB must NOT fail the query — surfacing the rows matters
    # more than the counter, so swallow a write error and return the results regardless.
    ids = [i for i in ids if i is not None]
    if not ids:
        return
    ph = ", ".join("?" for _ in ids)
    try:
        con.execute(f"UPDATE {table} SET accessed_count = accessed_count + 1 WHERE id IN ({ph})", ids)
        con.commit()
    except sqlite3.Error:
        pass


# ---------------- commands ----------------

def cmd_init(con, a):
    # use the graceful version helper (survives the case where schema_version is absent)
    print("flow-harness: initialized at schema version", _db._current_version(con))
    print("db:", a._db_path)


def cmd_intake(con, a):
    flags = D.normalize_flags(a.flags)
    recommended, reason = D.classify_lane(flags, removing_validation=a.removing_validation,
                                           code_impact_high=a.code_impact_high)
    ok, msg = D.lane_downgrade_allowed(recommended, a.lane, a.narrow_scope)
    if not ok:
        print("BLOCKED:", msg)
        return 1
    lane = a.lane or recommended
    iid = _db.insert(con, "intake", input_type=a.type, summary=a.summary, risk_lane=lane,
                     risk_flags=_jlist(flags) if flags else None,
                     affected_docs=_jlist(a.docs), story_id=a.story, notes=a.notes)
    print(f"PASS: intake #{iid} -> lane={lane}")
    print(f"  reason: {reason}" + ("" if lane == recommended else f" (operator set lane={lane})"))
    if flags:
        print("  flags:", ", ".join(flags))
    if lane == "high_risk":
        print("  high-risk: create a story folder, record a durable decision on behavior/auth/data/contract change.")
    return 0


_PROOF_SOURCES = ("card_markdown_gate", "manual", "verify_command")
_SECRET_RE = re.compile(
    r"(?i)(token|secret|passwd|password|credential|api[_-]?key|bearer|authorization|-----begin)"
)


def _mask_evidence(text):
    """Redact secret-shaped free text before durable store (trust-align RT)."""
    if text is None:
        return None
    if _SECRET_RE.search(text):
        return "***redacted***"
    return text


def cmd_story(con, a):
    if a.story_cmd == "add":
        if a.lane not in D.LANES:
            print("FAIL: --lane must be tiny|normal|high_risk"); return 1
        _db.insert(con, "story", id=a.id, title=a.title, risk_lane=a.lane,
                   contract_doc=a.contract, verify_command=a.verify)
        print(f"PASS: story {a.id} added (lane={a.lane})")
        return 0
    if a.story_cmd == "update":
        # Trust boundary (US-101 spirit, flow-native): bare implemented is forbidden.
        if a.status == "implemented":
            print(
                "FAIL: story update --status implemented is rejected.\n"
                "  Use: story complete --id <id> --proof-source card_markdown_gate|manual|verify_command\n"
                "  (honest proof provenance; never forge last_verified_result without story verify)"
            )
            return 1
        n = _db.update(con, "story", "id", a.id, status=a.status,
                       unit_proof=a.unit, integration_proof=a.integration,
                       e2e_proof=a.e2e, platform_proof=a.platform,
                       evidence=_mask_evidence(a.evidence))
        print(f"{'PASS' if n else 'FAIL'}: story {a.id} {'updated' if n else 'not found'}")
        return 0 if n else 1
    if a.story_cmd == "complete":
        s = _db.one(con, "SELECT * FROM story WHERE id=?", (a.id,))
        if not s:
            print(f"FAIL: story {a.id} not found"); return 1
        src = (a.proof_source or "").strip()
        if src not in _PROOF_SOURCES:
            print(
                "FAIL: --proof-source required: card_markdown_gate|manual|verify_command\n"
                "  card_markdown_gate = /flow check markdown gate (does NOT set last_verified=pass)\n"
                "  verify_command     = requires prior story verify pass"
            )
            return 1
        if src == "verify_command":
            if s.get("last_verified_result") != "pass":
                print(
                    f"FAIL: proof-source verify_command requires last_verified_result=pass "
                    f"(got {s.get('last_verified_result')!r}). Run: story verify --id {a.id}"
                )
                return 1
        # Honest provenance: card/manual never forge last_verified_result=pass
        ev = _mask_evidence(a.evidence) or s.get("evidence") or ""
        note = (s.get("notes") or "").strip()
        prov = f"proof_source={src}"
        if prov not in note:
            note = (note + "\n" + prov).strip() if note else prov
        if src == "card_markdown_gate" and "last_verified_result=pass" not in (note or ""):
            # explicit honesty marker for auditors
            note = note + "\nverify_stamp=not_shell"
        fields = dict(status="implemented", notes=note)
        if ev:
            fields["evidence"] = ev
        # only keep last_verified_* when real verify already passed
        n = _db.update(con, "story", "id", a.id, **fields)
        print(
            f"PASS: story {a.id} complete (status=implemented, proof_source={src})"
            + ("" if src == "verify_command" else " [no shell-verify stamp]")
        )
        return 0 if n else 1
    if a.story_cmd in ("verify", "verify-all"):
        if a.story_cmd == "verify":
            stories = [_db.one(con, "SELECT * FROM story WHERE id=?", (a.id,))]
            if stories == [None]:
                print(f"FAIL: story {a.id} not found"); return 1
        else:
            stories = _db.rows(con, "SELECT * FROM story WHERE verify_command IS NOT NULL AND verify_command<>''")
        rc = 0
        for s in stories:
            cmd = s.get("verify_command")
            if not cmd:
                print(f"  {s['id']}: no verify_command (skip)"); continue
            # shell=True is intentional: verify_command is operator-authored (like a Makefile
            # target). Do NOT pass externally-attacker-controlled strings here. For a shared
            # multi-author harness, gate verify-all behind an allowlist or use shell=False.
            res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            result = "pass" if res.returncode == 0 else "fail"
            _db.update(con, "story", "id", s["id"],
                       last_verified_at=_now(con), last_verified_result=result)
            print(f"  {s['id']}: {result} (exit {res.returncode})")
            if result == "fail":
                rc = 1
        return rc


def cmd_trace(con, a):
    rec = dict(task_summary=a.summary, intake_id=a.intake, story_id=a.story, agent=a.agent,
               actions_taken=_jlist(a.actions), files_read=_jlist(a.files_read),
               files_changed=_jlist(a.files_changed), decisions_made=_jlist(a.decisions),
               errors=_jlist(a.errors), outcome=a.outcome, duration_seconds=a.duration,
               token_estimate=a.tokens, harness_friction=a.friction, notes=a.notes)
    tid = _db.insert(con, "trace", **{k: v for k, v in rec.items() if v is not None})
    achieved, missing = D.score_trace(rec)
    lane = None
    if a.story:
        s = _db.one(con, "SELECT * FROM story WHERE id=?", (a.story,))
        lane = s.get("risk_lane") if s else None
    lane = lane or a.lane or "normal"
    ok, required = D.tier_verdict(lane, achieved)
    print(f"PASS: trace #{tid} recorded. tier {achieved}/3, required {required} for lane '{lane}'"
          + ("" if ok else "  <-- BELOW required"))
    if missing:
        print("  to reach next tier, add:", ", ".join(missing))
    # pre-close gate (advisory)
    if a.story:
        s = _db.one(con, "SELECT * FROM story WHERE id=?", (a.story,))
        if s and s.get("last_verified_result") != "pass":
            print(f"  pre-close gate: story {a.story} has not passed verification "
                  f"(last={s.get('last_verified_result')}). Run 'story verify {a.story}'.")
    return 0  # advisory: tier verdict never hard-fails the agent


def cmd_decision(con, a):
    if a.decision_cmd == "add":
        _db.insert(con, "decision", id=a.id, title=a.title, doc_path=a.doc,
                   status=a.status, verify_command=a.verify, predicted_impact=a.predicted)
        print(f"PASS: decision {a.id} added. (durable record = this row + markdown ADR at {a.doc or '<none>'})")
        if not a.doc:
            print("  note: high-risk decisions need a docs/decisions/NNNN-*.md file too - a trace field is not durable.")
        return 0
    if a.decision_cmd == "verify":
        d = _db.one(con, "SELECT * FROM decision WHERE id=?", (a.id,))
        if not d:
            print(f"FAIL: decision {a.id} not found"); return 1
        if not d.get("verify_command"):
            print(f"  {a.id}: no verify_command"); return 0
        # shell=True: operator-authored command only (see note in cmd_story verify).
        res = subprocess.run(d["verify_command"], shell=True, capture_output=True, text=True)
        result = "pass" if res.returncode == 0 else "fail"
        _db.update(con, "decision", "id", a.id, last_verified_at=_now(con), last_verified_result=result)
        print(f"  {a.id}: {result} (exit {res.returncode})")
        return 0 if result == "pass" else 1
    if a.decision_cmd == "outcome":
        # close the predicted-vs-actual loop: record what actually happened vs predicted_impact.
        n = _db.update(con, "decision", "id", a.id, actual_outcome=a.actual, status=a.status)
        print(f"PASS: decision {a.id} actual_outcome recorded" if n else f"FAIL: decision {a.id} not found")
        return 0 if n else 1


def cmd_backlog(con, a):
    if a.backlog_cmd == "add":
        bid = _db.insert(con, "backlog", title=a.title, current_pain=a.pain,
                         discovered_while=a.discovered_while, suggested_improvement=a.suggested,
                         predicted_impact=a.predicted, risk=a.risk)
        print(f"PASS: backlog #{bid} opened (growth-rule). Close it later with --outcome.")
        return 0
    if a.backlog_cmd == "close":
        n = _db.update(con, "backlog", "id", a.id, actual_outcome=a.outcome,
                       status=a.status, implemented_at=_now(con) if a.status == "implemented" else None)
        print(f"{'PASS' if n else 'FAIL'}: backlog #{a.id} {'closed' if n else 'not found'} ({a.status})")
        return 0 if n else 1


def _scan_tool_row(con, root, row):
    """Probe one tool's presence and persist status + checked_at. Returns (status, detail)."""
    status, detail = P.scan_tool_status(root, row.get("kind") or "cli",
                                        row.get("command"), row.get("scan_target"))
    con.execute("UPDATE tool SET status=?, checked_at=datetime('now') WHERE name=?",
                (status, row["name"]))
    con.commit()
    return status, detail


def cmd_tool(con, a):
    root = os.environ.get("FLOW_PROJECT_ROOT") or os.getcwd()
    if a.tool_cmd == "register":
        kind = (getattr(a, "kind", None) or "cli").lower()
        if kind not in D.TOOL_KINDS:
            print(f"FAIL: unknown tool kind '{kind}' (use one of: {', '.join(D.TOOL_KINDS)})")
            return 1
        # Validate the responsibility against the fixed vocabulary (like --kind). Free text would
        # fragment the "what is equipped for purpose X" lookup — a typo'd responsibility silently
        # never matches `query tools --responsibility "<canonical>"`, defeating the registry.
        if a.responsibility not in D.TOOL_RESPONSIBILITIES:
            print(f"FAIL: unknown responsibility '{a.responsibility}'. Use one of: "
                  f"{', '.join(D.TOOL_RESPONSIBILITIES)}")
            return 1
        cap = D.normalize_capability(getattr(a, "capability", None)) or None
        scan = getattr(a, "scan_target", None)
        # Registry = declared intent + last-scanned reality: registration always succeeds (for a
        # valid kind/responsibility) and records the probed status. A tool may legitimately be
        # registered before it is installed (status=missing until `tool check` / a later register
        # sees it). Presence is a query concern (`query tools --status present`), never a gate.
        status, _detail = P.scan_tool_status(root, kind, a.command, scan)
        # Upsert by PK name: DELETE + INSERT + checked_at in one explicit transaction so a crash
        # mid-upsert can never leave the row missing (atomic replace, not delete-then-maybe-insert).
        try:
            con.execute("BEGIN")
            con.execute("DELETE FROM tool WHERE name=?", (a.name,))
            cols = dict(name=a.name, command=a.command, description=a.description,
                        responsibility=a.responsibility, args=a.args, kind=kind,
                        capability=cap, scan_target=scan, status=status)
            keys = [k for k, v in cols.items() if v is not None]
            con.execute(f"INSERT INTO tool ({', '.join(keys)}) VALUES ({', '.join('?' for _ in keys)})",
                        [cols[k] for k in keys])
            con.execute("UPDATE tool SET checked_at=datetime('now') WHERE name=?", (a.name,))
            con.execute("COMMIT")
        except Exception:
            con.execute("ROLLBACK")
            raise
        hint = "  (not found yet; shows missing until installed)" if status == "missing" else ""
        print(f"PASS: tool '{a.name}' registered "
              f"(kind={kind}, capability={cap or '-'}, status={status}){hint}")
        return 0
    if a.tool_cmd == "check":
        where, params = ("WHERE name=?", (a.name,)) if getattr(a, "name", None) else ("", ())
        data = _db.rows(con, f"SELECT name,kind,command,scan_target FROM tool {where} ORDER BY name", params)
        if not data:
            if getattr(a, "name", None):
                print(f"FAIL: no tool named '{a.name}'"); return 1
            print("(no tools registered)"); return 0
        results = [(r["name"], *_scan_tool_row(con, root, r)) for r in data]
        if getattr(a, "json", False):
            print(json.dumps([{"name": n, "status": s, "detail": d} for n, s, d in results], indent=2))
        else:
            for n, s, d in results:
                print(f"  {n:<20} {s:<8} {d}")
        return 0
    if a.tool_cmd == "remove":
        cur = con.execute("DELETE FROM tool WHERE name=?", (a.name,)); con.commit()
        if cur.rowcount:
            print(f"PASS: tool '{a.name}' removed"); return 0
        print(f"FAIL: no tool named '{a.name}'"); return 1
    print(f"FAIL: unknown tool subcommand '{a.tool_cmd}'"); return 1


def cmd_intervention(con, a):
    iid = _db.insert(con, "intervention", trace_id=a.trace, story_id=a.story,
                     type=a.type, description=a.description, source=a.source, impact=a.impact)
    print(f"PASS: intervention #{iid} ({a.type} by {a.source})")
    return 0


def cmd_query(con, a):
    if a.query_cmd == "matrix":
        data = _db.rows(con, "SELECT id,title,risk_lane,status,unit_proof,integration_proof,"
                             "e2e_proof,platform_proof,last_verified_result FROM story ORDER BY id")
        if a.json:
            print(json.dumps(data, indent=2)); return 0
        if not data:
            print("(no stories yet)"); return 0
        b = (lambda v: ("1" if a.numeric else "yes") if v else ("0" if a.numeric else "no"))
        print(f"{'STORY':<10} {'LANE':<9} {'STATUS':<12} U I E P  VERIFY  TITLE")
        for s in data:
            print(f"{s['id']:<10} {s['risk_lane']:<9} {s['status']:<12} "
                  f"{b(s['unit_proof'])[:1]} {b(s['integration_proof'])[:1]} "
                  f"{b(s['e2e_proof'])[:1]} {b(s['platform_proof'])[:1]}  "
                  f"{(s['last_verified_result'] or '-'):<6}  {s['title']}")
        return 0
    if a.query_cmd == "backlog":
        where = ""
        if a.open:
            where = "WHERE status IN ('proposed','accepted')"
        elif a.closed:
            where = "WHERE status IN ('implemented','rejected')"
        data = _db.rows(con, f"SELECT * FROM backlog {where}")
        data = _order_by_reuse(data, lambda r: _is_security_text(r.get("title"), r.get("current_pain")))
        _touch_accessed(con, "backlog", [r["id"] for r in data])
        if a.json:
            print(json.dumps(data, indent=2)); return 0
        for x in data:
            print(f"  #{x['id']} [{x['status']}] {x['title']} -- pain: {x.get('current_pain') or '-'} "
                  f"| predicted: {x.get('predicted_impact') or '-'} | actual: {x.get('actual_outcome') or '-'}")
        if not data:
            print("(no backlog items)")
        return 0
    if a.query_cmd == "friction":
        data = _db.rows(con, "SELECT id,created_at,task_summary,harness_friction,accessed_count FROM trace "
                             "WHERE harness_friction IS NOT NULL AND harness_friction<>''")
        data = _order_by_reuse(data, lambda r: _is_security_text(r.get("task_summary"), r.get("harness_friction")))
        _touch_accessed(con, "trace", [r["id"] for r in data])
        if a.json:
            print(json.dumps(data, indent=2)); return 0
        for x in data:
            print(f"  trace #{x['id']}: {x['harness_friction']}  (task: {x['task_summary']})")
        if not data:
            print("(no friction recorded)")
        return 0
    if a.query_cmd == "tools":
        clauses, params = [], []
        if a.responsibility:
            clauses.append("responsibility = ?"); params.append(a.responsibility)
        if getattr(a, "capability", None):
            clauses.append("capability = ?"); params.append(D.normalize_capability(a.capability))
        if getattr(a, "status", None):
            clauses.append("status = ?"); params.append(a.status)
        where = ("WHERE " + " AND ".join(clauses)) if clauses else ""
        data = _db.rows(con, f"SELECT * FROM tool {where} ORDER BY name", tuple(params))
        if a.json:
            print(json.dumps(data, indent=2)); return 0
        for x in data:
            print(f"  {x['name']:<20} {(x.get('kind') or 'cli'):<7} {(x.get('status') or 'unknown'):<8} "
                  f"{(x.get('capability') or '-'):<22} {x['responsibility']}")
        if not data:
            print("(no tools registered)")
        return 0
    if a.query_cmd == "decisions":
        data = _db.rows(con, "SELECT id,title,status,predicted_impact,actual_outcome,accessed_count FROM decision")
        data = _order_by_reuse(data, lambda r: _is_security_text(r.get("title")))
        _touch_accessed(con, "decision", [r["id"] for r in data])
        if a.json:
            print(json.dumps(data, indent=2)); return 0
        for x in data:
            print(f"  {x['id']} [{x['status']}] {x['title']} "
                  f"| predicted: {x.get('predicted_impact') or '-'} | actual: {x.get('actual_outcome') or '-'}")
        if not data:
            print("(no decisions)")
        return 0


# ---- self-improvement: audit (entropy/drift) + propose (deterministic GRC loop) ----
# Ported from repository-harness (infrastructure.rs audit/propose, domain.rs entropy_score).
# Deterministic on purpose: mine REPEATED friction/interventions by count (>=2) — never an
# LLM guess (grounded > intrinsic). Proposals are advisory; --commit only adds backlog rows.

_AUDIT_QUERIES = {
    "orphaned_stories": ("orphaned planned/in-progress stories",
        "SELECT story.id, story.title FROM story LEFT JOIN trace ON trace.story_id=story.id "
        "WHERE story.status IN ('planned','in_progress') AND trace.id IS NULL ORDER BY story.id"),
    "unverified_stories": ("unverified story commands",
        "SELECT id, title FROM story WHERE verify_command IS NOT NULL AND TRIM(verify_command)<>'' "
        "AND last_verified_result IS NULL ORDER BY id"),
    "unverified_decisions": ("unverified decision commands",
        "SELECT id, title FROM decision WHERE verify_command IS NOT NULL AND TRIM(verify_command)<>'' "
        "AND last_verified_result IS NULL ORDER BY id"),
    "backlog_without_outcomes": ("implemented backlog items without outcomes",
        "SELECT CAST(id AS TEXT), title FROM backlog WHERE predicted_impact IS NOT NULL "
        "AND actual_outcome IS NULL AND status='implemented' ORDER BY id"),
    "stale_stories": ("stale unfinished stories (>30d since last trace)",
        "SELECT story.id, story.title FROM story JOIN trace ON trace.story_id=story.id "
        "WHERE story.status<>'implemented' GROUP BY story.id, story.title "
        "HAVING julianday('now')-julianday(MAX(trace.created_at))>30 ORDER BY story.id"),
}
_ENTROPY_WEIGHTS = {"orphaned_stories": 10, "unverified_stories": 5, "unverified_decisions": 5,
                    "backlog_without_outcomes": 2, "stale_stories": 3}


def _audit(con):
    findings = {k: _db.rows(con, sql) for k, (_label, sql) in _AUDIT_QUERIES.items()}
    score = min(100, sum(len(findings[k]) * _ENTROPY_WEIGHTS[k] for k in _AUDIT_QUERIES))
    return findings, score


def _normalize_token(s):
    return re.sub(r"[^a-z0-9]+", " ", str(s).lower()).strip()


def _repeated_values(values, threshold=2):
    """Group by normalized key, keep a representative + count; return those seen >= threshold."""
    grouped, order = {}, []
    for v in values:
        k = _normalize_token(v)
        if not k:
            continue
        if k in grouped:
            grouped[k][1] += 1
        else:
            grouped[k] = [v, 1]
            order.append(k)
    return [(grouped[k][0], grouped[k][1]) for k in order if grouped[k][1] >= threshold]


def _short_title(s, n=8):
    words = " ".join(str(s).split()[:n])
    return (words[:69] + "...") if len(words) > 72 else words


def _confidence_for_count(c):
    return "high" if c >= 3 else "medium"


def _repeated_friction(con):
    rows = _db.rows(con, "SELECT harness_friction AS f FROM trace WHERE harness_friction IS NOT NULL "
                         "AND TRIM(harness_friction)<>'' AND LOWER(TRIM(harness_friction))<>'none'")
    return _repeated_values([r["f"] for r in rows])


def _repeated_interventions(con):
    rows = _db.rows(con, "SELECT type || ': ' || description AS k FROM intervention WHERE TRIM(description)<>''")
    return _repeated_values([r["k"] for r in rows])


def _build_proposals(con):
    findings, _score = _audit(con)
    props = []
    for text, count in _repeated_friction(con):
        props.append(dict(title=f"Reduce repeated friction: {_short_title(text)}",
                          component="Failure attribution",
                          evidence=f"{count} traces recorded similar friction: {text}",
                          predicted_impact="Fewer repeated friction entries for similar tasks.",
                          risk="normal",
                          suggested="Update the relevant docs, templates, or guidance for this friction pattern.",
                          validation="Review the next five related traces and compare friction frequency.",
                          confidence=_confidence_for_count(count)))
    for key, count in _repeated_interventions(con):
        props.append(dict(title=f"Address repeated intervention: {_short_title(key)}",
                          component="Intervention recording",
                          evidence=f"{count} interventions share the pattern: {key}",
                          predicted_impact="Fewer repeated human/review interventions for the same issue.",
                          risk="normal",
                          suggested="Clarify the operating rule or gate that would have caught this earlier.",
                          validation="Future interventions of this type should decrease after the rule change.",
                          confidence=_confidence_for_count(count)))
    for stage, f, t, fc in _usage_gate_fail_stages(con):
        props.append(dict(title=f"Stage {stage} fails its gate often",
                          component=stage,
                          evidence=f"gate fail-rate {f}/{t} over {fc} cycles (mechanical usage log)",
                          predicted_impact="Fewer gate retries at this stage once its artifact/template is tightened.",
                          risk="normal",
                          suggested="Tighten this stage's artifact/template, or split the stage so its gate is honestly satisfiable.",
                          validation="Watch this stage's gate fail-rate in 'flow usage' over the next cycles.",
                          confidence="medium"))
    for key, (label, _sql) in _AUDIT_QUERIES.items():
        n = len(findings[key])
        if n > 0:
            props.append(dict(title=f"Clean up {label}", component="Entropy auditing",
                              evidence=f"Audit found {n} {label}.",
                              predicted_impact="Lower entropy score and stronger completion evidence.",
                              risk="tiny",
                              suggested="Resolve the listed audit findings or record why they are intentionally retained.",
                              validation="Run 'flow harness audit' and confirm the category count decreases.",
                              confidence="low"))
    return props


def cmd_audit(con, a):
    findings, score = _audit(con)
    print(f"flow-harness audit: entropy score {score}/100 (0 = clean, higher = more drift)")
    any_found = False
    for key, (label, _sql) in _AUDIT_QUERIES.items():
        rows = findings[key]
        if rows:
            any_found = True
            print(f"  {len(rows)} {label}:")
            for r in rows[:10]:
                vals = list(r.values())
                print(f"    - {vals[0]}: {vals[1] if len(vals) > 1 else ''}")
    if not any_found:
        print("  no drift findings - clean.")
    return 0


def cmd_propose(con, a):
    props = _build_proposals(con)
    if not props:
        print("flow-harness propose: no repeated friction/interventions or audit drift yet - nothing to propose.")
        return 0
    mode = "committing to backlog" if a.commit else "dry-run; pass --commit to add to backlog"
    print(f"flow-harness propose: {len(props)} improvement proposal(s) from accumulated signal ({mode})")
    for p in props:
        print(f"  [{p['confidence']}] {p['title']}")
        print(f"      evidence: {p['evidence']}")
        print(f"      suggest:  {p['suggested']}")
        if a.commit:
            bid = _db.insert(con, "backlog", title=p["title"], discovered_while="flow harness propose",
                             current_pain=p["evidence"], suggested_improvement=p["suggested"],
                             risk=p["risk"], predicted_impact=p["predicted_impact"],
                             notes=f"component: {p['component']}; confidence: {p['confidence']}; validation: {p['validation']}")
            print(f"      -> backlog #{bid}")
    return 0


def _now(con):
    return con.execute("SELECT datetime('now')").fetchone()[0]


# ---------------- usage-log rollup + stats (schema 006) ----------------
# JSONL sinks are the source of truth; usage_event is a derived, queryable mirror.
# Idempotency rests on UNIQUE(src,line_no); rollup_cursor skips already-seen lines.

USAGE_COLS = ("epoch_s", "session_id", "cycle_id", "project", "command", "args",
              "exit_code", "gate_pass", "duration_s", "stage_from", "stage_to", "card",
              "project_type", "mode", "flow_version", "tier", "host", "read_only",
              "gate_fail_reason", "ephemeral")


def _events_path(a):
    return os.path.join(os.path.dirname(a._db_path), "events.jsonl")


def _global_log_path():
    return os.path.join(os.path.expanduser("~"), ".claude", "flow", "usage.jsonl")


def _coerce_event(o):
    row = {c: o.get(c) for c in USAGE_COLS}
    for k in ("gate_pass", "read_only", "ephemeral"):
        v = row.get(k)
        if isinstance(v, bool):
            row[k] = 1 if v else 0
        # JSON null -> None (non-gate command); ints pass through
    return row


def cmd_rollup(con, a):
    srcs = [_events_path(a)]
    if getattr(a, "global_", False):
        srcs.append(_global_log_path())
    rolled = skipped = 0
    cols = ["src", "line_no"] + list(USAGE_COLS)
    ph = ",".join("?" for _ in cols)
    for src in srcs:
        if not os.path.isfile(src):
            continue
        cur = con.execute("SELECT last_line FROM rollup_cursor WHERE src=?", (src,)).fetchone()
        last = cur[0] if cur else 0
        # errors="replace": a single invalid byte anywhere in a shared, multi-writer log must
        # not abort the WHOLE rollup - it degrades to a per-line json.loads failure below
        # instead (one bad row skipped, not every row on the file).
        with open(src, "r", encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        lines = text.split("\n")
        lines = lines[:-1]  # drop trailing empty (after final \n) or a partial unterminated last line
        n = 0
        total = len(lines)
        cursor_advance = last
        for line in lines:
            n += 1
            if n <= last:
                continue
            s = line.strip()
            if not s:
                cursor_advance = n
                continue
            try:
                o = json.loads(s)
            except ValueError:
                skipped += 1
                # A torn line can only be the CURRENT final line of the file (an EXIT-trap
                # append still in flight) - any earlier malformed line is real corruption, not
                # a race, so it is skipped and the cursor still advances past it. The final
                # line's cursor is held so a completing append is retried on the next rollup
                # rather than being permanently skipped once `n` reaches it.
                if n == total:
                    break
                cursor_advance = n
                continue
            row = _coerce_event(o)
            vals = [src, n] + [row[c] for c in USAGE_COLS]
            c2 = con.execute(f"INSERT OR IGNORE INTO usage_event ({','.join(cols)}) VALUES ({ph})", vals)
            if c2.rowcount and c2.rowcount > 0:
                rolled += 1
            cursor_advance = n
        # advance the cursor monotonically only (never reset backward, e.g. when a sink is
        # truncated/empty on re-read) — correctness rests on UNIQUE(src,line_no) regardless.
        if cursor_advance > last:
            con.execute("INSERT INTO rollup_cursor(src,last_line,updated_at) VALUES(?,?,datetime('now')) "
                        "ON CONFLICT(src) DO UPDATE SET last_line=excluded.last_line, updated_at=excluded.updated_at",
                        (src, cursor_advance))
    con.commit()
    print(json.dumps({"rolled": rolled, "skipped": skipped}))
    return 0


def cmd_usage(con, a):
    src = _global_log_path() if getattr(a, "global_", False) else _events_path(a)
    w = "WHERE src=?"
    # Default-exclude throwaway/test runs so the view reflects real builds. COALESCE handles old
    # rows (ephemeral NULL -> 0); the project-name fallback excludes legacy `tmp.*` runs that
    # predate the field (no log rewrite). `--include-ephemeral` shows everything.
    if not getattr(a, "include_ephemeral", False):
        w += " AND NOT (COALESCE(ephemeral,0)=1 OR project LIKE 'tmp.%')"
    pr = (src,)
    total = con.execute(f"SELECT COUNT(*) FROM usage_event {w}", pr).fetchone()[0]
    if not total:
        if not getattr(a, "summary", False):   # --summary stays silent on no data (recall appends nothing)
            print(f"usage: no events yet for {src}")
            print("  (run some flow commands first, then 'flow usage')")
        return 0
    g = con.execute(f"SELECT COUNT(*), SUM(CASE WHEN gate_pass=0 THEN 1 ELSE 0 END) FROM usage_event "
                    f"{w} AND command IN ('next','check') AND gate_pass IS NOT NULL", pr).fetchone()
    gate_total, gate_fail = (g[0] or 0), (g[1] or 0)
    fail_rate = (100.0 * gate_fail / gate_total) if gate_total else 0.0
    cyc = con.execute(f"SELECT cycle_id, MAX(epoch_s)-MIN(epoch_s) FROM usage_event "
                      f"{w} AND cycle_id<>'' GROUP BY cycle_id", pr).fetchall()
    cycles_started = len(cyc)
    build_cycles, diag_cycles = _count_build_cycles(con, w, pr)
    times = sorted(r[1] for r in cyc if r[1] is not None)
    reached = con.execute(f"SELECT COUNT(DISTINCT cycle_id) FROM usage_event "
                          f"{w} AND cycle_id<>'' AND (card<>'' OR command='card')", pr).fetchone()[0]
    dwell = con.execute(f"SELECT stage_to, COUNT(*), AVG(duration_s) FROM usage_event "
                        f"{w} AND command='next' AND stage_to<>'' GROUP BY stage_to ORDER BY stage_to", pr).fetchall()
    # Wall-clock time spent IN each stage, reconstructed from stage transitions: a `next` event's
    # epoch is the moment you LEFT stage_from / ENTERED stage_to. dwell(S) = (exit S) - (enter S),
    # per cycle, averaged across cycles. Unlike duration_s (the runner's own exec time ~1-2s) this
    # is real lead-time and answers "where do builds stall". Abandoned stages (no exit) are skipped.
    #
    # Legacy rows (pre-fix compact global lines) lack stage_from. Best-effort: infer it from the
    # preceding row's stage_to, partitioned strictly by (project, cycle_id) ordered by epoch_s.
    # Where a real stage_from exists it always wins; inference fires only when the field is absent.
    # Inferred dwell is approximate (re-entries / idle gaps acknowledged); exact rows are unaffected.
    trans = con.execute(f"SELECT cycle_id, project, stage_from, stage_to, epoch_s FROM usage_event "
                        f"{w} AND command='next' AND cycle_id<>'' AND epoch_s IS NOT NULL "
                        f"ORDER BY project, cycle_id, epoch_s", pr).fetchall()
    _prev_stage_to: dict = {}   # key=(project, cycle_id) -> stage_to of last processed row
    _enter, _exit = {}, {}      # key=(project, cycle_id) to prevent cross-project bleed on --global
    _dwell_inference_fired = False  # True when any row lacked a real stage_from (legacy pre-v0.12)
    for cyc_id, proj_name, sf, st, es in trans:
        pkey = (proj_name or "", cyc_id)
        # Infer stage_from from prior row's stage_to when the field is absent (legacy compact rows).
        sf_effective = sf if sf else _prev_stage_to.get(pkey)
        if not sf and sf_effective:
            _dwell_inference_fired = True
        _prev_stage_to[pkey] = st if st else _prev_stage_to.get(pkey)
        if st:
            _enter.setdefault(pkey, {}).setdefault(st, es)   # first entry into st
        if sf_effective:
            _exit.setdefault(pkey, {})[sf_effective] = es    # last exit from sf_effective
    _wall = {}
    for pkey, stages in _enter.items():
        for stg, ein in stages.items():
            eout = _exit.get(pkey, {}).get(stg)
            if eout is not None and eout >= ein:
                _wall.setdefault(stg, []).append(eout - ein)
    stage_wall = sorted((stg, len(v), sum(v) / len(v)) for stg, v in _wall.items())
    def _dur(s):
        s = int(s)
        if s >= 86400: return f"{s/86400:.1f}d"
        if s >= 3600:  return f"{s/3600:.1f}h"
        if s >= 60:    return f"{s/60:.1f}m"
        return f"{s}s"
    cmds = con.execute(f"SELECT command, COUNT(*) FROM usage_event {w} GROUP BY command ORDER BY COUNT(*) DESC", pr).fetchall()
    med = times[len(times) // 2] if times else 0
    if getattr(a, "summary", False):   # one compact line for `recall` to append
        tf = con.execute(f"SELECT stage_to, SUM(CASE WHEN gate_pass=0 THEN 1 ELSE 0 END) AS f, COUNT(*) AS t "
                         f"FROM usage_event {w} AND command IN ('next','check') AND stage_to<>'' AND gate_pass IS NOT NULL "
                         f"GROUP BY stage_to HAVING f>0 ORDER BY f DESC LIMIT 1", pr).fetchone()
        tfs = f"{tf[0]}({tf[1]}/{tf[2]})" if tf else "none"
        print(f"USAGE (mechanical log): cycles={cycles_started} build-intent={build_cycles} diagnostic-only={diag_cycles} reached-cards={reached} "
              f"| cycle-time s min/med/max={times[0] if times else 0}/{med}/{times[-1] if times else 0} "
              f"| gate fail-rate={fail_rate:.0f}% | top-fail-stage={tfs}")
        return 0
    # per-card dwell (wall-clock): time from an operator-marked 'card start' to the card's
    # successful 'card done'. Both are command='card'; the verb lives in args ('start C-NNN' /
    # 'done C-NNN'). Pair the earliest start with the latest SUCCESSFUL done per (project, cycle,
    # card). Cards finished by hand-edit + '/flow check' (no 'card done' event) have no pair — the
    # metric covers verb-tracked cards only. A failed/reverted 'card done' (exit_code != 0) is not
    # a completion, so it never closes a dwell. Works under --global too as of v0.20 Phase 1: the
    # compact global JSONL line now carries card/args for command=card rows (previously omitted,
    # which made --global dwell permanently blind) - rows written before v0.20 still lack these
    # fields and simply yield no pair, which is why the "no pairs yet" branch below is worded as
    # a capability statement, not a claim that --global can never show dwell.
    _crows = con.execute(
        f"SELECT project, cycle_id, card, args, exit_code, epoch_s FROM usage_event "
        f"{w} AND command='card' AND card<>'' AND epoch_s IS NOT NULL "
        f"AND (args LIKE 'start%' OR args LIKE 'done%') ORDER BY epoch_s", pr).fetchall()
    _cstart, _cdone = {}, {}
    for _proj, _cyc, _card, _cargs, _cec, _ces in _crows:
        _ckey = (_proj or "", _cyc or "", _card)
        _act = (_cargs or "").strip().lower()
        if _act.startswith("start"):
            _cstart.setdefault(_ckey, _ces)          # earliest start (rows are epoch-ordered)
        elif _act.startswith("done") and (_cec == 0):
            _cdone[_ckey] = _ces                      # latest successful done
    card_dwell = sorted(
        (k[2], _cdone[k] - t0) for k, t0 in _cstart.items()
        if k in _cdone and _cdone[k] >= t0)
    # optional --builds-only: restrict cycle timing metrics to build cycles only
    builds_only = getattr(a, "builds_only", False)
    if builds_only and build_cycles < cycles_started:
        # Identify build cycle_ids from the already-fetched _count_build_cycles data.
        # Re-query to get per-cycle timing for build cycles only.
        cycle_rows = con.execute(
            f"SELECT cycle_id, read_only, command, MAX(epoch_s)-MIN(epoch_s) AS dur "
            f"FROM usage_event {w} AND cycle_id<>'' GROUP BY cycle_id",
            pr
        ).fetchall()
        # For each cycle, check if any event in it is non-read_only.
        # We use the already-computed cycle event classification via _count_build_cycles logic
        # but here per-cycle (need per-cycle decision).
        # Efficient: aggregate read_only flag per cycle from the JSONL-derived table.
        build_times = []
        for row in cycle_rows:
            cid, ro, cmd, dur = row
            # Check if this cycle has any build event: query its events
            # (small: cycles typically have few events)
            cycle_evs = con.execute(
                f"SELECT read_only, command FROM usage_event {w} AND cycle_id=?",
                list(pr) + [cid]
            ).fetchall()
            if any(not _is_readonly_event(ro_e, cmd_e) for ro_e, cmd_e in cycle_evs):
                if dur is not None:
                    build_times.append(dur)
        times_display = sorted(build_times)
        med_display = times_display[len(times_display) // 2] if times_display else 0
        display_count = build_cycles
    else:
        times_display, med_display, display_count = times, med, cycles_started
    if getattr(a, "json", False):
        print(json.dumps({
            "src": src, "events_total": total,
            "gate_fail_rate_pct": round(fail_rate, 1), "gate_fail": gate_fail, "gate_total": gate_total,
            "cycles_started": cycles_started,
            "cycles_build_intent": build_cycles,
            "cycles_diagnostic_only": diag_cycles,
            "cycles_reached_cards": reached,
            "cycle_time_s": {"min": times_display[0] if times_display else 0, "median": med_display, "max": times_display[-1] if times_display else 0},
            "stage_exec_time": [{"stage": s, "n": c, "avg_s": round(v or 0, 1)} for s, c, v in dwell],
            "stage_dwell": [{"stage": s, "n": c, "avg_s": round(v, 1)} for s, c, v in stage_wall],
            "card_dwell": [{"card": c, "s": round(s, 1)} for c, s in card_dwell],
            "commands": [{"command": c, "n": n} for c, n in cmds],
        }))
        return 0
    print(f"flow usage - {src}")
    print(f"  events total:         {total}")
    print(f"  gate fail-rate:       {fail_rate:.0f}%  ({gate_fail}/{gate_total} next|check failed)")
    print(f"  cycles started:       {cycles_started}   (build-intent: {build_cycles} · diagnostic-only: {diag_cycles})")
    print(f"  cycles reached cards: {reached}  (abandonment proxy: {cycles_started - reached} not yet at cards)")
    if times_display:
        _ct_label = "build cycles" if builds_only and build_cycles < cycles_started else "cycles"
        print(f"  cycle-time (s) [{display_count} {_ct_label}]: min={times_display[0]} median={med_display} max={times_display[-1]}")
    print("  per-stage command exec time (avg duration_s of 'next' - runner overhead, NOT lead-time):")
    for s, c, v in dwell:
        print(f"    {s:<12} n={c} avg={(v or 0):.0f}s")
    _dwell_hdr = ("  per-stage dwell (wall-clock; ~approx for pre-v0.12 global rows):"
                  if _dwell_inference_fired else
                  "  per-stage dwell (wall-clock: avg real time spent IN the stage, from transitions):")
    print(_dwell_hdr)
    if stage_wall:
        for s, c, v in stage_wall:
            print(f"    {s:<12} n={c} avg={_dur(v)}")
    else:
        print("    (no completed stage transitions yet)")
    print("  per-card dwell (wall-clock: 'card start' -> successful 'card done'):")
    if card_dwell:
        for c, s in card_dwell:
            print(f"    {c:<12} {_dur(s)}")
    elif getattr(a, "global_", False):
        print("    (per-card dwell requires rows written by flow >= 0.20 - older rows in this log predate the card/args fields)")
    else:
        print("    (no card start->done pairs yet - mark cards with '/flow card start|done')")
    print("  commands:")
    for c, n in cmds:
        print(f"    {c:<12} {n}")
    return 0


# C-012: READ-TIME build-intent classification (FR2 logging is UNCHANGED; this is rollup-only).
# A cycle is a build cycle iff it has >=1 non-read_only event.
# Primary: use the already-logged `read_only` field.
# Fallback (legacy rows lacking the field): classify by command name via the same allowlist
# that _log_is_readonly in flow.sh uses: status|recall|ready|usage|tokens|coherence|
# consistency|contract|constitution|doctor|design|help are read-only; everything else is not.
_READONLY_CMDS = frozenset({
    "status", "recall", "ready", "usage", "tokens", "coherence",
    "consistency", "contract", "constitution", "doctor", "design", "help",
    "-h", "--help", "",
})


def _is_readonly_event(ro, cmd):
    """Return True iff this usage event is read-only (no build mutation).
    ro: the read_only column value (1/0/True/False/None); cmd: the command string.
    Primary: use `ro` when present. Fallback for legacy rows (ro=None): classify by command name.
    """
    if ro is not None:
        # Already logged: 1/True = read_only, 0/False = not read_only
        return bool(ro)
    # Legacy row: COALESCE by command name
    return (cmd or "").strip().lower() in _READONLY_CMDS


def _count_build_cycles(con, where_clause, params):
    """Count build cycles (>=1 non-read_only event) and diagnostic-only cycles.
    Retroactive: works on legacy rows lacking read_only via command-name COALESCE.
    Returns (build_count, diagnostic_count).
    """
    rows = con.execute(
        f"SELECT cycle_id, read_only, command FROM usage_event "
        f"{where_clause} AND cycle_id<>''",
        params
    ).fetchall()
    # Group events by cycle_id; a cycle is build-intent if any event is non-read_only.
    cycle_has_build: dict = {}   # cycle_id -> bool
    for cid, ro, cmd in rows:
        if cid not in cycle_has_build:
            cycle_has_build[cid] = False
        if not _is_readonly_event(ro, cmd):
            cycle_has_build[cid] = True
    build_count = sum(1 for v in cycle_has_build.values() if v)
    diag_count = sum(1 for v in cycle_has_build.values() if not v)
    return build_count, diag_count


def _usage_gate_fail_stages(con):
    """Stages whose gate fails often (>=50%) across >=2 distinct cycles — the usage->propose signal.
    Heuristic, surfaced for the operator to commit (never auto-applied)."""
    try:
        rows = con.execute(
            "SELECT stage_to, SUM(CASE WHEN gate_pass=0 THEN 1 ELSE 0 END) AS f, COUNT(*) AS t, "
            "       COUNT(DISTINCT CASE WHEN gate_pass=0 THEN cycle_id END) AS fc "
            "FROM usage_event WHERE command IN ('next','check') AND stage_to<>'' AND gate_pass IS NOT NULL "
            "GROUP BY stage_to").fetchall()
    except sqlite3.Error:
        return []
    out = []
    for stage, f, t, fc in rows:
        if t and (f / t) >= 0.5 and (fc or 0) >= 2:
            out.append((stage, f, t, fc))
    return out


def cmd_prune(con, a):
    """Cap each JSONL sink to its last N lines, crash-safe (temp + os.replace). Pruning renumbers
    lines, so the usage_event mirror + rollup_cursor for that sink are reset to rebuild cleanly."""
    keep = getattr(a, "keep", None) or 5000
    srcs = [_events_path(a)]
    if getattr(a, "global_", False):
        srcs.append(_global_log_path())
    for src in srcs:
        if not os.path.isfile(src):
            print(json.dumps({"sink": src, "kept": 0, "dropped": 0, "note": "absent"}))
            continue
        # errors="replace": same shared, multi-writer file `cmd_rollup` was hardened against
        # (v0.20 Phase 1) - a single invalid byte here must not crash prune either.
        with open(src, "r", encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
        if len(lines) <= keep:
            print(json.dumps({"sink": src, "kept": len(lines), "dropped": 0}))
            continue
        kept = lines[-keep:]
        tmp = src + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.writelines(kept)
        os.replace(tmp, src)            # atomic on the same filesystem
        # line numbers changed -> the mirror + cursor for this sink are stale; reset so the next
        # rollup re-ingests the kept lines as line_no 1..K (UNIQUE(src,line_no) stays consistent).
        con.execute("DELETE FROM usage_event WHERE src=?", (src,))
        con.execute("DELETE FROM rollup_cursor WHERE src=?", (src,))
        con.commit()
        print(json.dumps({"sink": src, "kept": len(kept), "dropped": len(lines) - len(kept)}))
    if getattr(a, "global_", False):
        # the global sink is shared: only THIS project's db cursor/mirror was reset. Any other
        # project that ran `rollup --global` keeps a stale cursor + phantom rows for it until reset.
        sys.stderr.write("note: pruned the device-global log; other projects that rolled it up should "
                         "reset it too (run a rollup after deleting their rollup_cursor row for that path).\n")
    return 0


# ---------------- arg parsing ----------------

def build_parser():
    p = argparse.ArgumentParser(prog="flow_harness.py", description="flow durable harness layer")
    p.add_argument("--db", help="sqlite db path (default <FLOW_PROJECT_ROOT>/.flow/harness.db)")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("init", help="create/upgrade the harness db")

    pi = sub.add_parser("intake", help="classify incoming work + choose risk lane")
    pi.add_argument("--type", required=True, choices=D.INPUT_TYPES)
    pi.add_argument("--summary", required=True)
    pi.add_argument("--flags", help="comma list: " + ",".join(D.RISK_FLAGS))
    pi.add_argument("--lane", choices=D.LANES, help="override recommended lane")
    pi.add_argument("--narrow-scope", dest="narrow_scope", action="store_true",
                    help="operator acceptance required to downgrade a hard-gate high_risk lane")
    pi.add_argument("--removing-validation", dest="removing_validation", action="store_true")
    pi.add_argument("--code-impact-high", dest="code_impact_high", action="store_true")
    pi.add_argument("--docs"); pi.add_argument("--story"); pi.add_argument("--notes")

    ps = sub.add_parser("story", help="story packets + proof status")
    pss = ps.add_subparsers(dest="story_cmd", required=True)
    a1 = pss.add_parser("add"); a1.add_argument("--id", required=True); a1.add_argument("--title", required=True)
    a1.add_argument("--lane", required=True, choices=D.LANES); a1.add_argument("--contract"); a1.add_argument("--verify")
    a2 = pss.add_parser("update"); a2.add_argument("--id", required=True); a2.add_argument("--status", choices=D.STORY_STATUSES)
    for f in ("unit", "integration", "e2e", "platform"):
        a2.add_argument(f"--{f}", type=int, choices=(0, 1))
    a2.add_argument("--evidence")
    a3 = pss.add_parser("verify"); a3.add_argument("--id", required=True)
    pss.add_parser("verify-all")
    # flow-native complete (trust-align D7): not protocol-v1 positional parity
    ac = pss.add_parser("complete", help="mark implemented with honest proof_source (not bare update)")
    ac.add_argument("--id", required=True)
    ac.add_argument("--proof-source", dest="proof_source",
                    choices=("card_markdown_gate", "manual", "verify_command"),
                    help="card_markdown_gate never forges last_verified=pass")
    ac.add_argument("--evidence")

    pt = sub.add_parser("trace", help="record an agent task execution trace (auto-scored)")
    pt.add_argument("--summary", required=True); pt.add_argument("--intake", type=int); pt.add_argument("--story", "--card")
    # Accept the natural underscore variants + --card as a --story alias: agents in the wild
    # (real CMC/C2-App-001 logs) typed --actions_taken/--files_changed/--files_read/--card and lost
    # the trace to argparse exit-2. These aliases make those calls succeed instead of silently dropping.
    pt.add_argument("--agent"); pt.add_argument("--actions", "--actions_taken")
    pt.add_argument("--files-read", "--files_read", dest="files_read")
    pt.add_argument("--files-changed", "--files_changed", dest="files_changed"); pt.add_argument("--decisions"); pt.add_argument("--errors")
    pt.add_argument("--outcome", choices=D.TRACE_OUTCOMES); pt.add_argument("--duration", type=int)
    pt.add_argument("--tokens", type=int); pt.add_argument("--friction"); pt.add_argument("--notes")
    pt.add_argument("--lane", choices=D.LANES, help="lane hint when no --story")

    pd = sub.add_parser("decision", help="durable decision records")
    pds = pd.add_subparsers(dest="decision_cmd", required=True)
    d1 = pds.add_parser("add"); d1.add_argument("--id", required=True); d1.add_argument("--title", required=True)
    d1.add_argument("--doc"); d1.add_argument("--status", choices=D.DECISION_STATUSES); d1.add_argument("--verify")
    d1.add_argument("--predicted")
    d2 = pds.add_parser("verify"); d2.add_argument("--id", required=True)
    d3 = pds.add_parser("outcome"); d3.add_argument("--id", required=True)
    d3.add_argument("--actual", required=True); d3.add_argument("--status", choices=D.DECISION_STATUSES)

    pb = sub.add_parser("backlog", help="growth-rule improvement loop")
    pbs = pb.add_subparsers(dest="backlog_cmd", required=True)
    b1 = pbs.add_parser("add"); b1.add_argument("--title", required=True); b1.add_argument("--pain")
    b1.add_argument("--discovered-while", dest="discovered_while"); b1.add_argument("--suggested")
    b1.add_argument("--predicted"); b1.add_argument("--risk", choices=D.LANES)
    b2 = pbs.add_parser("close"); b2.add_argument("--id", type=int, required=True); b2.add_argument("--outcome", required=True)
    b2.add_argument("--status", choices=D.BACKLOG_STATUSES, default="implemented")

    ptl = sub.add_parser("tool", help="kind-aware inbound tool/capability registry"); ptl_s = ptl.add_subparsers(dest="tool_cmd", required=True)
    tr = ptl_s.add_parser("register"); tr.add_argument("--name", required=True); tr.add_argument("--command", required=True)
    tr.add_argument("--description", required=True); tr.add_argument("--responsibility", required=True); tr.add_argument("--args")
    tr.add_argument("--kind", choices=D.TOOL_KINDS, default="cli", help="cli|binary|mcp|skill|http")
    tr.add_argument("--capability", help="workflow purpose, kebab-cased (e.g. edge-case-expansion)")
    tr.add_argument("--scan-target", dest="scan_target", help="path/URL probed for presence (mcp|skill|http)")
    tc = ptl_s.add_parser("check", help="probe registered tools' presence; persist status + checked_at")
    tc.add_argument("--name"); tc.add_argument("--json", action="store_true")
    trm = ptl_s.add_parser("remove"); trm.add_argument("--name", required=True)

    pv = sub.add_parser("intervention", help="record a human/reviewer/ci/agent override")
    # --note is an additive alias for --description (both set a.description; eases the verb-grammar friction)
    pv.add_argument("--type", required=True, choices=D.INTERVENTION_TYPES); pv.add_argument("--description", "--note", required=True)
    pv.add_argument("--source", required=True, choices=D.INTERVENTION_SOURCES); pv.add_argument("--trace", type=int)
    pv.add_argument("--story"); pv.add_argument("--impact")

    pq = sub.add_parser("query", help="read durable state")
    pqs = pq.add_subparsers(dest="query_cmd", required=True)
    q1 = pqs.add_parser("matrix"); q1.add_argument("--json", action="store_true"); q1.add_argument("--numeric", action="store_true")
    q2 = pqs.add_parser("backlog"); q2.add_argument("--open", action="store_true"); q2.add_argument("--closed", action="store_true"); q2.add_argument("--json", action="store_true")
    q3 = pqs.add_parser("friction"); q3.add_argument("--json", action="store_true")
    q4 = pqs.add_parser("tools"); q4.add_argument("--responsibility"); q4.add_argument("--json", action="store_true")
    q4.add_argument("--capability"); q4.add_argument("--status", choices=D.TOOL_STATUSES)
    q5 = pqs.add_parser("decisions"); q5.add_argument("--json", action="store_true")

    sub.add_parser("audit", help="entropy/drift audit: orphaned/unverified/stale records + a 0-100 score")
    pp = sub.add_parser("propose", help="deterministic improvement proposals from repeated friction/interventions + audit drift")
    pp.add_argument("--commit", action="store_true", help="write the proposals into the backlog (else dry-run)")

    pr = sub.add_parser("rollup", help="ingest JSONL usage sinks into usage_event (idempotent)")
    pr.add_argument("--global", dest="global_", action="store_true", help="also roll up the device-global log")
    pu = sub.add_parser("usage", help="print usage analytics from usage_event")
    pu.add_argument("--global", dest="global_", action="store_true", help="read the device-global log instead of this project")
    pu.add_argument("--json", action="store_true")
    pu.add_argument("--include-ephemeral", dest="include_ephemeral", action="store_true",
                    help="include throwaway/test runs (temp-dir or tmp.* projects), excluded by default")
    pu.add_argument("--summary", action="store_true", help="one compact line (for `recall` to append); silent on no data")
    pu.add_argument("--builds-only", dest="builds_only", action="store_true",
                    help="filter cycle timing metrics to build-intent cycles only (excludes diagnostic-only)")
    ppr = sub.add_parser("prune", help="cap each JSONL sink to its last N lines (crash-safe; resets the mirror for that sink)")
    ppr.add_argument("--keep", type=int, help="lines to keep (default 5000)")
    ppr.add_argument("--global", dest="global_", action="store_true", help="also prune the device-global log")
    return p


def main(argv):
    forwarded = _maybe_forward_to_rust(argv)
    if forwarded is not None:
        return forwarded
    try:
        a = build_parser().parse_args(argv)
    except SystemExit as e:
        # argparse exits 2 on a bad/missing flag, having printed a terse usage line. In real use
        # (CMC/C2-App-001 logs) that silently dropped durable decisions/traces. Add a guiding hint
        # of the common forms so the failure is actionable, then preserve argparse's exit code.
        if e.code not in (None, 0):
            sys.stderr.write(
                "flow-harness: command not accepted. Common forms (flags accept - or _; --card = --story):\n"
                "  intake   --type <new_spec|bug|chore|...> --summary \"...\" [--flags auth,data_model]\n"
                "  story    add --id C-NNN --title \"...\" --lane <normal|high_risk|...>\n"
                "  trace    --summary \"...\" [--story C-NNN] [--agent X] [--actions \"...\"] [--files-changed \"...\"] [--outcome completed]\n"
                "  decision add --id <slug> --title \"...\" [--doc flow/04-adr.md]\n"
                "see harness/README.md for the full contract.\n"
            )
        raise
    con = _db.connect(db_path=a.db)
    a._db_path = a.db or _db.default_db_path()
    dispatch = {
        "init": cmd_init, "intake": cmd_intake, "story": cmd_story, "trace": cmd_trace,
        "decision": cmd_decision, "backlog": cmd_backlog, "tool": cmd_tool,
        "intervention": cmd_intervention, "query": cmd_query,
        "audit": cmd_audit, "propose": cmd_propose,
        "rollup": cmd_rollup, "usage": cmd_usage, "prune": cmd_prune,
    }
    try:
        return dispatch[a.cmd](con, a) or 0
    except sqlite3.IntegrityError as e:
        sys.stderr.write(f"flow-harness: {e} (already exists?)\n")
        return 1
    except sqlite3.Error as e:
        sys.stderr.write(f"flow-harness: db error: {e}\n")
        return 1
    finally:
        con.close()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

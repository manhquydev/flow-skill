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


def _maybe_forward_to_rust(argv):
    if os.environ.get("FLOW_HARNESS_BACKEND", "python").lower() != "rust":
        return None
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


def cmd_story(con, a):
    if a.story_cmd == "add":
        if a.lane not in D.LANES:
            print("FAIL: --lane must be tiny|normal|high_risk"); return 1
        _db.insert(con, "story", id=a.id, title=a.title, risk_lane=a.lane,
                   contract_doc=a.contract, verify_command=a.verify)
        print(f"PASS: story {a.id} added (lane={a.lane})")
        return 0
    if a.story_cmd == "update":
        n = _db.update(con, "story", "id", a.id, status=a.status,
                       unit_proof=a.unit, integration_proof=a.integration,
                       e2e_proof=a.e2e, platform_proof=a.platform, evidence=a.evidence)
        print(f"{'PASS' if n else 'FAIL'}: story {a.id} {'updated' if n else 'not found'}")
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


def cmd_tool(con, a):
    if a.tool_cmd != "register":
        print(f"FAIL: unknown tool subcommand '{a.tool_cmd}'"); return 1
    _db.insert(con, "tool", name=a.name, command=a.command, description=a.description,
               responsibility=a.responsibility, args=a.args)
    print(f"PASS: tool '{a.name}' registered ({a.responsibility})")
    return 0


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
        where, params = "", ()
        if a.responsibility:
            where, params = "WHERE responsibility = ?", (a.responsibility,)
        data = _db.rows(con, f"SELECT * FROM tool {where} ORDER BY name", params)
        if a.json:
            print(json.dumps(data, indent=2)); return 0
        for x in data:
            print(f"  {x['name']:<20} {x['responsibility']:<22} {x['description']}")
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

    pt = sub.add_parser("trace", help="record an agent task execution trace (auto-scored)")
    pt.add_argument("--summary", required=True); pt.add_argument("--intake", type=int); pt.add_argument("--story")
    pt.add_argument("--agent"); pt.add_argument("--actions"); pt.add_argument("--files-read", dest="files_read")
    pt.add_argument("--files-changed", dest="files_changed"); pt.add_argument("--decisions"); pt.add_argument("--errors")
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

    ptl = sub.add_parser("tool", help="register a user/project tool"); ptl_s = ptl.add_subparsers(dest="tool_cmd", required=True)
    tr = ptl_s.add_parser("register"); tr.add_argument("--name", required=True); tr.add_argument("--command", required=True)
    tr.add_argument("--description", required=True); tr.add_argument("--responsibility", required=True); tr.add_argument("--args")

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
    q4 = pqs.add_parser("tools"); q4.add_argument("--responsibility"); q4.add_argument("--json", action="store_true"); q4.add_argument("--summary", action="store_true")
    q5 = pqs.add_parser("decisions"); q5.add_argument("--json", action="store_true")

    sub.add_parser("audit", help="entropy/drift audit: orphaned/unverified/stale records + a 0-100 score")
    pp = sub.add_parser("propose", help="deterministic improvement proposals from repeated friction/interventions + audit drift")
    pp.add_argument("--commit", action="store_true", help="write the proposals into the backlog (else dry-run)")
    return p


def main(argv):
    forwarded = _maybe_forward_to_rust(argv)
    if forwarded is not None:
        return forwarded
    a = build_parser().parse_args(argv)
    con = _db.connect(db_path=a.db)
    a._db_path = a.db or _db.default_db_path()
    dispatch = {
        "init": cmd_init, "intake": cmd_intake, "story": cmd_story, "trace": cmd_trace,
        "decision": cmd_decision, "backlog": cmd_backlog, "tool": cmd_tool,
        "intervention": cmd_intervention, "query": cmd_query,
        "audit": cmd_audit, "propose": cmd_propose,
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

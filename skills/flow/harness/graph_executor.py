"""Graph executor: record/advance API over the 014 schema (stdlib only).

There is NO resident process. Each call is a short-lived invocation that records
evidence or computes next-steps from topology + journal; the LLM agent and flow.sh
own all sequencing and all LLM work. Exit contract (fail-closed, consumed by
flow.sh `harness_capture_checked`):
  0 = value on stdout / success
  3 = definitive no-next (complete) or paused on an open interrupt
  4 = harness unavailable / contradictory flags (FLOW_HARNESS_DISABLE set)
  1/2 = failure
Security-class interrupt resolution enforces the out-of-band DEBT-commit artifact
(closed-set target, captured DEBT line, committed provenance via HEAD blob + blame)
with resolved_by + session id stored as AUDIT evidence. Documented residual limit:
git authorship is forgeable by an agent with git-config control.
"""

import json
import os
import re
import sqlite3
import subprocess
import sys
import time

import _db
import graph_ids

# Mirrors flow.sh cmd_skip's security-class regex (flow.sh:1242) - keep in sync.
SECURITY_RE = re.compile(
    r"auth|authoriz|authorize|admin|tenan|payment|billing|password|token|secret|"
    r"credential|permission|role|rbac|login|pii|data loss|migration|validation",
    re.IGNORECASE,
)
# Closed-set interrupt targets: a card id or a stage name. Validated BEFORE any
# file/git lookup so no free-form text ever reaches a match pattern.
TARGET_RE = re.compile(r"^C-[0-9]{1,4}$|^[0-9]{2}-[a-z-]+$")

NODE_TYPES = {"gate_check", "git_op", "record_evidence", "interrupt"}


def _root():
    return os.environ.get("FLOW_PROJECT_ROOT") or os.getcwd()


def _session_id():
    # Mirrors flow.sh _session_env_id cascade (flow.sh:353-368).
    for var in ("FLOW_SESSION_ID", "CLAUDE_CODE_SESSION_ID", "CODEX_SESSION_ID",
                "CODEX_THREAD_ID", "AGY_SESSION_ID", "ANTIGRAVITY_SESSION_ID"):
        v = os.environ.get(var)
        if v:
            return v.replace("\r", "").replace("\n", "").replace("|", "")
    return "ppid:%s:%s" % (os.uname().nodename if hasattr(os, "uname") else "host",
                           os.getppid())


def _git(root, *args):
    try:
        return subprocess.run(["git", "-C", root, *args],
                              capture_output=True, text=True, timeout=15)
    except Exception:
        return None


def _git_out(root, *args):
    r = _git(root, *args)
    return r.stdout if (r is not None and r.returncode == 0) else None


# ---------------- topology ----------------

def load_topology(path):
    """Phase-2 fixture loader: plain JSON file. Phase 3 replaces this call site with
    the install-dir-only, pin-verified loader + full lint."""
    with open(path, encoding="utf-8") as fh:
        topo = json.load(fh)
    if not isinstance(topo.get("nodes"), dict) or not isinstance(topo.get("edges"), list):
        raise ValueError("topology: nodes/edges missing")
    for name, spec in topo["nodes"].items():
        if spec.get("type") not in NODE_TYPES:
            raise ValueError(f"topology: node {name} has type outside {sorted(NODE_TYPES)}")
    return topo


def _successors(topo, node, latest_manifest):
    out = []
    for e in topo["edges"]:
        if e.get("from") != node:
            continue
        pred = e.get("when", "always")
        if _predicate(pred, latest_manifest):
            out.append(e["to"])
    return out


def _predicate(name, manifest):
    # Registry is exactly {always, review_green, review_red} (red-team round 7:
    # debt-skips are a traversal semantic, not predicates). Predicates read ONLY
    # durable artifacts - here, the recorded gate exit in the latest manifest.
    gate = (manifest or {}).get("gate") or {}
    if name == "always":
        return True
    if name == "review_green":
        return gate.get("exit") == 0
    if name == "review_red":
        return gate.get("exit") not in (None, 0)
    raise ValueError(f"unregistered predicate: {name}")


def _skipped_stages(root):
    p = os.path.join(root, "flow", ".skipped")
    try:
        with open(p, encoding="utf-8") as fh:
            return {ln.strip() for ln in fh if ln.strip()}
    except OSError:
        return set()


# A debt-skipped gate is ACCEPTED-WITH-DEBT: cmd_skip only advances after the DEBT +
# security-class + 05 guards, and its own contract line is "planning_complete now
# tolerates it" (flow.sh:1258). So for traversal purposes a skipped gate evaluates
# predicates as a PASS - its green out-edges are taken, red ones are not.
_SKIPPED_GATE_MANIFEST = {"gate": {"exit": 0, "skipped": True}}


def _substitute_skips(topo, nodes, root, _seen=None):
    """Transitively replace gate_check nodes whose mapped `stage` is debt-skipped
    with THEIR successors (round-7 traversal semantic - no bypass edges in data).
    Topology never writes flow/.skipped; only cmd_skip does."""
    skipped = _skipped_stages(root)
    if not skipped:
        return nodes
    seen = _seen or set()
    out = []
    for n in nodes:
        spec = topo["nodes"].get(n, {})
        stage = spec.get("stage")
        if spec.get("type") == "gate_check" and stage and stage in skipped and n not in seen:
            seen.add(n)
            out.extend(_substitute_skips(
                topo, _successors(topo, n, _SKIPPED_GATE_MANIFEST), root, seen))
        else:
            out.append(n)
    return out


# ---------------- journal ----------------

def _latest_checkpoint(con, execution_id, ns):
    return _db.one(con,
                   "SELECT * FROM graph_checkpoint WHERE execution_id=? AND ns=? "
                   "ORDER BY checkpoint_id DESC LIMIT 1", (execution_id, ns))


def _execution(con, execution_id):
    return _db.one(con, "SELECT * FROM graph_execution WHERE id=?", (execution_id,))


def _open_interrupt(con, execution_id, ns=None):
    if ns is None:
        return _db.one(con, "SELECT * FROM graph_interrupt WHERE execution_id=? "
                            "AND status='open' ORDER BY created_at LIMIT 1", (execution_id,))
    return _db.one(con, "SELECT * FROM graph_interrupt WHERE execution_id=? AND ns=? "
                        "AND status='open' ORDER BY created_at LIMIT 1", (execution_id, ns))


def plan_next(con, topo, execution_id, ns, root):
    """Next node names for (execution, ns): entry roots before the first checkpoint,
    else predicate-gated successors of the latest node, with skip-substitution."""
    latest = _latest_checkpoint(con, execution_id, ns)
    if latest is None:
        if ns != "":
            # Non-root namespaces (card:C-NNN) have no implicit entry: Phase 4 starts
            # them by recording their dispatch node explicitly. Empty = nothing to do.
            return []
        entry = topo.get("entry") or []
        return _substitute_skips(topo, list(entry[:1]), root)
    manifest = json.loads(latest["manifest"])
    return _substitute_skips(topo, _successors(topo, latest["node"], manifest), root)


# ---------------- verbs ----------------

def _guard_flags():
    if os.environ.get("FLOW_HARNESS_DISABLE"):
        sys.stderr.write(
            "flow-graph: FLOW_HARNESS_DISABLE is set but a graph verb was invoked - "
            "contradictory instruction (the executor IS the durable layer). Unset "
            "FLOW_HARNESS_DISABLE to use graph commands.\n")
        return 4
    return None


def cmd_graph_run(con, a):
    rc = _guard_flags()
    if rc:
        return rc
    if a.story and _db.one(con, "SELECT 1 FROM story WHERE id=?", (a.story,)) is None:
        sys.stderr.write(f"flow-graph: no story {a.story} - create it first "
                         "(story add --id ...) or omit --story\n")
        return 1
    eid = graph_ids.new_id()
    with _db.transaction(con):
        con.execute(
            "INSERT INTO graph_execution (id,project,kind,topology_version,topology_hash,story_id) "
            "VALUES (?,?,?,?,?,?)",
            (eid, a.project or os.path.basename(_root()), a.kind,
             a.topology_version, a.topology_hash, a.story))
    print(eid)
    return 0


TERMINAL = ("done", "failed", "abandoned")


def cmd_graph_record(con, a):
    rc = _guard_flags()
    if rc:
        return rc
    ex = _execution(con, a.execution)
    if ex is None:
        sys.stderr.write(f"flow-graph: no execution {a.execution}\n")
        return 1
    if ex["status"] in TERMINAL:
        # Terminal is terminal: a killed-at-gate execution must never be resurrected
        # by a later record (the kill IS the operator decision).
        sys.stderr.write(f"flow-graph: execution is terminal ({ex['status']}) - refusing record\n")
        return 1
    ns = a.ns or ""
    latest = _latest_checkpoint(con, a.execution, ns)
    versions = json.loads(latest["versions"]) if latest else {}
    versions[a.node] = versions.get(a.node, 0) + 1
    seen = json.loads(latest["seen"]) if latest else {}
    seen[a.node] = dict(versions)
    ck = graph_ids.new_id()
    meta = {"source": a.source, "step": (json.loads(latest["meta"])["step"] + 1) if latest else 0,
            "ts": int(time.time())}
    writes = json.loads(a.writes) if a.writes else []
    if os.environ.get("FLOW_GRAPH_FAILPOINT") == "before-commit":
        # test-only crash injection: proves the write below is atomic (rolls back whole)
        try:
            with _db.transaction(con):
                con.execute("INSERT INTO graph_checkpoint "
                            "(execution_id,ns,checkpoint_id,parent_checkpoint_id,node,manifest,versions,seen,meta) "
                            "VALUES (?,?,?,?,?,?,?,?,?)",
                            (a.execution, ns, ck, a.parent, a.node, a.manifest or "{}",
                             json.dumps(versions), json.dumps(seen), json.dumps(meta)))
                raise RuntimeError("failpoint")
        except RuntimeError:
            sys.stderr.write("flow-graph: FLOW_GRAPH_FAILPOINT=before-commit fired "
                             "(transaction rolled back)\n")
            return 1
    with _db.transaction(con):
        for i, w in enumerate(writes):
            con.execute("INSERT INTO graph_step_write "
                        "(execution_id,ns,checkpoint_id,task_id,idx,channel,value) "
                        "VALUES (?,?,?,?,?,?,?)",
                        (a.execution, ns, ck, w.get("task", "t0"), i,
                         w.get("channel", ""), json.dumps(w.get("value"))))
        con.execute("INSERT INTO graph_checkpoint "
                    "(execution_id,ns,checkpoint_id,parent_checkpoint_id,node,manifest,versions,seen,meta) "
                    "VALUES (?,?,?,?,?,?,?,?,?)",
                    (a.execution, ns, ck, a.parent, a.node, a.manifest or "{}",
                     json.dumps(versions), json.dumps(seen), json.dumps(meta)))
        if a.interrupt:
            con.execute("INSERT INTO graph_interrupt "
                        "(execution_id,ns,interrupt_id,node,prompt,security_class) "
                        "VALUES (?,?,?,?,?,?)",
                        (a.execution, ns, graph_ids.new_id(), a.node,
                         a.prompt or "operator decision required", 1 if a.security_class else 0))
            con.execute("UPDATE graph_execution SET status='paused', "
                        "updated_at=datetime('now') WHERE id=?", (a.execution,))
        else:
            con.execute("UPDATE graph_execution SET updated_at=datetime('now') WHERE id=?",
                        (a.execution,))
    if a.interrupt:
        # exit 3 = paused/no-value by contract: no stdout (the id is in `status`)
        return 3
    print(ck)
    return 0


def cmd_graph_next(con, a):
    rc = _guard_flags()
    if rc:
        return rc
    ex = _execution(con, a.execution)
    if ex is None:
        sys.stderr.write(f"flow-graph: no execution {a.execution}\n")
        return 1
    if ex["status"] == "paused" and _open_interrupt(con, a.execution):
        sys.stderr.write("flow-graph: execution paused on an open interrupt - "
                         "resolve via `graph resume --answer ... --actor ...`\n")
        return 3
    if ex["status"] in TERMINAL:
        sys.stderr.write(f"flow-graph: execution is terminal ({ex['status']})\n")
        return 3
    try:
        topo = load_topology(a.topology)
        nxt = plan_next(con, topo, a.execution, a.ns or "", _root())
    except (OSError, ValueError) as e:
        # Bad/missing topology or unregistered predicate: a clean failure, never a
        # traceback (rc 1 is the failure code; 3 stays reserved for complete/paused).
        sys.stderr.write(f"flow-graph: topology error: {e}\n")
        return 1
    if not nxt:
        return 3
    print(nxt[0])
    return 0


def _debt_provenance(root, target):
    """(ok, why, debt_line, author_mail) — out-of-band artifact checks (a)+(b).

    (a) closed-set target, DEBT-row-restricted fixed-string match, FULL line captured
        (the capture is $debt_line's ONLY provenance; empty capture refuses).
    (b) committed provenance against HEAD's blob of the SAME file: refuse on ANY
        uncommitted DEBT.md change, locate the captured line in
        `git show HEAD:<prefix>DEBT.md`, then blame that line at HEAD for author-mail.
    """
    if not TARGET_RE.match(target or ""):
        return False, "target outside closed set", None, None
    debt_path = os.path.join(root, "DEBT.md")
    try:
        with open(debt_path, encoding="utf-8") as fh:
            rows = [ln.rstrip("\n") for ln in fh]
    except OSError:
        return False, "no DEBT.md", None, None
    debt_line = next((ln for ln in rows
                      if ln.startswith("- [ ] DEBT:") and target in ln), "")
    if not debt_line:
        return False, "no open DEBT line naming the target", None, None
    r = _git(root, "diff", "--quiet", "HEAD", "--", "DEBT.md")
    if r is None or r.returncode != 0:
        return False, "DEBT.md has uncommitted changes (or git unavailable)", None, None
    pfx = (_git_out(root, "rev-parse", "--show-prefix") or "").strip()
    blob = _git_out(root, "show", f"HEAD:{pfx}DEBT.md")
    if blob is None:
        return False, "DEBT.md not committed", None, None
    n = next((i + 1 for i, ln in enumerate(blob.splitlines()) if ln == debt_line), 0)
    if not n:
        return False, "captured DEBT line absent from HEAD blob", None, None
    porc = _git_out(root, "blame", "-w", "--line-porcelain",
                    "-L", f"{n},{n}", "HEAD", "--", "DEBT.md") or ""
    mail = next((ln[len("author-mail "):].strip("<> ")
                 for ln in porc.splitlines() if ln.startswith("author-mail ")), None)
    return True, "", debt_line, mail


def cmd_graph_resume(con, a):
    rc = _guard_flags()
    if rc:
        return rc
    ex = _execution(con, a.execution)
    if ex is None:
        sys.stderr.write(f"flow-graph: no execution {a.execution}\n")
        return 1
    if ex["status"] in TERMINAL:
        sys.stderr.write(f"flow-graph: execution is terminal ({ex['status']}) - refusing resume\n")
        return 1
    intr = _open_interrupt(con, a.execution)
    if intr is None:
        if a.answer or a.actor:
            sys.stderr.write("flow-graph: no open interrupt on this execution\n")
            return 1
        # No interrupt + no answer: reconciliation report. For each ns, verify the
        # latest manifest's durable claims against git so evidence-backed work is
        # never re-dispatched even if a recording call was missed.
        root = _root()
        report = []
        for row in _db.rows(con,
                            "SELECT ns, MAX(checkpoint_id) AS ck FROM graph_checkpoint "
                            "WHERE execution_id=? GROUP BY ns", (a.execution,)):
            full = _db.one(con, "SELECT node, manifest FROM graph_checkpoint "
                                "WHERE execution_id=? AND ns=? AND checkpoint_id=?",
                           (a.execution, row["ns"], row["ck"]))
            manifest = json.loads(full["manifest"])
            report.append({"ns": row["ns"], "node": full["node"],
                           "evidence": verify_evidence(root, manifest)})
        print(json.dumps({"execution": a.execution, "reconciliation": report}))
        return 0
    if not a.answer or not a.actor:
        sys.stderr.write("flow-graph: resume needs --answer <json> and --actor <id>\n")
        return 2
    try:
        ans = json.loads(a.answer)
        reason = ans["reason"]
        assert isinstance(reason, str) and reason.strip()
    except Exception:
        sys.stderr.write("flow-graph: --answer must be a JSON object with a non-empty "
                         "string \"reason\"\n")
        return 1
    root = _root()
    audit_session = _session_id()
    author_distinct = None
    if a.target and not TARGET_RE.match(a.target):
        sys.stderr.write("flow-graph: BLOCKED - target outside the closed set "
                         "(C-NNN or NN-stage)\n")
        return 1
    if intr["security_class"]:
        if SECURITY_RE.search(reason):
            sys.stderr.write("flow-graph: BLOCKED - that reason looks security-class; "
                             "security resolutions are operator-only (mirror of cmd_skip)\n")
            return 1
        target = a.target or ""
        ok, why, debt_line, mail = _debt_provenance(root, target)
        if not ok:
            sys.stderr.write(f"flow-graph: BLOCKED - {why}. A committed open DEBT line "
                             "naming the target is required (out-of-band artifact).\n")
            return 1
        cfg = (_git_out(root, "config", "user.email") or "").strip()
        # Audit evidence, NOT authorization: same-identity environments degrade
        # (documented) to committed-provenance + audit fields.
        author_distinct = bool(mail and cfg and mail != cfg)
    with _db.transaction(con):
        con.execute("UPDATE graph_interrupt SET status='resolved', resume_value=?, "
                    "resolved_by=?, resolved_at=datetime('now') "
                    "WHERE execution_id=? AND ns=? AND interrupt_id=?",
                    (json.dumps({"answer": ans, "actor": a.actor,
                                 "session": audit_session,
                                 "author_distinct": author_distinct}),
                     a.actor, intr["execution_id"], intr["ns"], intr["interrupt_id"]))
        con.execute("UPDATE graph_execution SET status='running', "
                    "updated_at=datetime('now') WHERE id=?", (a.execution,))
    print(intr["interrupt_id"])
    return 0


def _safe_ref(v):
    # Manifest values reach git argv: refuse anything option-shaped so a crafted
    # manifest cannot smuggle git flags (evidence spoofing).
    return isinstance(v, str) and v and not v.startswith("-")


def verify_evidence(root, manifest):
    """Git reconciliation: check a manifest's durable claims against reality.
    Consumed by `graph resume` (no-args reconciliation report) so evidence-backed
    work is never re-dispatched even if a recording call was missed (the
    between-invocations window)."""
    out = {}
    branch = manifest.get("branch")
    if _safe_ref(branch):
        out["branch_exists"] = _git_out(root, "rev-parse", "--verify",
                                        "--quiet", branch, "--") is not None
    sha, base = manifest.get("git_sha"), manifest.get("base")
    if _safe_ref(sha) and _safe_ref(base):
        r = _git(root, "merge-base", "--is-ancestor", sha, base)
        out["merged"] = bool(r is not None and r.returncode == 0)
    return out


def cmd_graph_status(con, a):
    rc = _guard_flags()
    if rc:
        return rc
    ex = _execution(con, a.execution)
    if ex is None:
        sys.stderr.write(f"flow-graph: no execution {a.execution}\n")
        return 1
    latest = _db.rows(con,
                      "SELECT ns, MAX(checkpoint_id) AS checkpoint_id, node FROM graph_checkpoint "
                      "WHERE execution_id=? GROUP BY ns", (a.execution,))
    opens = _db.rows(con, "SELECT ns, interrupt_id, node, security_class FROM graph_interrupt "
                          "WHERE execution_id=? AND status='open'", (a.execution,))
    print(json.dumps({"execution": dict(ex), "latest": latest, "open_interrupts": opens}))
    return 0


def cmd_graph_abandon(con, a):
    rc = _guard_flags()
    if rc:
        return rc
    with _db.transaction(con):
        cur = con.execute("UPDATE graph_execution SET status='abandoned', outcome=?, "
                          "updated_at=datetime('now') WHERE id=?",
                          (a.outcome, a.execution))
        if not cur.rowcount:
            raise sqlite3.IntegrityError(f"no execution {a.execution}")
        con.execute("UPDATE graph_interrupt SET status='abandoned' "
                    "WHERE execution_id=? AND status='open'", (a.execution,))
    return 0


def cmd_graph_gc(con, a):
    rc = _guard_flags()
    if rc:
        return rc
    project = a.project or os.path.basename(_root())
    # Purge FIRST, then sweep: rows marked stale in this invocation survive until the
    # NEXT gc, so doctor/status get a window to surface them (never mark-and-delete in
    # one call). Purge is scoped to one project - the DB is deliberately shared across
    # worktrees, and a sibling card's gc must not erase this project's history.
    with _db.transaction(con):
        cur = con.execute("DELETE FROM graph_execution "
                          "WHERE status IN ('done','failed','abandoned') AND project=?",
                          (project,))
        deleted = cur.rowcount
    marked = 0
    if a.stale_days is not None:
        cutoff = int(time.time()) - a.stale_days * 86400
        try:
            stale = _db.rows(con,
                             "SELECT e.id FROM graph_execution e "
                             "WHERE e.status='running' AND e.project=? "
                             "AND e.created_at <= datetime('now', ?) "
                             "AND NOT EXISTS ("
                             "  SELECT 1 FROM graph_checkpoint c WHERE c.execution_id=e.id "
                             "  AND json_extract(c.meta,'$.ts') >= ?)",
                             (project, f"-{a.stale_days} days", cutoff))
        except sqlite3.OperationalError:
            sys.stderr.write("flow-graph: this SQLite lacks JSON1 (json_extract) - "
                             "stale sweep unavailable\n")
            print(json.dumps({"deleted": deleted, "stale_marked": 0}))
            return 1
        for row in stale:
            _db.update_where(con, "graph_execution", {"id": row["id"]},
                             status="abandoned", outcome="stale")
            marked += 1
    print(json.dumps({"deleted": deleted, "stale_marked": marked}))
    return 0

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

import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
import time

import _db
import graph_ids
import graph_predicates as PRED

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRUSTED_TOPOLOGY = os.path.join(SKILL_DIR, "references", "flow-topology.json")
TOPOLOGY_PIN = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "pins", "flow-topology.sha256")

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


def _project_key():
    """Project identity for rows in the SHARED db. Must be main-root scoped: stamping
    basename(_root()) would record whichever worktree happened to mint the execution
    (`proj-card-C-001`), and gc filtering by the caller's basename would then never
    see it - terminal rows unpurgeable, stale sweep blind."""
    root = _root()
    return os.path.basename(_db._linked_worktree_main_root(root) or root)


def _session_id():
    # Mirrors flow.sh _session_env_id cascade (flow.sh:353-368).
    for var in ("FLOW_SESSION_ID", "CLAUDE_CODE_SESSION_ID", "CODEX_SESSION_ID",
                "CODEX_THREAD_ID", "AGY_SESSION_ID", "ANTIGRAVITY_SESSION_ID"):
        v = os.environ.get(var)
        if v:
            return v.replace("\r", "").replace("\n", "").replace("|", "")
    return "ppid:%s:%s" % (os.uname().nodename if hasattr(os, "uname") else "host",
                           os.getppid())


def _git_env():
    """git honours GIT_DIR/GIT_WORK_TREE from the environment, and every git HOOK
    exports them (also `git rebase -x`, `bisect run`, `submodule foreach`). Inheriting
    them silently points our worktree translation and merge proofs at a foreign repo."""
    env = dict(os.environ)
    for k in ("GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE",
              "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"):
        env.pop(k, None)
    return env


def _git(root, *args):
    try:
        return subprocess.run(["git", "-C", root, *args], env=_git_env(),
                              capture_output=True, text=True, timeout=15)
    except Exception:
        return None


def _git_out(root, *args):
    r = _git(root, *args)
    return r.stdout if (r is not None and r.returncode == 0) else None


def _linked_main_root(root):
    """Main-worktree path when `root` is inside a linked worktree, else None.

    Delegates to the ONE resolver (`_db`), which handles submodules,
    --separate-git-dir (core.worktree) and monorepo sub-projects - a second local
    heuristic is exactly what drifted before."""
    return _db._linked_worktree_main_root(root)


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
    # Registry lives in graph_predicates (exactly {always, review_green, review_red};
    # red-team round 7: debt-skips are a traversal semantic, not predicates).
    return PRED.evaluate(name, manifest)


def canonical_hash(topo):
    # Whitespace-insensitive: hash the canonical JSON form, so cosmetic edits
    # don't invalidate the pin or strand paused executions.
    blob = json.dumps(topo, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(blob).hexdigest()


def load_topology_trusted():
    """Shipped-topology loader: skill install dir ONLY, pin-verified.

    A project-local flow-topology.json is IGNORED with a warning (topology is
    executable-adjacent data - a cloned repo must not be able to swap it), and a
    pin mismatch REFUSES (exit path: ValueError -> clean rc 1), never just records.
    Returns (topology, canonical_hash)."""
    local = os.path.join(_root(), "flow-topology.json")
    if os.path.exists(local):
        sys.stderr.write("flow-graph: ignoring project-local flow-topology.json "
                         "(topology loads only from the skill install dir, pin-verified)\n")
    topo = load_topology(TRUSTED_TOPOLOGY)
    try:
        with open(TOPOLOGY_PIN, encoding="utf-8") as fh:
            pin = fh.read().split()[0]
    except (OSError, IndexError):
        raise ValueError(f"topology pin missing/unreadable at {TOPOLOGY_PIN}")
    h = canonical_hash(topo)
    if h != pin:
        raise ValueError("topology pin mismatch - refusing to run. If the edit is "
                         "intentional, regenerate the pin (see harness/README.md)")
    return topo, h


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


def _substitute_skips(topo, nodes, skipped, _seen=None):
    """Transitively replace gate_check nodes whose mapped `stage` is debt-skipped
    with THEIR successors (round-7 traversal semantic - no bypass edges in data).
    Topology never writes flow/.skipped; only cmd_skip does. `skipped` is the
    stage-name set (callers pass _skipped_stages(root); lint passes subsets)."""
    if not skipped:
        return nodes
    seen = _seen or set()
    out = []
    for n in nodes:
        spec = topo["nodes"].get(n, {})
        stage = spec.get("stage")
        if spec.get("type") == "gate_check" and stage and stage in skipped:
            if n in seen:
                continue  # cycle revisit: never re-emit a skipped gate (matches _skip_walk)
            seen.add(n)
            out.extend(_substitute_skips(
                topo, _successors(topo, n, _SKIPPED_GATE_MANIFEST), skipped, seen))
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


def _visits(con, execution_id, ns, node):
    return con.execute("SELECT COUNT(*) FROM graph_checkpoint WHERE execution_id=? "
                       "AND ns=? AND node=?", (execution_id, ns, node)).fetchone()[0]


def plan_next(con, topo, execution_id, ns, root):
    """Next node names for (execution, ns): entry roots before the first checkpoint,
    else predicate-gated successors of the latest node, with skip-substitution."""
    latest = _latest_checkpoint(con, execution_id, ns)
    # Skips are written by cmd_skip at the main root; a card worktree must not see a
    # different skip set than the journal was recorded under.
    skipped = _skipped_stages(_db._linked_worktree_main_root(root) or root)
    if latest is None:
        if ns != "":
            # Non-root namespaces (card:C-NNN) have no implicit entry: Phase 4 starts
            # them by recording their dispatch node explicitly. Empty = nothing to do.
            return []
        entry = topo.get("entry") or []
        return _substitute_skips(topo, list(entry[:1]), skipped)
    manifest = json.loads(latest["manifest"])
    nxt = _substitute_skips(topo, _successors(topo, latest["node"], manifest), skipped)
    # A declared max_visits is a BOUND, not decoration: once a repair node has been
    # visited that many times the two-strikes contract says escalate, so stop advising it
    # (auto-run.md: strike 2 -> operator/cross-vendor, never an unbounded loop).
    out = []
    for n in nxt:
        cap = topo["nodes"].get(n, {}).get("max_visits")
        if cap and _visits(con, execution_id, ns, n) >= int(cap):
            sys.stderr.write(f"flow-graph: {n} hit max_visits={cap} - escalate, not retry\n")
            continue
        out.append(n)
    return out


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
            (eid, a.project or _project_key(), a.kind,
             a.topology_version, a.topology_hash, a.story))
    print(eid)
    return 0


TERMINAL = ("done", "failed", "abandoned")


def _no_dupes(pairs):
    seen = {}
    for k, v in pairs:
        if k in seen:
            raise ValueError(f"duplicate key {k!r} in manifest")
        seen[k] = v
    return seen


def _build_manifest(a):
    """Assemble the evidence manifest HERE, from typed flags - never from a JSON string
    a shell concatenated. Card `status:` tokens and git ref names are attacker-adjacent
    free text: spliced into a bash JSON literal, `status: x","gate":{"exit":0},"z":"`
    silently overrides a RED gate with a green one (json keeps the last duplicate key).
    A caller-supplied --manifest is still accepted for tests, but is parsed and
    duplicate-key-rejected before it can reach the journal."""
    m = {}
    if a.manifest:
        m = json.loads(a.manifest, object_pairs_hook=_no_dupes)
        if not isinstance(m, dict):
            raise ValueError("manifest must be a JSON object")
    gate = {}
    if getattr(a, "gate_exit", None) is not None:
        gate["exit"] = int(a.gate_exit)
    if getattr(a, "gate_cmd", None):
        gate["cmd"] = a.gate_cmd
    if gate:
        m["gate"] = gate
    for flag, key in (("card_status", "status"), ("branch", "branch"),
                      ("worktree", "worktree"), ("vendor", "vendor")):
        v = getattr(a, flag, None)
        if v:
            m[key] = v
    return json.dumps(m)


def cmd_graph_session(con, a):
    """Print the project's current RUNNING auto_run execution, minting one atomically if
    there is none (unless --no-create). SQLite's BEGIN IMMEDIATE is the arbitration point.

    This replaces a bash pin file + mkdir claim: that design needed corpse recovery,
    TOCTOU-free reclaim and a liveness check, and got all three wrong (a claim could be
    stolen mid-mint, and an ABANDONED row still passed an existence-only check, silently
    blackholing every later record). Here the query itself filters on status='running',
    so a retired execution can never be adopted."""
    rc = _guard_flags()
    if rc:
        return rc
    project = a.project or _project_key()
    kind = getattr(a, "kind", None) or "auto_run"
    # running OR paused: a paused execution is waiting on an operator interrupt - still
    # the live session (its resolution must land on the SAME execution). Only terminal
    # states (done/failed/abandoned) are unadoptable. Planning and shipping keep separate
    # sessions (different namespaces, different lifetimes).
    q = ("SELECT id FROM graph_execution WHERE project=? AND kind=? "
         "AND status IN ('running','paused') ORDER BY id DESC LIMIT 1")
    row = _db.one(con, q, (project, kind))
    if row:
        print(row["id"])
        return 0
    if getattr(a, "no_create", False):
        return 3
    eid = graph_ids.new_id()
    with _db.transaction(con):
        row = con.execute(q, (project, kind)).fetchone()   # re-check under the write lock
        if row:
            eid = row[0]
        else:
            con.execute(
                "INSERT INTO graph_execution (id,project,kind,topology_version,topology_hash) "
                "VALUES (?,?,?,?,?)", (eid, project, kind, 0, ""))
    print(eid)
    return 0


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
    try:
        a.manifest = _build_manifest(a)
    except (ValueError, TypeError) as e:
        sys.stderr.write(f"flow-graph: bad manifest: {e}\n")
        return 1
    # Boundary, not heartbeat: re-running the SAME verb with the SAME evidence is a
    # no-op. Without this, a second `flow.sh check` on a done card appends another
    # card-review after card-verify-live and `plan_next` (which reads the LATEST
    # checkpoint) rewinds the walk - advising re-verification of shipped work. A
    # changed manifest (red -> green, repair cycles) still records, as it must.
    if not getattr(a, "interrupt", False):
        prev = _latest_checkpoint(con, a.execution, ns)
        if prev and prev["node"] == a.node and prev["manifest"] == a.manifest:
            print(prev["checkpoint_id"])
            return 0
    if os.environ.get("FLOW_GRAPH_TOPOLOGY_FIXTURE") != "1":
        # Typo'd or contract-drifted node names would journal cleanly and then dead-end
        # at `next` as rc 3 "complete". Validate against the shipped topology (fixtures
        # opt out - they define their own node sets).
        try:
            topo_v, _ = load_topology_trusted()
            if a.node not in topo_v["nodes"]:
                sys.stderr.write(f"flow-graph: node {a.node!r} is not in the shipped topology\n")
                return 1
        except (OSError, ValueError):
            pass  # pin/loader problems surface on `next`/`lint`, not on a record
    if getattr(a, "merge", False):
        # The caller may NOT assert a merge: _ws_remove has no merge knowledge
        # (flow.sh:2077+ only removes the tree), so the executor computes the proof.
        root = _root()
        branch = a.branch or ""
        if not _safe_ref(branch):
            sys.stderr.write("flow-graph: --merge needs --branch <ref>\n")
            return 2
        # Bases, in proof precedence: the LOCAL integration branch first (auto-run merges
        # locally at step 5 and tears the tree down at step 8 with no push in between, so
        # origin/HEAD is stale there and would journal shipped work as abandoned), then
        # origin/HEAD as secondary confirmation. Never `rev-parse HEAD` of the current
        # tree: inside a card worktree that IS the card branch (self-ancestor).
        bases = []
        if a.base:
            bases = [a.base]
        else:
            main_root = _linked_main_root(root) or root
            local = (_git_out(main_root, "rev-parse", "--abbrev-ref", "HEAD") or "").strip()
            remote = (_git_out(root, "rev-parse", "--abbrev-ref", "origin/HEAD") or "").strip()
            bases = [b for b in (local, remote) if b]
        bases = [b for b in bases if _safe_ref(b) and b != branch]
        if not bases:
            sys.stderr.write("flow-graph: no usable merge base (self-ancestor or unresolvable) "
                             "- pass --base explicitly\n")
            return 2
        sha = (_git_out(root, "rev-parse", "--verify", "--quiet", branch, "--") or "").strip()
        if not sha:
            sys.stderr.write(f"flow-graph: branch {branch} not found\n")
            return 1
        merged, proved_by = False, None
        for b in bases:
            r = _git(root, "merge-base", "--is-ancestor", sha, b)
            if r is not None and r.returncode == 0:
                merged, proved_by = True, b
                break
        a.manifest = json.dumps({"branch": branch, "git_sha": sha,
                                 "base": proved_by or bases[0], "bases_tried": bases,
                                 "merged": merged})
        if not merged:
            # Unmerged teardown is abandonment, never a merge record.
            a.node = "card-abandon"
    latest = _latest_checkpoint(con, a.execution, ns)
    versions = json.loads(latest["versions"]) if latest else {}
    versions[a.node] = versions.get(a.node, 0) + 1
    seen = json.loads(latest["seen"]) if latest else {}
    seen[a.node] = dict(versions)
    ck = graph_ids.new_id()
    # Ordering is lexicographic over these ids, and a backwards clock step (NTP, resume
    # from suspend, a second host on a shared checkout) would otherwise mint an id BELOW
    # the journal head - the write lands but `_latest_checkpoint` never sees it.
    if latest and ck <= latest["checkpoint_id"]:
        ck = graph_ids.after(latest["checkpoint_id"])
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
    if _open_interrupt(con, a.execution, a.ns or ""):
        sys.stderr.write("flow-graph: this namespace has an open interrupt - "
                         "resolve it via `graph resume --interrupt-id ...`\n")
        return 3
    if ex["status"] == "paused" and _open_interrupt(con, a.execution):
        sys.stderr.write("flow-graph: execution paused on an open interrupt - "
                         "resolve via `graph resume --answer ... --actor ...`\n")
        return 3
    if ex["status"] in TERMINAL:
        sys.stderr.write(f"flow-graph: execution is terminal ({ex['status']})\n")
        return 3
    try:
        if a.topology:
            # Fixture-only surface: an ungated explicit path would bypass the pin, the
            # lint, AND the hash policy in one flag (review H2) - a cloned repo could
            # walk arbitrary topology. Tests opt in via env; production never does.
            if os.environ.get("FLOW_GRAPH_TOPOLOGY_FIXTURE") != "1":
                sys.stderr.write(
                    "flow-graph: --topology is a test-fixture surface; set "
                    "FLOW_GRAPH_TOPOLOGY_FIXTURE=1 to use it. Production walks the "
                    "shipped pin-verified topology only.\n")
                return 2
            sys.stderr.write(f"flow-graph: WARNING fixture topology in use: {a.topology} "
                             "(pin/lint/hash policy bypassed - journal hash unchanged)\n")
            topo = load_topology(a.topology)
        else:
            topo, h = load_topology_trusted()
            exh = ex["topology_hash"]
            if not exh:
                # Dark-phase executions were created with an empty hash: back-fill on
                # the first verified walk so the upgrade guard applies from then on.
                _db.update_where(con, "graph_execution", {"id": a.execution},
                                 topology_hash=h,
                                 topology_version=topo.get("topology_version", 1))
            elif exh != h:
                if getattr(a, "force_retopology", False):
                    # Fork onto the new topology: a fork checkpoint at the current node
                    # keeps the old chain walkable, then the execution re-pins its hash.
                    latest = _latest_checkpoint(con, a.execution, a.ns or "")
                    with _db.transaction(con):
                        if latest:
                            meta = json.loads(latest["meta"])
                            con.execute(
                                "INSERT INTO graph_checkpoint (execution_id,ns,checkpoint_id,"
                                "parent_checkpoint_id,node,manifest,versions,seen,meta) "
                                "VALUES (?,?,?,?,?,?,?,?,?)",
                                (a.execution, a.ns or "", graph_ids.new_id(),
                                 latest["checkpoint_id"], latest["node"], latest["manifest"],
                                 latest["versions"], latest["seen"],
                                 json.dumps({"source": "fork", "step": meta["step"] + 1,
                                             "ts": int(time.time())})))
                        con.execute("UPDATE graph_execution SET topology_hash=?, "
                                    "topology_version=?, updated_at=datetime('now') WHERE id=?",
                                    (h, topo.get("topology_version", 1), a.execution))
                else:
                    sys.stderr.write(
                        "flow-graph: the shipped topology changed since this execution "
                        "started (hash mismatch - e.g. a skill upgrade). Refusing to walk "
                        "a chain recorded under different semantics. Re-run with "
                        "--force-retopology to fork onto the current topology.\n")
                    return 1
        nxt = plan_next(con, topo, a.execution, a.ns or "", _root())
    except (OSError, ValueError) as e:
        # Bad/missing topology, pin mismatch, or unregistered predicate: a clean
        # failure, never a traceback (rc 1; 3 stays reserved for complete/paused).
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
    # Which interrupt is being answered must be EXPLICIT when more than one is open.
    # Resolving "whichever came first" let an operator answer a benign interrupt and
    # un-pause an execution whose security-class interrupt was still open - the guard
    # chain (closed-set target, committed DEBT provenance) was simply never reached.
    opens = _db.rows(con, "SELECT * FROM graph_interrupt WHERE execution_id=? AND status='open' "
                          "ORDER BY created_at, ns, interrupt_id", (a.execution,))
    if getattr(a, "interrupt_id", None):
        opens = [r for r in opens if r["interrupt_id"] == a.interrupt_id]
    elif getattr(a, "ns", None) is not None and a.ns != "":
        opens = [r for r in opens if r["ns"] == a.ns]
    if len(opens) > 1 and (a.answer or a.actor):
        sys.stderr.write(
            "flow-graph: %d interrupts are open - name the one you are answering with "
            "--interrupt-id (or --ns):\n" % len(opens))
        for r in opens:
            sys.stderr.write("  %s  ns=%s  node=%s  security_class=%s\n"
                             % (r["interrupt_id"], r["ns"] or "''", r["node"],
                                r["security_class"]))
        return 2
    intr = opens[0] if opens else None
    if intr is None:
        if a.answer or a.actor:
            sys.stderr.write("flow-graph: no open interrupt matches this execution/selector\n")
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
        # Un-pause only when NOTHING is still open: resolving one interrupt must not
        # release an execution whose security-class interrupt is still waiting.
        left = con.execute("SELECT COUNT(*) FROM graph_interrupt WHERE execution_id=? "
                           "AND status='open'", (a.execution,)).fetchone()[0]
        if not left:
            con.execute("UPDATE graph_execution SET status='running', "
                        "updated_at=datetime('now') WHERE id=?", (a.execution,))
    if left:
        sys.stderr.write(f"flow-graph: {left} interrupt(s) still open - execution stays paused\n")
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


# ---------------- card DAG (Phase 4) ----------------

_CARD_RE = re.compile(r"C-[0-9]+", re.IGNORECASE)


def _card_id(tok):
    return "C-%03d" % int(tok.split("-")[1])  # C-1 == C-001


def _read_cards(cards_dir):
    """Parse the REAL card format (no YAML frontmatter): a `deps:` body line whose
    free text is scraped for C-NNN ids (mirrors flow.sh:1310-1319) and a
    `## Allowed files` markdown section (mirrors _card_allowed_files, flow.sh:1289)
    tokenized like _ws_tokens (flow.sh:1948) so overlap can never diverge."""
    cards = {}
    if not os.path.isdir(cards_dir):
        return cards
    for name in sorted(os.listdir(cards_dir)):
        m = re.match(r"^(C-[0-9]+)\.md$", name)
        if not m:
            continue
        cid = _card_id(m.group(1))
        status, deps, files, in_allowed, fill = "", [], set(), False, False
        with open(os.path.join(cards_dir, name), encoding="utf-8", errors="replace") as fh:
            for line in fh:
                s = line.rstrip("\n")
                if s.startswith("## Allowed files"):
                    in_allowed = True
                    continue
                if in_allowed and s.startswith("## "):
                    in_allowed = False
                if in_allowed and s.strip():
                    if "[FILL" in s:
                        fill = True
                        continue
                    # Mirror _ws_tokens EXACTLY (flow.sh:2035): strip one leading bullet
                    # (incl. tabs), split on whitespace, then DELETE backticks/commas
                    # (deleting, not splitting, is what joins `a.ts`,`b.ts` the same way).
                    for tok in re.sub(r"^\s*-\s*", "", s).split():
                        # \r too: bash `tr -s ' \t'` leaves it, so a CRLF checkout would
                        # otherwise compare `src/a.ts\r` against `src/a.ts` and miss overlap.
                        tok = tok.replace("`", "").replace(",", "").replace("\r", "")
                        if tok:
                            files.add(tok)
                elif s.startswith("status:") and not status:
                    status = s.split(":", 1)[1].strip().split()[0] if s.split(":", 1)[1].strip() else ""
                elif s.startswith("deps:") and not deps:
                    deps = [_card_id(t) for t in _CARD_RE.findall(s)]
        # A self-dep is kept (not silently dropped): cmd_ready blocks such a card, so the
        # compiler must too - dropping it would advertise an undispatchable card as ready.
        cards[cid] = {"id": cid, "status": status, "deps": sorted(set(deps)),
                      "files": sorted(files), "fill": fill}
    return cards


def _dep_cycles(cards):
    color, out = {}, []
    path = []

    def dfs(n):
        color[n] = 1
        path.append(n)
        for d in cards.get(n, {}).get("deps", []):
            if d not in cards:
                continue
            if color.get(d) == 1:
                out.append(path[path.index(d):] + [d])
            elif color.get(d, 0) == 0:
                dfs(d)
        path.pop()
        color[n] = 2

    for n in cards:
        if color.get(n, 0) == 0:
            dfs(n)
    return out


def compile_cards(root, active_files=()):
    """Card DAG + ready-set. deps-met mirrors cmd_ready (status of each dep == done);
    overlap serialization is NEW deliberate behavior (legacy `ready` only advises,
    flow.sh:1302): cards sharing an allowed-file token, or overlapping a currently
    active worktree's tokens, are held back so two agents never edit one file."""
    cards = _read_cards(os.path.join(root, "cards"))
    cycles = _dep_cycles(cards)
    # Only `todo` is buildable - cmd_ready's exact semantics (an invalid/blank status is
    # a gate violation, not a dispatchable card).
    todo = [c for c in cards.values() if c["status"] == "todo"]
    in_cycle = {n for cyc in cycles for n in cyc}
    deps_met, blocked = [], {}
    for c in sorted(todo, key=lambda x: x["id"]):
        missing = [d for d in c["deps"] if cards.get(d, {}).get("status") != "done"]
        if c["id"] in in_cycle:
            blocked[c["id"]] = {"reason": "dep cycle",
                                "cycle": next("->".join(x) for x in cycles if c["id"] in x)}
        elif missing:
            blocked[c["id"]] = {"reason": "deps", "missing": missing}
        elif c["fill"]:
            blocked[c["id"]] = {"reason": "allowed-files still has [FILL"}
        else:
            deps_met.append(c["id"])
    ready, taken = [], set(active_files)
    for cid in deps_met:
        f = set(cards[cid]["files"])
        if f & taken:
            blocked[cid] = {"reason": "allowed-files overlap",
                            "with": sorted(f & taken)}
            continue
        taken |= f
        ready.append(cid)
    return {"cards": {k: v for k, v in sorted(cards.items())},
            "deps_met": deps_met, "ready": ready, "blocked": blocked,
            "cycles": ["->".join(c) for c in cycles]}


def cmd_graph_cards(con, a):
    rc = _guard_flags()
    if rc:
        return rc
    active = []
    if a.active_files:
        active = [t for t in a.active_files.replace(",", " ").split() if t]
    out = compile_cards(_root(), active)
    # A dep cycle blocks its OWN members, never the board: cmd_ready keeps advising every
    # other buildable card, and auto-run routes all dispatch through this verb - one
    # authoring typo must not halt a healthy run. rc 1 stays for an unreadable cards/.
    for c in out["cycles"]:
        sys.stderr.write(f"flow-graph: card dependency cycle: {c}\n")
    print(json.dumps(out))
    return 0


def cmd_graph_root(con, a):
    """Print the directory that owns this project's durable state. Single source of
    truth for main-tree scoping: flow.sh asks THIS instead of re-deriving the worktree
    translation with a weaker heuristic (a second implementation drifted on monorepo
    sub-projects and --separate-git-dir repos, re-splitting the journal)."""
    print(os.path.dirname(_db.default_db_path()))
    return 0


# ---------------- lint ----------------

# Autonomous cmd position allows ONLY read-only surfaces: flow.sh's scan-only `gate`
# verb and side-effect-free git queries. `check` mutates story/trace on pass and is
# Must-ask - a shape row for it would read as conditional permission (round-9 F1).
_CMD_GIT_VERBS = {"worktree", "merge-base", "rev-parse", "status", "log"}


def _lint_cmd(name, cmd):
    errs = []
    if not isinstance(cmd, list) or not cmd or not all(isinstance(x, str) for x in cmd):
        return [f"node {name}: cmd must be a non-empty argv array of strings"]
    for tok in cmd:
        if "{" in tok and tok != "{card}":
            errs.append(f"node {name}: unknown placeholder {tok!r} (only {{card}})")
    prog = cmd[0]
    if prog == "flow.sh":
        verb = cmd[1] if len(cmd) > 1 else ""
        if verb != "gate":
            errs.append(f"node {name}: flow.sh verb {verb!r} banned in autonomous cmd "
                        "position (only the read-only `gate` verb)")
        else:
            args = cmd[2:]
            ok = (len(args) == 1 and args[0] in PRED.STAGES) or args == ["--card", "{card}"]
            if not ok:
                errs.append(f"node {name}: gate arg shape must be a STAGES member "
                            f"or ['--card','{{card}}'] (got {args})")
    elif prog == "git":
        if len(cmd) < 2 or cmd[1] not in _CMD_GIT_VERBS:
            errs.append(f"node {name}: git verb outside {sorted(_CMD_GIT_VERBS)}")
    else:
        errs.append(f"node {name}: argv[0] {prog!r} outside {{flow.sh, git}}")
    return errs


def _reachable(topo, roots):
    seen, stack = set(), [r for r in roots if r in topo["nodes"]]
    while stack:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        stack.extend(e["to"] for e in topo["edges"] if e["from"] == n and e["to"] in topo["nodes"])
    return seen


def _skip_walk(topo, root, skipped):
    """Reachability under plan_next's skip-substitution: skipped gates pass through
    (their edges evaluated against the accepted-with-debt PASS manifest); all other
    edges are treated as traversable (their predicates depend on runtime gates)."""
    smap = PRED.stage_map(topo)
    seen, landed, stack = set(), set(), [root]
    while stack:
        n = stack.pop()
        if n in seen or n not in topo["nodes"]:
            continue
        seen.add(n)
        if smap.get(n) in skipped:
            for e in topo["edges"]:
                if e["from"] == n and _predicate(e.get("when", "always"),
                                                _SKIPPED_GATE_MANIFEST):
                    stack.append(e["to"])
            continue
        landed.add(n)
        stack.extend(e["to"] for e in topo["edges"] if e["from"] == n)
    return landed


def _lint_cycles(topo):
    """Planning (stage-carrying) subgraphs must be acyclic; every cycle anywhere
    must pass through a node carrying max_visits (the bounded-repair contract)."""
    errs = []
    nodes = topo["nodes"]
    adj = {}
    for e in topo["edges"]:
        adj.setdefault(e["from"], []).append(e["to"])
    color, stack_path = {}, []
    cycles = []

    def dfs(n):
        color[n] = 1
        stack_path.append(n)
        for m in adj.get(n, []):
            if m not in nodes:
                continue
            if color.get(m) == 1:
                cycles.append(stack_path[stack_path.index(m):] + [m])
            elif color.get(m, 0) == 0:
                dfs(m)
        stack_path.pop()
        color[n] = 2

    for n in nodes:
        if color.get(n, 0) == 0:
            dfs(n)
    smap = PRED.stage_map(topo)
    for cyc in cycles:
        if any(smap.get(n) for n in cyc):
            errs.append(f"planning subgraph cycle: {'->'.join(cyc)}")
        if not any(nodes[n].get("max_visits") for n in set(cyc)):
            errs.append(f"unbounded cycle (no max_visits node): {'->'.join(cyc)}")
    return errs


def _lint(topo, pin_path=None):
    errs = []
    nodes, edges = topo["nodes"], topo["edges"]
    entry = topo.get("entry") or []
    if not entry:
        errs.append("entry: missing or empty (unreachability is defined against entry roots)")
    for e in edges:
        for k in ("from", "to"):
            if e.get(k) not in nodes:
                errs.append(f"edge {e.get('from')}->{e.get('to')}: unknown node ref {e.get(k)!r}")
        w = e.get("when", "always")
        if w not in PRED.REGISTRY:
            errs.append(f"edge {e.get('from')}->{e.get('to')}: unregistered predicate {w!r}")
    for name, spec in nodes.items():
        if spec.get("cmd") is not None:
            errs += _lint_cmd(name, spec["cmd"])
        # Green-stranded gate (review H3): a gate_check with out-edges but none
        # satisfiable on a PASSING gate would dead-end at runtime with rc 3 -
        # indistinguishable from real completion. Terminals (no out-edges) are exempt.
        if spec.get("type") == "gate_check":
            outs = [e for e in edges if e.get("from") == name]
            if outs and not any(_predicate(e.get("when", "always"), _SKIPPED_GATE_MANIFEST)
                                for e in outs if e.get("when", "always") in PRED.REGISTRY):
                errs.append(f"node {name}: green-stranded gate (no out-edge satisfiable "
                            "on a passing gate - runtime would report complete)")
    reach_all = set()
    for r in entry:
        if r not in nodes:
            errs.append(f"entry root {r!r} is not a node")
            continue
        sub = _reachable(topo, [r])
        reach_all |= sub
        # Planning-subgraph discriminator: it contains the UNSKIPPABLE terminal stage
        # (05-contract). "Any node has a stage" would be self-defeating: a rogue stage
        # on card-review would flip the whole card subgraph to planning and legalize
        # itself (round-9 F1) - exactly the debt-skippable review gate to prevent.
        planningy = PRED.STAGES[-1] in {nodes[n].get("stage") for n in sub}
        for n in sub:
            if nodes[n].get("type") != "gate_check":
                continue
            st = nodes[n].get("stage")
            if planningy and st not in PRED.STAGES:
                errs.append(f"node {n}: planning gate_check needs a `stage` in STAGES (got {st!r})")
            if not planningy and st:
                errs.append(f"node {n}: gate_check declares stage {st!r} in a subgraph "
                            f"without the {PRED.STAGES[-1]} terminal - card subgraphs must "
                            "not declare `stage` (it would become debt-skippable), and a "
                            f"planning subgraph must include {PRED.STAGES[-1]}")
        # skip-reachability, scoped per subgraph (round-8 F1 + review H3): planning
        # roots must reach the 05-CONTRACT node itself - not just any out-edge-less
        # node - under EVERY subset of the skippable stages (2^5 = 32).
        terminals = {n for n in sub if not any(e["from"] == n for e in edges)}
        if planningy:
            term_nodes = {n for n in sub if nodes[n].get("stage") == PRED.STAGES[-1]}
            skippable = [s for s in PRED.SKIPPABLE_STAGES
                         if s in set(PRED.stage_map(topo).values())]
            for mask in range(1 << len(skippable)):
                subset = {skippable[i] for i in range(len(skippable)) if mask >> i & 1}
                if not (_skip_walk(topo, r, subset) & term_nodes):
                    errs.append(f"root {r}: the {PRED.STAGES[-1]} terminal is not "
                                f"reachable when skipped={sorted(subset)}")
                    break
        elif terminals and not (_skip_walk(topo, r, set()) & terminals):
            errs.append(f"root {r}: no terminal reachable")
    for n in nodes:
        if entry and n not in reach_all:
            errs.append(f"node {n}: unreachable from entry roots")
    errs += _lint_cycles(topo)
    if pin_path:
        try:
            with open(pin_path, encoding="utf-8") as fh:
                pin = fh.read().split()[0]
        except (OSError, IndexError):
            pin = None
        if pin != canonical_hash(topo):
            errs.append(f"pin mismatch vs {pin_path} (regenerate per harness/README.md "
                        "if the topology edit is intentional)")
    return errs


def cmd_graph_lint(con, a):
    rc = _guard_flags()
    if rc:
        return rc
    path = a.topology or TRUSTED_TOPOLOGY
    pin = a.pin or (TOPOLOGY_PIN if not a.topology else None)
    try:
        topo = load_topology(path)
    except (OSError, ValueError) as e:
        sys.stderr.write(f"flow-graph: lint: {e}\n")
        return 1
    try:
        errs = _lint(topo, pin_path=pin)
    except (AttributeError, TypeError, KeyError, RecursionError) as e:
        # Malformed shapes (node spec as string, edge as scalar, absurd depth) must
        # produce a lint line, never a traceback - lint is an operator-facing tool.
        sys.stderr.write(f"flow-graph: lint: malformed topology: {type(e).__name__}: {e}\n")
        return 1
    if errs:
        for e in errs:
            sys.stderr.write(f"flow-graph: lint: {e}\n")
        return 1
    print(json.dumps({"ok": True, "nodes": len(topo["nodes"]),
                      "edges": len(topo["edges"]),
                      "topology_hash": canonical_hash(topo)}))
    return 0


def cmd_graph_finish(con, a):
    """Close a lane: mark the execution done so `session` mints a fresh one for the next
    feature and `gc` can eventually reclaim it. Without a terminal transition nothing
    ever leaves `running`, so the journal grows forever and a completed planning lane
    answers "complete" for the feature that follows it."""
    rc = _guard_flags()
    if rc:
        return rc
    ex = _execution(con, a.execution)
    if ex is None:
        sys.stderr.write(f"flow-graph: no execution {a.execution}\n")
        return 1
    if ex["status"] in TERMINAL:
        return 0                      # idempotent
    opens = con.execute("SELECT COUNT(*) FROM graph_interrupt WHERE execution_id=? "
                        "AND status='open'", (a.execution,)).fetchone()[0]
    if opens and not getattr(a, "force", False):
        sys.stderr.write(f"flow-graph: {opens} interrupt(s) still open - resolve them or "
                         "pass --force\n")
        return 1
    with _db.transaction(con):
        con.execute("UPDATE graph_execution SET status='done', outcome=?, "
                    "updated_at=datetime('now') WHERE id=?",
                    (a.outcome or "complete", a.execution))
    return 0


def cmd_graph_gc(con, a):
    rc = _guard_flags()
    if rc:
        return rc
    project = a.project or _project_key()
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
                             "WHERE e.status IN ('running','paused') AND e.project=? "
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

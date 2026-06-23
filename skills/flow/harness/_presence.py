"""Tool presence probing for the inbound tool registry (stdlib only).

Ported from repository-harness crates/harness-cli/src/infrastructure.rs
(scan_tool_status, command_available, scan_target_resolves, http_reachable).

A probe NEVER raises: an absent tool is a fact to report (status 'missing'/'unknown'),
never an error that breaks a flow step. Status is one of: 'present', 'missing', 'unknown'.
Kind-aware so each agent runtime uses what it can orchestrate; an absent capability is a
clean skip. No third-party deps — only shutil / os / socket / urllib.
"""

import os
import shutil
import socket
from urllib.parse import urlparse

KINDS = ("cli", "binary", "mcp", "skill", "http")


def _path_or_pathext_exists(p):
    """os.path.exists, plus Windows PATHEXT fallback so an extensionless path resolves
    ('C:/Program Files/Git/cmd/git' -> git.EXE). shutil.which does NOT apply PATHEXT to a
    path that already contains a separator, so we check it ourselves."""
    if os.path.exists(p):
        return True
    if os.name == "nt":
        for ext in os.environ.get("PATHEXT", ".EXE;.BAT;.CMD").split(os.pathsep):
            if ext and os.path.exists(p + ext):
                return True
    return False


def _command_available(repo_root, command):
    """True if `command` resolves as a path or on PATH.

    Tries the whole string first so a path containing spaces (common on Windows) resolves,
    then the first whitespace token for the 'binary --arg' form. Each candidate is checked on
    PATH (shutil.which, which applies PATHEXT to bare names) and as a literal/repo-relative
    path (with a PATHEXT fallback for extensionless Windows paths)."""
    if not command:
        return False
    cmd = command.strip()
    if not cmd:                 # whitespace-only: a probe must never raise (no .split()[0] IndexError)
        return False
    candidates = [cmd]
    first = cmd.split()[0]
    if first != cmd:
        candidates.append(first)
    for cand in candidates:
        if shutil.which(cand):
            return True
        if _path_or_pathext_exists(cand):
            return True
        if repo_root and _path_or_pathext_exists(os.path.join(repo_root, cand)):
            return True
    return False


def _target_resolves(repo_root, target):
    """True if a declarative scan_target path (with ~ expansion) resolves on disk."""
    if not target:
        return False
    p = os.path.expanduser(target)
    if os.path.isabs(p):
        return os.path.exists(p)
    if os.path.exists(p):
        return True
    return bool(repo_root) and os.path.exists(os.path.join(repo_root, p))


def _http_reachable(target):
    """True if a TCP connection to the target's host:port succeeds within 2s. Never raises.

    Only http/https targets are probed (mirrors repository-harness): a non-http scheme or a
    bare word is not a reachable-by-TCP endpoint, and probing it would trigger slow DNS/connect
    on an unrelated host. Such targets fall through to the path-resolve fallback in scan_tool_status."""
    if not (target.startswith("http://") or target.startswith("https://")):
        return False
    try:
        u = urlparse(target, scheme="http")
        host = u.hostname
        if not host:
            return False
        port = u.port or (443 if u.scheme == "https" else 80)
        with socket.create_connection((host, port), timeout=2):
            return True
    except Exception:
        return False


def scan_tool_status(repo_root, kind, command, scan_target):
    """Kind-aware presence probe. Returns (status, detail); status in present/missing/unknown."""
    kind = (kind or "cli").lower()
    if kind in ("cli", "binary"):
        return ("present", command or "") if _command_available(repo_root, command) \
            else ("missing", command or "")
    if kind in ("mcp", "skill"):
        t = (scan_target or "").strip()
        if not t:
            return "unknown", "no scan target; agent confirms availability"
        return ("present", t) if _target_resolves(repo_root, t) else ("missing", t)
    if kind == "http":
        t = (scan_target or "").strip()
        if not t:
            return "unknown", "no scan target"
        if _http_reachable(t) or _target_resolves(repo_root, t):
            return "present", t
        return "missing", t
    return "unknown", ""

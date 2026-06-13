"""Pure harness domain logic: input types, risk lanes, trace tiers.

Ported from repository-harness (docs/FEATURE_INTAKE.md + crates/harness-cli/src/domain.rs).
No DB, no I/O - just rules, so it is trivially testable and reusable by both backends.
"""

# ---- input types (where work lands) ----
INPUT_TYPES = (
    "new_spec", "spec_slice", "change_request",
    "new_initiative", "maintenance", "harness_improvement",
)

# ---- risk lanes ----
LANES = ("tiny", "normal", "high_risk")
LANE_REQUIRED_TIER = {"tiny": 1, "normal": 2, "high_risk": 3}

# ---- risk checklist flags (FEATURE_INTAKE.md) ----
RISK_FLAGS = (
    "auth", "authorization", "data_model", "audit_security",
    "external_systems", "public_contracts", "cross_platform",
    "existing_behavior", "weak_proof", "multi_domain",
)

# Hard gates: any of these forces high_risk unless the human explicitly narrows scope.
HARD_GATE_FLAGS = (
    "auth", "authorization", "data_model", "audit_security",
    "external_systems",  # external provider behavior
    # "removing validation" is a process flag the caller signals via --removing-validation
)

TRACE_OUTCOMES = ("completed", "blocked", "partial", "failed")
STORY_STATUSES = ("planned", "in_progress", "implemented", "changed", "retired")
DECISION_STATUSES = ("proposed", "accepted", "superseded", "rejected")
BACKLOG_STATUSES = ("proposed", "accepted", "implemented", "rejected")
INTERVENTION_TYPES = ("correction", "override", "escalation", "approval")
INTERVENTION_SOURCES = ("human", "reviewer", "ci", "agent")


def normalize_flags(flags):
    """Accept a list/comma-string of flags; return validated lowercase tuple."""
    if not flags:
        return ()
    if isinstance(flags, str):
        flags = [f.strip() for f in flags.replace(";", ",").split(",")]
    out = []
    for f in flags:
        f = f.strip().lower().replace("-", "_").replace("/", "_")
        if f and f in RISK_FLAGS and f not in out:
            out.append(f)
    return tuple(out)


def classify_lane(flags, removing_validation=False, code_impact_high=False):
    """Return (lane, reason) from the FEATURE_INTAKE.md classification rules.

    0-1 flags -> tiny|normal (normal unless caller knows it is trivial)
    2-3 flags -> normal (stronger validation)
    4+ flags  -> high_risk
    any hard gate (or removing validation) -> high_risk
    """
    flags = normalize_flags(flags)
    hard = [f for f in flags if f in HARD_GATE_FLAGS]
    if removing_validation:
        hard = hard + ["removing_validation"]
    if hard:
        return "high_risk", "hard gate(s): " + ", ".join(hard)
    n = len(flags)
    if n >= 4:
        return "high_risk", f"{n} risk flags (4+ -> high_risk)"
    if n >= 2:
        return "normal", f"{n} risk flags (2-3 -> normal, stronger validation)"
    if code_impact_high:
        return "normal", "0-1 flags but non-trivial code impact"
    return "normal", f"{n} risk flag(s) (default normal; pass --lane tiny for trivial docs/copy)"


def lane_downgrade_allowed(recommended, requested, narrowed):
    """A hard-gate high_risk recommendation may only be lowered if the operator narrows scope."""
    if requested is None or requested == recommended:
        return True, ""
    rank = {"tiny": 0, "normal": 1, "high_risk": 2}
    if rank.get(requested, 1) < rank.get(recommended, 1):
        if recommended == "high_risk" and not narrowed:
            return False, ("refusing to downgrade a hard-gate high_risk lane to "
                           f"'{requested}' without --narrow-scope (operator must accept the exposure)")
    return True, ""


def score_trace(rec):
    """Return (achieved_tier, missing_for_next) for a trace record dict.

    tier 1 (minimal): task_summary >=10 chars AND outcome present.
    tier 2 (standard): + intake_id, story_id, agent, actions_taken, files_read,
                       files_changed, AND at least one of errors / harness_friction.
    tier 3 (detailed): + decisions_made, errors, harness_friction, AND one of
                       duration_seconds / token_estimate / notes.
    """
    def has(k):
        v = rec.get(k)
        return v is not None and str(v).strip() != "" and str(v).strip() not in ("[]", "null")

    # tier 1
    t1_missing = []
    if not (has("task_summary") and len(str(rec.get("task_summary", "")).strip()) >= 10):
        t1_missing.append("task_summary>=10chars")
    if not has("outcome"):
        t1_missing.append("outcome")
    if t1_missing:
        return 0, t1_missing  # below minimal

    # tier 2
    t2_need = ["intake_id", "story_id", "agent", "actions_taken", "files_read", "files_changed"]
    t2_missing = [k for k in t2_need if not has(k)]
    if not (has("errors") or has("harness_friction")):
        t2_missing.append("errors|harness_friction")
    if t2_missing:
        return 1, t2_missing

    # tier 3
    t3_need = ["decisions_made", "errors", "harness_friction"]
    t3_missing = [k for k in t3_need if not has(k)]
    if not (has("duration_seconds") or has("token_estimate") or has("notes")):
        t3_missing.append("duration_seconds|token_estimate|notes")
    if t3_missing:
        return 2, t3_missing

    return 3, []


def tier_verdict(lane, achieved):
    """Human verdict comparing achieved trace tier against what the lane requires."""
    required = LANE_REQUIRED_TIER.get(lane, 2)
    ok = achieved >= required
    return ok, required

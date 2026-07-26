"""Predicate registry + stage mapping for the graph executor (stdlib only).

The registry is EXACTLY {always, review_green, review_red}: predicates read only
durable artifacts (here, the recorded gate exit in a checkpoint manifest) - never
LLMs, never the network. Debt-skips are NOT predicates: they are a plan_next
traversal semantic keyed on each gate_check node's explicit `stage` field.
"""

# Keep in sync with flow.sh STAGES (flow.sh:122) - the closed set every planning
# gate_check node's `stage` field must belong to. 05-contract is never skippable
# (cmd_skip's primary guard), so the skippable set is STAGES minus the last.
STAGES = ["00-idea", "01-research", "02-scope", "03-prd", "04-adr", "05-contract"]
SKIPPABLE_STAGES = STAGES[:-1]


def always(manifest):
    return True


def review_green(manifest):
    gate = (manifest or {}).get("gate") or {}
    return gate.get("exit") == 0


def review_red(manifest):
    gate = (manifest or {}).get("gate") or {}
    return gate.get("exit") not in (None, 0)


REGISTRY = {"always": always, "review_green": review_green, "review_red": review_red}


def evaluate(name, manifest):
    fn = REGISTRY.get(name)
    if fn is None:
        raise ValueError(f"unregistered predicate: {name}")
    return fn(manifest)


def stage_map(topo):
    """node-id -> stage-name for every gate_check node carrying a `stage` field.
    (Card-subgraph gate_check nodes MUST NOT declare `stage` - a stage on
    card-review would make the review gate debt-skippable; lint enforces this.)"""
    out = {}
    for name, spec in topo.get("nodes", {}).items():
        if spec.get("type") == "gate_check" and spec.get("stage"):
            out[name] = spec["stage"]
    return out

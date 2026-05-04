"""build_topology.py — turn a local ARG dump into graph-vis-compatible graph.json.

See ``TOPOLOGY_GRAPH_PROMPT.md`` and the session plan for the full
contract. Key invariants:

- Deterministic: same ARG dump + same rules ⇒ byte-identical output.
- Offline at runtime: no network, no LLM calls.
- Output schema: matches `graph-vis` (`{nodes, edges, annotations}`)
  with extra metadata fields that graph-vis ignores.

Usage
-----
::

    python build_topology.py --arg-file <arg.json> [options]

Options
-------
--arg-file PATH         (required) Local ARG dump from fetch_arg_raw.py.
--subscription-id ID    Subscription scope; only this sub seeds the BFS.
                        Cross-subscription connections still get walked.
--rules PATH            Path to connection_rules.json
                        (default: rules/connection_rules.json next to this script).
--out PATH              Output graph.json
                        (default: output/graph.json next to this script).
--no-tenant-root        Skip the synthetic tenant-root parent above subscriptions.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from pathlib import Path
from typing import Any, Iterable, Iterator

from type_mapping import map_type

# --------------------------------------------------------------------- #
# ARM ID parsing                                                        #
# --------------------------------------------------------------------- #

# All ARM IDs in the graph are stored lowercased. ARG returns mixed
# casing inconsistently (sometimes Resources/.../ResourceGroup, sometimes
# resourcegroup), so we canonicalise once at ingest and lowercase every
# id-shaped string at every step.

SUBSCRIPTIONS_KW = "subscriptions"
RESOURCE_GROUPS_KW = "resourcegroups"
PROVIDERS_KW = "providers"
TENANT_ROOT_ID = "tenant-root"


def canonical_id(arm_id: str) -> str:
    """Lowercase + strip trailing slashes. Empty / non-string → ``""``."""
    if not isinstance(arm_id, str):
        return ""
    return arm_id.strip().rstrip("/").lower()


def parse_arm_id(arm_id: str) -> dict[str, Any]:
    """Decompose an ARM ID into its components.

    Returns a dict with keys (any may be empty):
      - ``subscription_id``
      - ``resource_group``
      - ``arm_type``      e.g. ``Microsoft.Compute/virtualMachines/extensions``
                          (preserves canonical Microsoft casing where possible
                          by reading from the un-lowercased input; falls back
                          to lowercased segments).
      - ``name``          last name segment (the resource's own name)
      - ``parent_id``     canonical ID of the structural parent
                          (parent resource > resource group > subscription
                          > tenant root)

    The function tolerates partial IDs (just a subscription, just an
    RG, etc.) and synthetic IDs (``tenant-root``).
    """
    if not isinstance(arm_id, str) or not arm_id:
        return {}

    raw = arm_id.strip().rstrip("/")
    if raw == TENANT_ROOT_ID:
        return {"arm_type": "tenant", "name": "Tenant", "parent_id": ""}

    raw_parts = raw.lstrip("/").split("/")
    parts = [p.lower() for p in raw_parts]

    info: dict[str, Any] = {
        "subscription_id": "",
        "resource_group": "",
        "arm_type": "",
        "name": "",
        "parent_id": "",
    }

    # /subscriptions/{sub}
    if len(parts) >= 2 and parts[0] == SUBSCRIPTIONS_KW:
        info["subscription_id"] = parts[1]

    # /subscriptions/{sub}/resourceGroups/{rg}
    if len(parts) >= 4 and parts[2] == RESOURCE_GROUPS_KW:
        info["resource_group"] = parts[3]

    # /subscriptions/{sub}/resourceGroups/{rg}/providers/{ns}/{type1}/{name1}/...
    if len(parts) >= 8 and parts[4] == PROVIDERS_KW:
        provider = raw_parts[5]  # preserve canonical casing for "Microsoft.X"
        type_name_pairs = list(zip(raw_parts[6::2], raw_parts[7::2]))
        if not type_name_pairs:
            return info

        type_segments = [tn[0] for tn in type_name_pairs]
        name_segments = [tn[1] for tn in type_name_pairs]
        info["arm_type"] = f"{provider}/" + "/".join(type_segments)
        info["name"] = name_segments[-1]

        if len(type_name_pairs) > 1:
            # Nested ARM resource — parent is the parent resource ID.
            parent_path = (
                f"/subscriptions/{info['subscription_id']}"
                f"/resourcegroups/{info['resource_group']}"
                f"/providers/{provider.lower()}/"
            )
            parent_path += "/".join(
                f"{t.lower()}/{n.lower()}"
                for t, n in type_name_pairs[:-1]
            )
            info["parent_id"] = parent_path
        else:
            # Top-level resource — parent is the RG.
            info["parent_id"] = (
                f"/subscriptions/{info['subscription_id']}"
                f"/resourcegroups/{info['resource_group']}"
            )
        return info

    # Just a resource group
    if len(parts) == 4 and parts[2] == RESOURCE_GROUPS_KW:
        info["arm_type"] = "resourceGroup"
        info["name"] = raw_parts[3]
        info["parent_id"] = f"/subscriptions/{info['subscription_id']}"
        return info

    # Just a subscription
    if len(parts) == 2 and parts[0] == SUBSCRIPTIONS_KW:
        info["arm_type"] = "subscription"
        info["name"] = raw_parts[1]
        info["parent_id"] = TENANT_ROOT_ID
        return info

    return info


def subscription_id_of(arm_id: str) -> str:
    """Extract the subscription id from an ARM id, or ``""``."""
    parts = canonical_id(arm_id).lstrip("/").split("/")
    if len(parts) >= 2 and parts[0] == SUBSCRIPTIONS_KW:
        return parts[1]
    return ""


def resource_group_of(arm_id: str) -> str:
    """Extract the resource group from an ARM id, or ``""``."""
    parts = canonical_id(arm_id).lstrip("/").split("/")
    if len(parts) >= 4 and parts[2] == RESOURCE_GROUPS_KW:
        return parts[3]
    return ""


def synth_subscription_id(sub_guid: str) -> str:
    return f"/subscriptions/{sub_guid.lower()}"


def synth_resource_group_id(sub_guid: str, rg_name: str) -> str:
    return f"/subscriptions/{sub_guid.lower()}/resourcegroups/{rg_name.lower()}"


# --------------------------------------------------------------------- #
# Property path walker                                                  #
# --------------------------------------------------------------------- #

def walk_path(obj: Any, path: str) -> Iterator[Any]:
    """Yield every value matched by a dotted path, with ``[]`` for arrays.

    Examples
    --------
    ``properties.foo.bar``      → at most one yielded value (or zero).
    ``properties.items[]``      → one yielded value per array element.
    ``properties.items[].name`` → one yielded value per array element's ``name``.

    Missing keys / unexpected types short-circuit silently — bad ARG data
    must never crash the script.
    """
    if not path:
        yield obj
        return
    segments = path.split(".")
    yield from _walk([obj], segments)


def _walk(values: list[Any], remaining: list[str]) -> Iterator[Any]:
    if not remaining:
        yield from values
        return
    head = remaining[0]
    rest = remaining[1:]
    is_array = head.endswith("[]")
    key = head[:-2] if is_array else head
    next_values: list[Any] = []
    for v in values:
        if not isinstance(v, dict):
            continue
        if key not in v:
            continue
        child = v[key]
        if is_array:
            if isinstance(child, list):
                next_values.extend(child)
        else:
            next_values.append(child)
    yield from _walk(next_values, rest)


def extract_resource_ids(value: Any, value_shape: str) -> Iterator[str]:
    """Pull resource ID strings out of a value according to its shape.

    Tolerates the realistic mess: nested ``id`` field, lists of strings,
    lists of objects, scalars at the end of the path.
    """
    if value is None:
        return
    shape = value_shape or "resourceId"

    if shape == "resourceId":
        if isinstance(value, str):
            yield value
        elif isinstance(value, dict) and isinstance(value.get("id"), str):
            yield value["id"]  # robustness: rule mis-classified as plain id
    elif shape == "array<resourceId>":
        if isinstance(value, list):
            for v in value:
                if isinstance(v, str):
                    yield v
                elif isinstance(v, dict) and isinstance(v.get("id"), str):
                    yield v["id"]
    elif shape in ("object{id:resourceId}", "armSubResource"):
        if isinstance(value, dict) and isinstance(value.get("id"), str):
            yield value["id"]
        elif isinstance(value, str):
            yield value


# --------------------------------------------------------------------- #
# Rule indexing                                                         #
# --------------------------------------------------------------------- #

def index_rules(rules: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    """Group rules by lowercased ``sourceType`` for O(1) lookup."""
    by_type: dict[str, list[dict[str, Any]]] = {}
    for r in rules:
        st = r.get("sourceType", "").lower()
        if not st:
            continue
        by_type.setdefault(st, []).append(r)
    return by_type


# --------------------------------------------------------------------- #
# ARG dump loader                                                       #
# --------------------------------------------------------------------- #

def load_arg(path: Path) -> list[dict[str, Any]]:
    """Read either ``{data: [...], ...}`` (fetch_arg_raw.py) or a bare list."""
    with path.open("r", encoding="utf-8") as fh:
        payload = json.load(fh)
    if isinstance(payload, dict) and isinstance(payload.get("data"), list):
        rows = payload["data"]
    elif isinstance(payload, list):
        rows = payload
    else:
        raise ValueError(
            f"{path}: expected a JSON list or a dict with a 'data' list"
        )
    if not all(isinstance(r, dict) for r in rows):
        raise ValueError(f"{path}: every ARG row must be a JSON object")
    return rows


# --------------------------------------------------------------------- #
# Graph builder                                                         #
# --------------------------------------------------------------------- #

class GraphBuilder:
    """Accumulator for nodes / edges / annotations.

    Internal storage uses dicts keyed on canonical IDs / tuples so we can
    deduplicate as we go. ``finalize()`` produces the sorted output.
    """

    def __init__(self) -> None:
        self._nodes: dict[str, dict[str, Any]] = {}
        # Edges keyed by (from, to). Last-write-wins on metadata.
        self._edges: dict[tuple[str, str], dict[str, str]] = {}
        # Annotations keyed by (from, to, label).
        self._annotations: dict[tuple[str, str, str], dict[str, Any]] = {}

    # -- node helpers ----------------------------------------------------

    def add_node(self, node: dict[str, Any]) -> None:
        """Insert or merge a node by id. Merge prefers ``present=True``."""
        nid = node["id"]
        existing = self._nodes.get(nid)
        if existing is None:
            self._nodes[nid] = node
            return
        # Merge: a real (present) node always wins over a stub.
        if not existing.get("present", True) and node.get("present", True):
            self._nodes[nid] = node

    def has_node(self, node_id: str) -> bool:
        return node_id in self._nodes

    def add_stub(self, target_id: str) -> None:
        """Add a placeholder node for a reference target absent from the dump."""
        if target_id in self._nodes:
            return
        info = parse_arm_id(target_id)
        arm_type = info.get("arm_type", "")
        label, icon = map_type(arm_type or "resource")
        name = info.get("name") or target_id.rsplit("/", 1)[-1] or target_id
        self._nodes[target_id] = {
            "id": target_id,
            "label": name,
            "type": label,
            "icon": icon,
            "armType": arm_type or None,
            "armId": target_id,
            "subscriptionId": info.get("subscription_id") or None,
            "resourceGroup": info.get("resource_group") or None,
            "location": None,
            "present": False,
        }

    # -- edge helpers ----------------------------------------------------

    def add_edge(self, src: str, dst: str) -> None:
        if not src or not dst or src == dst:
            return
        self._edges[(src, dst)] = {"from": src, "to": dst}

    def add_annotation(
        self,
        src: str,
        dst: str,
        label: str,
        *,
        cross_subscription: bool,
        dangling: bool,
    ) -> None:
        if not src or not dst or src == dst:
            return
        key = (src, dst, label or "")
        self._annotations[key] = {
            "from": src,
            "to": dst,
            "label": label or "",
            "kind": "connection",
            "crossSubscription": bool(cross_subscription),
            "dangling": bool(dangling),
        }

    # -- finalize --------------------------------------------------------

    def finalize(self) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
        nodes = sorted(self._nodes.values(), key=lambda n: n["id"])
        edges = sorted(self._edges.values(), key=lambda e: (e["from"], e["to"]))
        annotations = sorted(
            self._annotations.values(),
            key=lambda a: (a["from"], a["to"], a["label"]),
        )
        # Strip empty labels from annotations to keep the wire shape clean.
        for a in annotations:
            if not a["label"]:
                a.pop("label", None)
        return nodes, edges, annotations


# --------------------------------------------------------------------- #
# Resource → node                                                       #
# --------------------------------------------------------------------- #

def resource_to_node(row: dict[str, Any]) -> dict[str, Any]:
    """Project an ARG row into the graph-vis node shape."""
    arm_id_raw = row.get("id") or ""
    arm_id = canonical_id(arm_id_raw)
    arm_type = row.get("type") or ""
    info = parse_arm_id(arm_id_raw)

    name = row.get("name") or info.get("name") or arm_id.rsplit("/", 1)[-1]
    label, icon = map_type(arm_type or info.get("arm_type", ""))

    return {
        "id": arm_id,
        "label": str(name),
        "type": label,
        "icon": icon,
        "armType": arm_type or info.get("arm_type") or None,
        "armId": arm_id_raw,
        "subscriptionId": (row.get("subscriptionId") or info.get("subscription_id") or "").lower() or None,
        "resourceGroup": (row.get("resourceGroup") or info.get("resource_group") or "").lower() or None,
        "location": row.get("location") or None,
        "present": True,
    }


def synthetic_subscription_node(sub_guid: str) -> dict[str, Any]:
    label, icon = map_type("subscription")
    return {
        "id": synth_subscription_id(sub_guid),
        "label": sub_guid,
        "type": label,
        "icon": icon,
        "armType": "Microsoft.Resources/subscriptions",
        "armId": synth_subscription_id(sub_guid),
        "subscriptionId": sub_guid.lower(),
        "resourceGroup": None,
        "location": None,
        "present": True,
    }


def synthetic_rg_node(sub_guid: str, rg_name: str) -> dict[str, Any]:
    label, icon = map_type("resourceGroup")
    return {
        "id": synth_resource_group_id(sub_guid, rg_name),
        "label": rg_name,
        "type": label,
        "icon": icon,
        "armType": "Microsoft.Resources/resourceGroups",
        "armId": synth_resource_group_id(sub_guid, rg_name),
        "subscriptionId": sub_guid.lower(),
        "resourceGroup": rg_name.lower(),
        "location": None,
        "present": True,
    }


def tenant_root_node() -> dict[str, Any]:
    label, icon = map_type("tenant")
    return {
        "id": TENANT_ROOT_ID,
        "label": "Tenant",
        "type": label,
        "icon": icon,
        "armType": None,
        "armId": None,
        "subscriptionId": None,
        "resourceGroup": None,
        "location": None,
        "present": True,
    }


# --------------------------------------------------------------------- #
# Main BFS                                                              #
# --------------------------------------------------------------------- #

def build_graph(
    arg_rows: list[dict[str, Any]],
    rules_by_type: dict[str, list[dict[str, Any]]],
    *,
    seed_subscription: str | None,
    add_tenant_root: bool,
) -> dict[str, Any]:
    builder = GraphBuilder()

    # Index resources by canonical ARM id ------------------------------
    by_id: dict[str, dict[str, Any]] = {}
    by_sub: dict[str, list[dict[str, Any]]] = {}
    all_subs: set[str] = set()

    for row in arg_rows:
        arm_id = canonical_id(row.get("id") or "")
        if not arm_id:
            continue
        by_id[arm_id] = row
        sub = (
            (row.get("subscriptionId") or "").lower()
            or subscription_id_of(arm_id)
        )
        if sub:
            all_subs.add(sub)
            by_sub.setdefault(sub, []).append(row)

    # Determine BFS scope ----------------------------------------------
    scope_mode = "tenant"
    root_sub: str | None = None
    if seed_subscription:
        scope_mode = "subscription"
        root_sub = seed_subscription.lower()

    queue: deque[str] = deque()
    visited: set[str] = set()

    if root_sub:
        queue.append(root_sub)
    elif all_subs:
        queue.append(sorted(all_subs)[0])

    # Process subscriptions --------------------------------------------
    pending_cross_sub_targets: set[str] = set()

    while queue or (scope_mode == "tenant" and (all_subs - visited)):
        if not queue:
            # Disconnected component: pick lex-smallest unvisited sub.
            remaining = sorted(all_subs - visited)
            if not remaining:
                break
            queue.append(remaining[0])

        sub = queue.popleft()
        if sub in visited:
            continue
        visited.add(sub)

        # Add subscription node + RG nodes synthesised from rows.
        builder.add_node(synthetic_subscription_node(sub))

        rgs_in_sub: set[str] = set()
        for row in by_sub.get(sub, []):
            rg = (row.get("resourceGroup") or resource_group_of(row.get("id") or "")).lower()
            if rg:
                rgs_in_sub.add(rg)

        for rg in sorted(rgs_in_sub):
            rg_node = synthetic_rg_node(sub, rg)
            builder.add_node(rg_node)
            builder.add_edge(synth_subscription_id(sub), rg_node["id"])

        # Process every resource in this subscription.
        for row in by_sub.get(sub, []):
            node = resource_to_node(row)
            builder.add_node(node)

            # Ownership edge to structural parent (RG or parent resource).
            info = parse_arm_id(row.get("id") or "")
            parent_id = info.get("parent_id") or ""
            if parent_id:
                builder.add_edge(canonical_id(parent_id), node["id"])

            # Connection edges from rules.
            arm_type = (row.get("type") or info.get("arm_type", "")).lower()
            for rule in rules_by_type.get(arm_type, []):
                _apply_rule(rule, row, node, builder, by_id, sub,
                            queue, visited, all_subs, scope_mode,
                            pending_cross_sub_targets)

    # Tenant root + edges to subscriptions -----------------------------
    if add_tenant_root:
        builder.add_node(tenant_root_node())
        for sub in sorted(visited):
            builder.add_edge(TENANT_ROOT_ID, synth_subscription_id(sub))

    nodes, edges, annotations = builder.finalize()

    return {
        "schemaVersion": 1,
        "scope": {
            "mode": scope_mode,
            "rootSubscriptionId": root_sub,
            "visitedSubscriptions": sorted(visited),
        },
        "nodes": nodes,
        "edges": edges,
        "annotations": annotations,
    }


def _apply_rule(
    rule: dict[str, Any],
    row: dict[str, Any],
    src_node: dict[str, Any],
    builder: GraphBuilder,
    by_id: dict[str, dict[str, Any]],
    src_sub: str,
    queue: deque[str],
    visited: set[str],
    all_subs: set[str],
    scope_mode: str,
    pending_cross_sub_targets: set[str],
) -> None:
    """Resolve one rule against one resource row and emit annotations.

    Side-effects: enqueues newly-referenced subscriptions for tenant-mode
    BFS, even in subscription-mode the cross-subscription targets are
    *recorded* (annotation added) but not necessarily walked.
    """
    src_id = src_node["id"]
    target_type_filter = (rule.get("targetType") or "").lower()
    label = rule.get("label", "")
    value_shape = rule.get("valueShape", "resourceId")
    path = rule.get("propertyPath", "")

    for value in walk_path(row, path):
        for raw_target in extract_resource_ids(value, value_shape):
            target_id = canonical_id(raw_target)
            if not target_id:
                continue

            # Type filter: '*' / '' means any type accepted.
            if target_type_filter and target_type_filter != "*":
                target_type = parse_arm_id(raw_target).get("arm_type", "").lower()
                if target_type != target_type_filter:
                    # Don't match — the rule was specific and the target isn't it.
                    continue

            # Cross-subscription bookkeeping.
            target_sub = subscription_id_of(raw_target)
            cross_sub = bool(target_sub) and target_sub != src_sub

            # Tenant mode: enqueue referenced subs we haven't visited.
            if scope_mode == "tenant" and target_sub and target_sub not in visited:
                if target_sub in all_subs and target_sub not in queue:
                    queue.append(target_sub)
            # Subscription mode: still record the edge, also enqueue the
            # referenced sub so downstream resources get added (per the
            # prompt's behaviour).
            elif scope_mode == "subscription" and target_sub and target_sub not in visited:
                if target_sub in all_subs and target_sub not in queue:
                    queue.append(target_sub)

            # Dangling stub if the target isn't in the dump.
            dangling = target_id not in by_id
            if dangling:
                builder.add_stub(target_id)

            builder.add_annotation(
                src_id,
                target_id,
                label,
                cross_subscription=cross_sub,
                dangling=dangling,
            )


# --------------------------------------------------------------------- #
# CLI                                                                   #
# --------------------------------------------------------------------- #

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    here = Path(__file__).resolve().parent
    p = argparse.ArgumentParser(
        description="Build a graph-vis-compatible graph.json from an ARG dump."
    )
    p.add_argument("--arg-file", required=True, type=Path,
                   help="Local ARG dump (output of fetch_arg_raw.py).")
    p.add_argument("--subscription-id", default=None,
                   help="Subscription-scope BFS seed. Omit for tenant scope.")
    p.add_argument("--rules", type=Path, default=here / "rules" / "connection_rules.json",
                   help="Path to connection_rules.json.")
    p.add_argument("--out", type=Path, default=here / "output" / "graph.json",
                   help="Output path for graph.json.")
    p.add_argument("--no-tenant-root", action="store_true",
                   help="Skip the synthetic tenant-root parent above subscriptions.")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if not args.arg_file.exists():
        print(f"error: --arg-file not found: {args.arg_file}", file=sys.stderr)
        return 2

    arg_rows = load_arg(args.arg_file)

    if args.rules.exists():
        with args.rules.open("r", encoding="utf-8") as fh:
            rules_doc = json.load(fh)
        rules = rules_doc.get("rules", [])
    else:
        print(f"warning: --rules not found, proceeding with empty registry: {args.rules}",
              file=sys.stderr)
        rules = []

    rules_by_type = index_rules(rules)
    graph = build_graph(
        arg_rows,
        rules_by_type,
        seed_subscription=args.subscription_id,
        add_tenant_root=not args.no_tenant_root,
    )

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(graph, fh, indent=2, sort_keys=True, ensure_ascii=False)
        fh.write("\n")

    print(
        f"wrote {args.out} "
        f"(nodes={len(graph['nodes'])}, "
        f"edges={len(graph['edges'])}, "
        f"annotations={len(graph['annotations'])}, "
        f"visitedSubs={len(graph['scope']['visitedSubscriptions'])})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

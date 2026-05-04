# Topology Graph Generator

Turns a local Azure Resource Graph (ARG) dump into a `graph.json` file
consumable by the [`graph-vis`](https://github.com/micha31r/graph-vis)
library. Backend-only — there is no UI in this directory.

## Quick start

```powershell
# 1. Get an ARG dump. Requires `az login` (or any DefaultAzureCredential
#    source) with read access to the target tenant. Uses PEP-723 inline
#    deps — `uv` installs them on the fly:
uv run fetch_arg_raw.py > arg.json

# 2. Build the graph.
python build_topology.py --arg-file arg.json
# → writes output/graph.json
```

That's it. `requirements.txt` is empty for `build_topology.py` — Python
stdlib only, no third-party runtime deps. `fetch_arg_raw.py` declares
its own deps inline (`azure-identity`, `requests`) so `uv run` (or
`pip install azure-identity requests` then `python fetch_arg_raw.py`)
is enough.

## CLI

```
python build_topology.py --arg-file <path> [options]
```

| Flag | Behaviour |
|---|---|
| `--arg-file PATH` *(required)* | Local ARG dump. Accepts either the raw `{data: [...], count: ...}` shape from `fetch_arg_raw.py` or a bare JSON array of resource rows. |
| `--subscription-id ID` | Subscription scope: only this sub seeds the BFS. Cross-subscription connections are still recorded and any referenced subs that exist in the dump are walked. Omit for **tenant scope** (walks every subscription). |
| `--rules PATH` | Default: `rules/connection_rules.json` next to this script. |
| `--out PATH` | Default: `output/graph.json` next to this script. |
| `--no-tenant-root` | Skip the synthetic `tenant-root` parent above subscriptions (multi-root output). |

## Output schema

The output is **graph-vis compatible** — it has the three fields
graph-vis needs (`nodes`, `edges`, `annotations`) plus extra metadata
that graph-vis ignores. Pass it straight to `<GraphCanvas data={...} />`.

```jsonc
{
  "schemaVersion": 1,
  "scope": {
    "mode": "tenant",                       // or "subscription"
    "rootSubscriptionId": null,             // GUID when mode=subscription
    "visitedSubscriptions": ["...", "..."]
  },
  "nodes": [
    {
      // graph-vis required fields:
      "id":    "<lowercased ARM id, or 'tenant-root'>",
      "label": "<short display name>",
      "type":  "Virtual Machine",           // human-readable mapped from armType
      "icon":  "virtual-machine",           // kebab-case icon key
      // Extras (ignored by graph-vis, useful for downstream tools):
      "armType":        "Microsoft.Compute/virtualMachines",
      "armId":          "/subscriptions/.../...",
      "subscriptionId": "...",
      "resourceGroup":  "...",
      "location":       "eastus",
      "present":        true                // false → stub for a missing target
    }
  ],
  "edges": [
    // Structural / ownership edges (parent → child).
    // Drives graph-vis's radial tree layout.
    { "from": "<parent id>", "to": "<child id>" }
  ],
  "annotations": [
    // Connection edges from the rule registry.
    // Overlay only — they don't affect the radial layout.
    {
      "from":              "<source id>",
      "to":                "<target id>",
      "label":             "managed by",     // omitted if rule has no label
      "kind":              "connection",
      "crossSubscription": false,
      "dangling":          false             // true if 'to' is a stub
    }
  ]
}
```

### Node id conventions

| Node           | id                                                                 |
|----------------|--------------------------------------------------------------------|
| Tenant root    | `tenant-root`                                                       |
| Subscription   | `/subscriptions/<sub-guid>`                                         |
| Resource group | `/subscriptions/<sub-guid>/resourcegroups/<rg-name>`                |
| ARM resource   | the row's `id` field, **lowercased**, trailing slash stripped       |

All ids are lowercased — ARG returns inconsistent casing and the script
canonicalises so dedup works.

### Icon keys

The `icon` field is a kebab-case key (e.g. `virtual-machine`,
`storage-account`, `key-vault`, `resource-group`, `subscription`,
`tenant`, plus `resource` for unknown types). graph-vis is icon-agnostic
— **the consumer is responsible for supplying SVGs** under those keys
via the `iconSources` prop. See `type_mapping.py` for the full list of
mapped types; it's the source of truth for which keys you need to
provide. Unknown ARM types fall back to the `resource` key, so as long
as you ship a generic `resource.svg` everything renders.

### Edges vs annotations

- **`edges`** are structural — they form the ownership tree
  (`tenant-root → subscription → RG → resource → nested resource`).
  graph-vis uses them for the radial layout; root nodes (no incoming
  edges) get pinned.
- **`annotations`** are non-structural overlay edges from the
  connection rule registry (e.g. *VM → "uses os disk" → Disk*). They
  carry a human label and don't affect the radial layout.

Without the synthetic tenant root (`--no-tenant-root`), every
subscription becomes its own pinned root. With it, you get one tidy
spider-web rooted at the tenant.

## Determinism contract

Same `--arg-file` + same `--rules` ⇒ **byte-identical** `graph.json`.

Guaranteed by:
- All set/dict iteration is sorted before serialisation.
- Node ids are stable (lowercased ARM id, or canonical synthetic id).
- JSON is written with `indent=2`, `sort_keys=True`, trailing newline.
- No timestamps, UUIDs, or `os.environ` reads in the output.

Verify with:
```powershell
python build_topology.py --arg-file arg.json --out out1.json
python build_topology.py --arg-file arg.json --out out2.json
(Get-FileHash out1.json).Hash -eq (Get-FileHash out2.json).Hash   # → True
```

## Privacy guardrails

- **ARG data never leaves the machine** during script execution. No
  network calls, no telemetry, no LLM calls.
- `secrets_filter.py` provides `redact()`, `redact_json()`, `is_safe()`,
  and `assert_safe()`. Use these at any boundary that might transmit
  ARG content (Phase-1 sub-agent prompts, log lines that quote
  resources, anything sent to `web_search`/`web_fetch`).
- `output/` is gitignored — generated graphs may contain customer
  resource ids, names, locations.
- The `rules/` directory is **safe to commit** — it contains only
  resource type names and Microsoft documentation references, never
  customer data.

## Connection rule registry (`rules/`)

```
rules/
├── checklist.md                # Phase-1 progress tracker (committed)
├── connection_rules.json       # consolidated registry (committed)
└── per_provider/               # one file per RP namespace (committed)
    ├── Microsoft.Compute.json
    ├── Microsoft.Network.json
    └── Microsoft.Mixed.json    # Web/Sql/AKS/etc. (rename when each grows)
```

Each rule says *"this property on type X holds a reference to a resource
of type Y; label the edge Z"*. Schema:

```jsonc
{
  "schemaVersion": 1,
  "rules": [
    {
      "sourceType":       "Microsoft.Compute/disks",
      "propertyPath":     "properties.managedBy",
      "valueShape":       "resourceId",  // resourceId | array<resourceId>
                                          //          | object{id:resourceId}
                                          //          | armSubResource
      "cardinality":      "0..1",
      "targetType":       "Microsoft.Compute/virtualMachines",  // or "*" for any
      "relationshipKind": "connection",
      "label":            "managed by",
      "docsRef":          "https://learn.microsoft.com/...",
      "notes":            ""
    }
  ]
}
```

### Adding new rules

1. Find the property in [Microsoft Learn ARM template
   reference](https://learn.microsoft.com/en-us/azure/templates/) for
   the source type.
2. Add the rule to the appropriate `per_provider/<Namespace>.json`. Keep
   `sourceType` / `targetType` in canonical Microsoft casing; the
   script lowercases at compare time.
3. Re-merge:

   ```powershell
   cd experiments\graph
   python -c @"
   import json, glob
   files = sorted(glob.glob('rules/per_provider/*.json'))
   all_rules, seen = [], set()
   for f in files:
       with open(f, 'r', encoding='utf-8') as fh:
           for r in json.load(fh).get('rules', []):
               key = (r['sourceType'].lower(), r['propertyPath'],
                      r['targetType'].lower(), r['relationshipKind'])
               if key in seen: continue
               seen.add(key); all_rules.append(r)
   all_rules.sort(key=lambda r: (r['sourceType'].lower(),
                                 r['propertyPath'],
                                 r['targetType'].lower()))
   with open('rules/connection_rules.json', 'w', encoding='utf-8',
             newline='\n') as fh:
       json.dump({'schemaVersion': 1, 'rules': all_rules}, fh,
                 indent=2, sort_keys=True); fh.write('\n')
"@
   ```

The current registry is a hand-written **seed** covering ~30 of the
highest-value references (Compute, Network, Web, AKS, App Insights,
SQL). Comprehensive coverage of every Azure RP is a separate effort —
see `rules/checklist.md` for the per-namespace breakdown and the prompt
template for a research sub-agent.

### Property path syntax

| Form | Meaning |
|---|---|
| `properties.foo.bar`   | walk a nested object |
| `properties.foo[]`     | walk an array; each element becomes a value |
| `properties.foo[].bar` | walk an array, then `.bar` on each element |

Combine with `valueShape`:

| `valueShape` | Value at the end of `propertyPath` |
|---|---|
| `resourceId`              | a string (the ARM id directly) |
| `array<resourceId>`       | a list of strings (or `{id: ...}` objects) |
| `object{id:resourceId}`   | an object with an `id` property |
| `armSubResource`          | string or `{id: ...}` (tolerant) |

### `targetType` wildcard

For polymorphic references (e.g.
`Microsoft.Network/privateEndpoints.privateLinkServiceConnections[].privateLinkServiceId`
which can target any PaaS resource), use `"targetType": "*"`. The
script will accept the reference regardless of the target's actual type.

## File layout

```
experiments/graph/
├── README.md                   ← this file
├── .gitignore                  ← ignores output/
├── requirements.txt            ← stdlib-only stub
├── fetch_arg_raw.py            ← Phase-0 ARG fetch (PEP-723 inline deps)
├── build_topology.py           ← Phase-2 CLI
├── secrets_filter.py           ← regex redaction
├── type_mapping.py             ← ARM type → (label, icon key)
├── rules/
│   ├── checklist.md
│   ├── connection_rules.json   ← merged registry
│   └── per_provider/
│       ├── Microsoft.Compute.json
│       ├── Microsoft.Network.json
│       └── Microsoft.Mixed.json
└── output/                     ← gitignored; graph.json lands here
```

## Algorithm

See `TOPOLOGY_GRAPH_PROMPT.md` §5.2 for the original spec. Summary:

1. Load ARG; index resources by lowercased id; group by subscription.
2. Seed the BFS queue (subscription scope: `[--subscription-id]`;
   tenant scope: lex-smallest sub guid in the data).
3. For each subscription pulled off the queue:
   - Add the synthetic subscription node.
   - Synthesise resource-group nodes from the unique `(sub, rg)` pairs
     in the rows (RGs aren't in `Resources` query results).
   - For each resource: add the node, add an ownership edge to its
     structural parent (RG or parent ARM resource for nested types),
     then walk every matching rule and emit annotations. Tag
     cross-subscription annotations and add stubs for dangling targets.
4. Tenant mode: when the queue empties, if any subscriptions are still
   unvisited, enqueue the lex-smallest one (covers disconnected
   components).
5. Add the synthetic tenant root and edges to every visited
   subscription (unless `--no-tenant-root`).
6. Sort `nodes` by id, `edges` by `(from, to)`, `annotations` by
   `(from, to, label)`. Serialise with stable formatting.

## Out of scope (intentionally)

- Live ARG queries — use the bundled `fetch_arg_raw.py` (PEP-723 deps, run with `uv run`).
- Visualisation. This directory only produces the JSON. Render it with
  `graph-vis`.
- Inferred / heuristic relationships ("these resources share a tag,
  therefore related"). Only explicit ARM-property references.
- Editing the graph. Read-only generator.

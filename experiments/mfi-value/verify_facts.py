"""
Factual Verification of MFI vs Baseline Insights

Stage 1: Build a deterministic fact sheet from raw ARG data (no LLM)
Stage 2: LLM-assisted claim verification against the fact sheet
"""
from __future__ import annotations

import json
import os
import re
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import OpenAI

# -------- Configuration --------
ARG_CACHE_PATH = Path("../../plugin/skills/azure-enterprise-infra-planner/scripts/arg_raw_output_all.json")
RESULTS_DIR = Path("results")
PROMPTS_TO_VERIFY = [1, 2, 7, 9]

AOAI_BASE_URL = os.environ.get("AZURE_OPENAI_BASE_URL", "https://workloads-assistant-aoai.openai.azure.com/openai/v1")
AOAI_DEPLOYMENT = os.environ.get("AZURE_OPENAI_DEPLOYMENT", "gpt-5-mini")
AOAI_API_VERSION = os.environ.get("AZURE_OPENAI_API_VERSION", "preview")

MAX_PROPERTY_DEPTH = 5

# -------- Azure OpenAI Client --------
_credential = DefaultAzureCredential()
_token_provider = get_bearer_token_provider(_credential, "https://cognitiveservices.azure.com/.default")
aoai = OpenAI(
    base_url=AOAI_BASE_URL,
    api_key="placeholder",
    default_query={"api-version": AOAI_API_VERSION},
    default_headers={"Authorization": f"Bearer {_token_provider()}"},
)
print(f"Azure OpenAI client ready (deployment={AOAI_DEPLOYMENT}).")

# -------- Load ARG Data --------
cache = Path(ARG_CACHE_PATH)
raw = json.loads(cache.read_text(encoding="utf-8"))
resources = raw if isinstance(raw, list) else raw.get("data", [])
print(f"Loaded {len(resources):,} resources.")

# ======== STAGE 1: Build Deterministic Fact Sheet ========

# --- Noise filter (same as notebooks) ---
AUTO_CREATED_TYPES = frozenset({
    "microsoft.alertsmanagement/smartdetectoralertrules",
    "microsoft.insights/actiongroups",
    "microsoft.alertsmanagement/prometheusrulegroups",
    "microsoft.security/automations",
    "microsoft.security/pricings",
    "microsoft.operationsmanagement/solutions",
    "microsoft.security/iotsecuritysolutions",
    "microsoft.network/networkwatchers",
    "microsoft.advisor/recommendations",
})
INTERNAL_MS_RP_PREFIXES = (
    "microsoft.portalservices/", "microsoft.cloudtest/", "microsoft.hydra/",
    "microsoft.swiftlet/", "microsoft.compute/swiftlets", "microsoft.fairfieldgardens/",
    "microsoft.footprintmonitoring/", "microsoft.saashub/", "microsoft.visualstudio/",
)
AUTO_MANAGED_SUBRESOURCE_TYPES = frozenset({
    "microsoft.containerregistry/registries/replications",
    "microsoft.containerregistry/registries/webhooks",
    "microsoft.compute/capacityreservationgroups/capacityreservations",
    "microsoft.compute/hostgroups/hosts",
    "microsoft.compute/galleries/images/versions",
    "microsoft.network/networkmanagers/ipampools",
    "microsoft.network/networkmanagers/verifierworkspaces",
})
MARKETPLACE_TYPES = frozenset({
    "microsoft.solutions/applications", "microsoft.solutions/appliances",
    "microsoft.saas/resources", "microsoft.saashub/cloudservices",
})

def _is_noise(rtype: str) -> bool:
    if not rtype:
        return False
    if rtype in AUTO_CREATED_TYPES or rtype in AUTO_MANAGED_SUBRESOURCE_TYPES or rtype in MARKETPLACE_TYPES:
        return True
    return any(rtype.startswith(p) for p in INTERNAL_MS_RP_PREFIXES)

# --- Property aggregation (same whitelist as notebooks) ---
PROPERTY_LEAF_WHITELIST = frozenset({
    "location", "kind", "sku", "name", "tier", "family", "capacity", "size",
    "publicnetworkaccess", "restrictoutboundnetworkaccess",
    "publicnetworkaccessforingestion", "publicnetworkaccessforquery",
    "defaultaction", "bypass", "disablelocalauth", "enablerbacauthorization",
    "minimumtlsversion", "minimaltlsversion", "identity",
    "keysource", "enabledoubleencryption", "enablediskencryption",
    "infrastructureencryption", "requireinfrastructureencryption",
    "zoneredundant", "zoneredundancy", "redundancymode", "replication",
    "platformfaultdomaincount",
    "backupretentionintervalinhours", "backupintervalinminutes", "backupstorageredundancy",
    "softdeleteretentionindays", "enablesoftdelete", "enablepurgeprotection",
    "ostype", "hypervgeneration", "licensetype",
    "accesstier", "largefilesharesstate", "allowsharedkeyaccess",
    "enablehttpstrafficonly", "supportshttpstrafficonly",
})

_KEY_DENY_RE = re.compile(
    r"(secret|password|credential|token|sas|certificate|thumbprint|fingerprint"
    r"|connection|connstr|admin(istrator)?(user|login|name)|private(ip|key|address)"
    r"|publicip|ipaddress|fqdn|hostname|host_name|endpoint|url|uri|email|mail"
    r"|principalid|tenantid|subscriptionid|objectid|clientid|appid"
    r"|customsubdomain|customdomain|key$|^key|accountkey|accesskey"
    r"|primarykey|secondarykey|sharedkey)", re.IGNORECASE)

_VALUE_DENY_PATTERNS = [
    re.compile(r"^\d{1,3}(\.\d{1,3}){3}$"),
    re.compile(r"(?i)^[0-9a-f:]{6,}$"),
    re.compile(r"(?i)^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$"),
    re.compile(r"(?i)^https?://"),
    re.compile(r"^[^@]+@[^@]+\.[^@]+$"),
    re.compile(r"^eyJ[A-Za-z0-9_-]+\."),
    re.compile(r"^[A-Za-z0-9+/]{40,}={0,2}$"),
]

def _is_pii_key(key: str) -> bool:
    return bool(_KEY_DENY_RE.search(key))

def _is_pii_value(val: str) -> bool:
    return any(p.search(val) for p in _VALUE_DENY_PATTERNS)

def walk_properties(node: Any, path: tuple[str, ...] = (), depth: int = 0):
    if depth > MAX_PROPERTY_DEPTH:
        return
    if isinstance(node, dict):
        for k, v in node.items():
            k_lower = str(k).lower()
            if _is_pii_key(k_lower):
                continue
            yield from walk_properties(v, path + (k_lower,), depth + 1)
    elif isinstance(node, list):
        for item in node:
            yield from walk_properties(item, path, depth + 1)
    else:
        val_str = str(node).strip()
        if val_str and not _is_pii_value(val_str):
            yield (path, val_str)


def build_fact_sheet(rows: list[dict]) -> dict:
    """Build comprehensive fact sheet from raw ARG data."""

    # Tenant-level counts
    sub_count = len({r.get("subscriptionId") for r in rows if r.get("subscriptionId")})
    rg_count = len({
        (r.get("subscriptionId"), (r.get("resourceGroup") or "").lower())
        for r in rows if r.get("subscriptionId") and r.get("resourceGroup")
    })

    # Per-type aggregation
    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        rtype = (row.get("type") or "").lower()
        if rtype and not _is_noise(rtype):
            grouped[rtype].append(row)

    type_facts: dict[str, dict] = {}
    for rtype, type_rows in sorted(grouped.items()):
        total = len(type_rows)
        props: dict[str, Counter] = defaultdict(Counter)

        for row in type_rows:
            # Location
            loc = row.get("location")
            if loc and isinstance(loc, str):
                props["location"][loc.lower()] += 1

            # Kind
            kind = row.get("kind")
            if kind and isinstance(kind, str):
                props["kind"][kind] += 1

            # SKU fields
            sku = row.get("sku")
            if isinstance(sku, dict):
                for path, val in walk_properties(sku, ("sku",)):
                    leaf = path[-1]
                    if leaf in PROPERTY_LEAF_WHITELIST:
                        props[".".join(path)][val] += 1

            # Identity
            identity = row.get("identity")
            if isinstance(identity, dict):
                id_type = identity.get("type")
                if id_type and isinstance(id_type, str):
                    props["identity"][id_type] += 1

            # Properties
            raw_props = row.get("properties")
            if isinstance(raw_props, dict):
                for path, val in walk_properties(raw_props, ("properties",)):
                    leaf = path[-1]
                    if leaf in PROPERTY_LEAF_WHITELIST:
                        props[".".join(path)][val] += 1

        # Convert counters to distributions
        prop_distributions = {}
        for prop_path, counter in sorted(props.items()):
            total_vals = sum(counter.values())
            distribution = {
                val: {"count": count, "percentage": round(count / total * 100, 1)}
                for val, count in counter.most_common(10)
            }
            prop_distributions[prop_path] = {
                "totalResponded": total_vals,
                "distribution": distribution,
            }

        type_facts[rtype] = {
            "totalCount": total,
            "properties": prop_distributions,
        }

    return {
        "tenantSummary": {
            "totalResources": len(rows),
            "subscriptionCount": sub_count,
            "resourceGroupCount": rg_count,
            "distinctResourceTypes": len(type_facts),
        },
        "resourceTypes": type_facts,
    }


print("Building fact sheet...")
fact_sheet = build_fact_sheet(resources)
print(f"Fact sheet: {fact_sheet['tenantSummary']['distinctResourceTypes']} resource types")

# Save fact sheet for reference
fact_sheet_path = RESULTS_DIR / "fact_sheet.json"
fact_sheet_path.write_text(json.dumps(fact_sheet, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"Saved fact sheet to {fact_sheet_path}")

# ======== STAGE 2: LLM-Assisted Claim Verification ========

VERIFY_PROMPT = """You are a factual accuracy auditor. You will receive:
1. A **fact sheet** — a deterministic summary of an Azure tenant's resources computed from raw data. This is ground truth.
2. An **insight** — a single sentence making claims about the tenant's infrastructure.

Your job is to extract every verifiable factual claim from the insight and check each one against the fact sheet.

A "verifiable claim" is any specific number, percentage, count, SKU name, property value, or distribution mentioned in the insight. Skip qualitative judgments ("strong", "widely used") and planning recommendations ("you should...").

For each claim, determine:
- **supported**: the fact sheet confirms it (within ~5 percentage points or ~10% of the count)
- **approximate**: directionally correct but numbers are off by more than 5pp / 10% (but less than 20pp / 50%)
- **hallucinated**: contradicted by the data, or the property/value doesn't exist in the fact sheet
- **unverifiable**: the claim references something not captured in the fact sheet (e.g., naming patterns, qualitative statements)

Respond with JSON:
{
  "claims": [
    {
      "claim": "the specific factual claim extracted",
      "verdict": "supported" | "approximate" | "hallucinated" | "unverifiable",
      "fact_sheet_value": "what the fact sheet actually says (or 'not found')",
      "explanation": "brief explanation of the match/mismatch"
    }
  ]
}"""


def verify_insight(insight: str, fact_sheet_json: str) -> dict:
    """Verify a single insight against the fact sheet."""
    user_msg = f"## Fact Sheet\n\n{fact_sheet_json}\n\n## Insight to Verify\n\n{insight}"
    response = aoai.chat.completions.create(
        model=AOAI_DEPLOYMENT,
        messages=[
            {"role": "system", "content": VERIFY_PROMPT},
            {"role": "user", "content": user_msg},
        ],
        response_format={"type": "json_object"},
    )
    return json.loads(response.choices[0].message.content or "{}")


def verify_insight_set(insights: list[str], fact_sheet_json: str, label: str) -> list[dict]:
    """Verify all insights in a set."""
    results = []
    for i, insight in enumerate(insights):
        print(f"    Verifying {label} insight {i+1}/{len(insights)}...")
        verification = verify_insight(insight, fact_sheet_json)
        results.append({
            "insight_index": i + 1,
            "insight_text": insight[:120] + "...",
            "verification": verification,
        })
        time.sleep(1)
    return results


def score_results(verifications: list[dict]) -> dict:
    """Aggregate claim verdicts."""
    totals = {"supported": 0, "approximate": 0, "hallucinated": 0, "unverifiable": 0}
    total_claims = 0
    hallucinated_claims = []

    for v in verifications:
        claims = v.get("verification", {}).get("claims", [])
        for c in claims:
            verdict = c.get("verdict", "unverifiable")
            if verdict in totals:
                totals[verdict] += 1
            else:
                totals["unverifiable"] += 1
            total_claims += 1
            if verdict == "hallucinated":
                hallucinated_claims.append({
                    "insight": v["insight_text"],
                    "claim": c.get("claim", ""),
                    "fact_sheet_value": c.get("fact_sheet_value", ""),
                    "explanation": c.get("explanation", ""),
                })

    verifiable = totals["supported"] + totals["approximate"] + totals["hallucinated"]
    accuracy = round((totals["supported"] + totals["approximate"]) / verifiable * 100, 1) if verifiable > 0 else 0

    return {
        "total_claims": total_claims,
        "verdicts": totals,
        "verifiable_claims": verifiable,
        "accuracy_pct": accuracy,
        "hallucinated_claims": hallucinated_claims,
    }


# Prepare a trimmed fact sheet for the LLM (focus on types relevant to the prompts)
# Full fact sheet is too large for context — send relevant types per prompt
def get_relevant_fact_sheet(prompt_idx: int) -> str:
    """Return the full fact sheet as JSON string. The LLM can handle it with gpt-5-mini."""
    return json.dumps(fact_sheet, ensure_ascii=False)


# ======== Run Verification ========
print("\n" + "=" * 60)
print("FACTUAL VERIFICATION")
print("=" * 60)

all_verification_results = {}

for prompt_idx in PROMPTS_TO_VERIFY:
    baseline_path = RESULTS_DIR / f"prompt_{prompt_idx}_baseline.json"
    mfi_path = RESULTS_DIR / f"prompt_{prompt_idx}_mfi.json"

    if not baseline_path.exists() or not mfi_path.exists():
        print(f"\nSkipping prompt {prompt_idx} — results not found")
        continue

    baseline_insights = json.loads(baseline_path.read_text(encoding="utf-8"))
    mfi_insights = json.loads(mfi_path.read_text(encoding="utf-8"))
    fs_json = get_relevant_fact_sheet(prompt_idx)

    print(f"\n{'=' * 60}")
    print(f"Prompt {prompt_idx}")
    print(f"{'=' * 60}")

    print(f"  Verifying baseline ({len(baseline_insights)} insights)...")
    baseline_verifications = verify_insight_set(baseline_insights, fs_json, "baseline")
    baseline_scores = score_results(baseline_verifications)

    print(f"  Verifying MFI ({len(mfi_insights)} insights)...")
    mfi_verifications = verify_insight_set(mfi_insights, fs_json, "mfi")
    mfi_scores = score_results(mfi_verifications)

    print(f"\n  Baseline: {baseline_scores['accuracy_pct']}% accuracy ({baseline_scores['verdicts']['supported']}S / {baseline_scores['verdicts']['approximate']}A / {baseline_scores['verdicts']['hallucinated']}H)")
    print(f"  MFI:      {mfi_scores['accuracy_pct']}% accuracy ({mfi_scores['verdicts']['supported']}S / {mfi_scores['verdicts']['approximate']}A / {mfi_scores['verdicts']['hallucinated']}H)")

    if baseline_scores['hallucinated_claims']:
        print(f"  Baseline hallucinations:")
        for h in baseline_scores['hallucinated_claims']:
            print(f"    - {h['claim'][:80]}...")

    if mfi_scores['hallucinated_claims']:
        print(f"  MFI hallucinations:")
        for h in mfi_scores['hallucinated_claims']:
            print(f"    - {h['claim'][:80]}...")

    all_verification_results[prompt_idx] = {
        "baseline": {"scores": baseline_scores, "verifications": baseline_verifications},
        "mfi": {"scores": mfi_scores, "verifications": mfi_verifications},
    }

# Save all results
verification_path = RESULTS_DIR / "factual_verification.json"
verification_path.write_text(
    json.dumps(all_verification_results, indent=2, ensure_ascii=False), encoding="utf-8"
)

# Print summary
print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
print(f"{'Prompt':<10} {'Baseline Acc':<15} {'MFI Acc':<15} {'Baseline H':<12} {'MFI H':<12}")
print("-" * 64)
for idx in PROMPTS_TO_VERIFY:
    if idx not in all_verification_results:
        continue
    b = all_verification_results[idx]["baseline"]["scores"]
    m = all_verification_results[idx]["mfi"]["scores"]
    print(f"{idx:<10} {b['accuracy_pct']:>6.1f}%        {m['accuracy_pct']:>6.1f}%        {b['verdicts']['hallucinated']:>4}         {m['verdicts']['hallucinated']:>4}")

print(f"\nSaved detailed results to {verification_path}")

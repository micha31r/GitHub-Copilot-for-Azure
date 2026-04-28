# Phase 2: Research Best Practices

> The goal of this phase is to gather Azure best practices and WAF guidance using MCP tools.

## Step 1 - Identify Core Resources and Sub-Goals

From the user's description, list the core Azure services (compute, data, networking, messaging). Also derive sub-goals — implicit constraints to include in `inputs.subGoals`:
- "assume all defaults" → `"Cost-optimized: consumption/serverless tiers, minimal complexity"`
- "production system" → `"Production-grade: zone redundancy, private networking, managed identity"`

Read `<project-root>/.azure/insights.json` (from Phase 1) and derive sub-goals from each planning implication (e.g., `"Tenant convention: prefer westus2 region per insights"`).

### Input Analysis

You may use the following additional methods to better understand user goals:

| Scenario | Action |
|----------|--------|
| Repository | Scan `package.json`, `requirements.txt`, `Dockerfile`, `*.csproj` for runtime/dependencies. |
| User requirements | Clarify workload purpose, traffic, data storage, security, budget. |
| Multi-environment | Ask about dev/staging/prod sizing differences. |

## Step 2 - WAF Tool Calls

> Mandatory: Call WAF MCP tools before reading local resource files. Complete this step before proceeding.

1. Call `get_azure_bestpractices` with `resource: "general"`, `action: "all"` for baseline guidance. Call once only.
2. Call `wellarchitectedframework_serviceguide_get` with `service: "<name>"` for each core service (in parallel). Examples: `"Container Apps"`, `"Cosmos DB"`, `"App Service"`, `"Event Grid"`, `"Key Vault"`. Return URLs only.
3. The tool returns a markdown URL. Use a sub-agent to fetch and summarize in ≤500 tokens, focusing on: additional resources needed, required properties for security/reliability, key design decisions.
4. Collect all WAF findings: missing resources, property hardening, architecture patterns.

## Step 3 - Summarise WAF Guides

Use sub-agents to fetch and summarize each WAF guide URL from step 2. 

> Note: the responses from WAF guides are large - 20-60KB each.

## Gate
- All tool calls must be completed and WAF guides summarized.

# Research Phase

Gather all information needed to make correct infrastructure decisions before generating the plan.

## Input Analysis

Determine the input scenario and gather requirements accordingly:

| Scenario | Action |
|----------|--------|
| **Repository analysis** | Scan project files: `package.json`, `requirements.txt`, `Dockerfile`, `*.csproj`, config files. Identify runtime, dependencies, and infrastructure needs. |
| **User requirements** | Ask user to describe their workload: purpose, expected traffic, data storage needs, security requirements, budget constraints. |
| **Multi-environment** | Ask which environments (dev/staging/prod) and how sizing differs between them. |

## MCP Tool Usage

### Architecture Research

Use `microsoft_docs_search` to find architecture guidance:
- Search for architecture patterns matching the workload type (e.g., "Azure web app architecture best practices")
- Search for Well-Architected Framework guidance for the relevant pillars
- Extract recommended resource types and design patterns from results

### SKU and Region Availability

Use `microsoft_docs_search` and `microsoft_docs_fetch` to verify:
- Which regions support the selected resource types
- Available SKUs and their capabilities
- Service limits and quotas for target SKUs

### Resource Documentation

For each planned resource type, use `microsoft_docs_fetch` on the relevant Learn doc pages to:
- Confirm correct ARM resource type and API version
- Verify required and optional properties
- Check configuration constraints and incompatibilities
- Populate the `references` array in the plan JSON with doc URLs

### Search → Fetch Pattern

1. **Search first** — Use `microsoft_docs_search` with a specific query to find relevant pages
2. **Fetch high-value pages** — Use `microsoft_docs_fetch` on URLs from search results that need full detail
3. **Record URLs** — Save fetched URLs in the resource's `references` array for verification traceability

### Existing Resource Discovery

When new resources need to connect to already-deployed infrastructure:

1. **Identify subscription** — Use `mcp_azure_mcp_ser_subscription_list` to list subscriptions and confirm the target
2. **List resource groups** — Use `mcp_azure_mcp_ser_group_list` to find existing groups in the subscription
3. **Query deployed resources** — Use `azure_resources-query_azure_resource_graph` with a natural language intent (e.g., "list all resources in resource group X with their type, SKU, and location")
4. **Extract connection points** — From the query results, identify resource names, SKUs, networking config, and other properties that new resources must align with
5. **Add as dependencies** — Reference existing resources in the plan's `dependencies` arrays so the generated IaC can wire up correctly

## Research Checklist

For each resource in the plan, verify:

1. **Type** — Correct `Microsoft.*` resource type
2. **SKU** — Available in target region, appropriate for workload size
3. **Region** — Service available, data residency requirements met
4. **Name** — Complies with naming constraints
5. **Dependencies** — All prerequisite resources identified and ordered
6. **Properties** — Required properties populated per resource schema
7. **Alternatives** — At least one alternative considered with tradeoff documented

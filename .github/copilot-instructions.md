# Project Context

This repo (`GitHub-Copilot-for-Azure`) is the plugin that powers the GitHub Copilot for Azure extension. It contains agent skills that handle Azure-related tasks inside Copilot conversations.

## Infra Planner

The `azure-enterprise-infra-planner` skill takes a workload description and turns it into real Azure infrastructure. Given something like "I need a hub-spoke network with AKS and a private Cosmos DB", the skill researches best practices, proposes a full resource set with reasoning, generates a structured JSON plan, verifies it, and produces Bicep or Terraform ready to deploy. Infrastructure planning involves a lot of cross-cutting decisions — naming conventions, pairing constraints, WAF alignment — that are easy to miss and tedious to look up every time, so the agent handles that research systematically rather than relying on whatever it happened to learn during training.

This skill targets the infrastructure layer: networks, gateways, identity, resource groups, subscription-scoped deployments. It is not for application deployment — that's what azure-prepare and azd are for.

The skill uses a small SKILL.md that keeps the initial context lean, a tree of reference files that get loaded progressively as the agent moves through each phase, and heavy use of sub-agents to keep large external fetches from bloating the main context.

Key files: `plugin/skills/azure-enterprise-infra-planner/SKILL.md`, `references/workflow.md`.

## Insights

Currently the infra planner generates plans based on the user prompt alone. The prompt contains a workload description but does not include contextual data such as whether naming conventions exist, whether specific SKU types are preferred, or the required security posture. As a result, the skill must make assumptions and rely on default configurations that align with Azure best practices and WAF principles. The generated plans are logically correct but may require manual editing to match how users already build and operate within Azure.

Insights are patterns derived from a user's existing Azure footprint that bridge this gap. They are extracted from Azure Resource Graph data and used to guide planning decisions so that generated infrastructure aligns with the customer's actual conventions — their preferred regions, SKU tiers, security posture, networking topology, and so on.

Good insights contain both an observed pattern (data) and an associated planning implication (action). This makes it easier to control how insights influence the planning process and improves transparency by allowing users to understand how those patterns inform decisions.

Insight pipeline experiments live under `experiments/insights-data-processing/`. See that directory's README.md and FINDINGS.md for approaches tested and results.

Key files: `scripts/fetch_arg.py`.
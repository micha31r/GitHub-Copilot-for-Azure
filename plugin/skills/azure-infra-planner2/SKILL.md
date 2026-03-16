---
name: azure-infra-planner2
description: "Architect and provision enterprise Azure infrastructure from workload descriptions. For platform engineers needing networking, security, compliance, and WAF alignment. Generates Bicep or Terraform directly (no azd). WHEN: 'plan Azure infrastructure', 'set up networking and VMs', 'architect Azure landing zone', 'design hub-spoke network', 'provision enterprise workload', 'plan DR infrastructure', 'set up VMs with load balancer and bastion', 'plan infrastructure for compliance'. PREFER azure-prepare FOR app-centric workflows."
license: MIT
metadata:
  author: Microsoft
  version: "1.3.0"
---

# Azure Infra Planner

## Triggers

Activate this skill when user wants to:
- Plan and provision enterprise Azure infrastructure from a workload description (not source code)
- Architect a landing zone, hub-spoke network, or multi-region topology
- Set up IaaS resources: VMs, NSGs, bastion hosts, load balancers, VPN gateways
- Design networking infrastructure: VNets, subnets, firewalls, private endpoints
- Plan disaster recovery, backup, or compliance-driven infrastructure (PCI-DSS, HIPAA)
- Provision enterprise middleware: Service Bus, Event Hub, Key Vault with private networking
- Generate Bicep or Terraform for subscription-scope or multi-resource-group deployments
- Set up multi-environment infrastructure (dev/staging/prod) at the platform level

## Mandatory Rules

1. You must follow every phase in the prescribed order. Do not skip steps or phases.
2. Always get user approval before generating any IaC or executing deployments.

## Phase 1: Research

The goal of the research phase is to gather requirements, identify core and supporting resources, and identify configurations. This phase is critical for ensuring the plan is comprehensive, secure, and aligned with best practices before any code is generated. 

This skill is used by Cloud Architects and Platform Engineers to quickly generate enterprise-grade Azure infrastructure for a wide variety of workloads. ALWAYS consider completeness, correctness, compliance, and security for every step below.

### Step 1: Requirement Analysis

Identify the user's intent and extract key requirements from their description. Look for explicit mentions of workload type, performance needs, security requirements, compliance constraints, and any specific Azure services they mention. Also identify implicit requirements such as "production-grade" or "cost-optimized" that will influence resource selection and configuration.

If the user query is overly simplified, you may ask for high-level clarifications. However, the skill should be able to handle incomplete or vague descriptions by making reasonable assumptions based on common patterns and best practices. Always document any assumptions in the plan's `assumption` section (see [schema.md](references/schema.md)).

### Step 2: Research Azure Well-Architected Framework (WAF)

Use the `get_azure_bestpractices` and `wellarchitectedframework_serviceguide_get` MCP tools to research best practices for every service identified in Step 1. You must delegate each resource to a sub-agent to fetch and summarize the WAF guidance for that service. Focus on the five pillars of WAF:

- **Reliability** — Redundancy, availability zones, failover
- **Security** — Network isolation, managed identity, Key Vault usage, encryption
- **Cost Optimization** — Appropriate SKU tiers, no over-provisioning
- **Operational Excellence** — Monitoring, diagnostics, tagging
- **Performance Efficiency** — Correct SKU sizing for workload

### Step 3: Research Azure Resources

Use the `mcp_bicep_get_az_resource_type_schema`, `azure-documentation`, `microsoft_docs_search`, and `microsoft_docs_fetch` tools to research each identified resource type. Verify details such as available SKUs, regional availability, naming rules, and pairing constraints. 

You may invoke subagents to research each resource in parallel. However, you must also research cross-cutting effects that resources have on each other (e.g., a VM with a public IP requires NSG rules, a Cosmos DB account with private endpoints requires a VNet and subnet). Keep track your findings in memory and use them in step 4.

### Step 4: Generate Infrastructure Plan

Generate a JSON infrastructure plan at `<project-root>/.azure/infrastructure-plan.json` that includes all identified resources, their properties, and the reasoning behind their inclusion. This plan should be comprehensive and include all core and supporting resources needed to meet the user's requirements while adhering to best practices. The plan should also document any assumptions, trade-offs, and WAF considerations that influenced resource selection and configuration.

You must generate the plan resource by resource. Do NOT use sub-agents for this task. Ensure that all required properties are included and align with the requirements and constraints you have identified above.

### Step 5: Verify Plan

> Do NOT begin verification until you've read all instructions in this section.

Verify the first version of the JSON plan for correctness, completeness, and alignment with the requirements and best practices. Evaluate using the following criteria and suggest comprehensive fixes for any issues found. Document your findings and actions taken in `<project-root>/.azure/plan-eval.json`.

#### Goal Alignment

Does the plan fully meet the user's requirements and intent? Check each requirement against the resources and configurations in the plan. If any requirement is not met, identify the gap and suggest specific resources or property changes to address it.

#### Adherence to WAF Principles

Does every aspect of the plan follow WAF best practices for reliability, security, cost optimization, operational excellence, and performance efficiency? Identify any deviations from best practices and suggest specific changes to align with WAF principles. Trade-offs or missing references are not penalised if they are justified and documented in the plan.

#### Dependency Completeness

Are all dependencies between resources fully defined and correct? This includes both explicit dependencies (e.g., a VM depends on a VNet) and implicit ones derived from best practices (e.g., a Cosmos DB account with private endpoints should have a VNet and subnet). Identify any missing or incorrect dependencies and suggest specific fixes. Circular dependencies should be identified and resolved by breaking the weaker edge.

#### Deployability

Will the plan deploy successfully with the defined resources and properties? Check for any conflicts, missing required properties, or incompatible configurations that would cause deployment failure. Identify any issues and suggest specific fixes to ensure the plan is deployable. Missing optional properties or resources are not penalised if the plan is still deployable and meets the requirements.

#### Other Mandetory Checks

You must also run the following checks and include them in your evaluation:

##### Naming Check:

| # | Check | Fix |
|---|-------|-----|
| 1 | Follows CAF pattern from resource file Identity/Naming section | Rewrite using correct abbreviation |
| 2 | Length within min/max for type | Truncate or restructure |
| 3 | Only allowed characters for type | Strip disallowed characters |
| 4 | Globally-unique names avoid collisions | Add distinguishing suffix |
| 5 | Required subnet names exact (`AzureFirewallSubnet`, `GatewaySubnet`, `AzureBastionSubnet`) | Use exact required string |
| 6 | Function Apps sharing Storage diverge within first 32 chars | Rename or separate storage |
| 7 | AKS `MC_{rg}_{cluster}_{region}` ≤ 80 chars | Shorten names |

##### Property and Pairing Checks

Validate connections between resources by referencing tools: `azure-documentation`, `microsoft_docs_search`, `microsoft_docs_fetch` and [pairing-checks.md](pairing-checks.md) for full rules covering areas such as: SKU compatibility, subnet/network conflicts, storage pairing, Cosmos DB, Key Vault/CMK, SQL Database, and AKS networking.

#### Mandatory Strategy

The entire evaluation must be completed by a sub-agent to isolate the context and prevent bias. All research tool calls, analysis, and solution generation must be done by the sub-agent alone. Do not return to the main agent until the evaluation is fully complete and the output is generated in the specified schema. Do not generate any fixes or suggestions in the main agent. 

The sub-agent must be provided with the user query verbatim and the generated plan. Only the instructions for Step 5 can be provided to the sub-agent as a system prompt. 

Since the sub-agent doesn't have access to the existing research, it will need to make it's own assumptions. You must tell the sub-agent to document all assumptions in the `assumptions` section of the output schema.

#### Evaluation Output Schema

```json
{
  "assumptions": [],
  "goalAlignment": {
    "issues": [
      {
        "issue": "",
        "fix": "",
        "justification": ""
      }
    ],
  },
  ...
}
```

> STOP HERE - Do not proceed to Step 6 until the sub-agent has completed the evaluation.  

### Step 6: Refine Plan

Read `<project-root>/.azure/plan-eval.json` and apply the suggested fixes to the plan.

Since the evaluation is done in a separate context, the sub-agent may have made assumptions that differ from your original intent or understanding. Review each assumption carefully and determine if it is valid or if it needs to be adjusted based on your knowledge of the user's requirements and the context of the plan. Fresh (and valid) assumptions are to be seriously considered when refining the plan. Invalid assumptions are discarded.

Then, for each issue identified in the evaluation, review the suggested fix and justification. If the fix is valid and improves the plan's alignment with the user's requirements, best practices, and deployability, apply it to the plan. If the fix is not valid or does not improve the plan, you should discard it but must document your reasoning in the `tradeoffs` section of the plan.

Other significant improvements that are not identified in the evaluation but that you recognize as necessary based on fresh insights should also be applied to the plan. Document any such changes and their justifications in the `tradeoffs` section as well.

After applying fixes, the plan should be fully aligned with the user's requirements, adhere to WAF principles, have complete dependencies, and be deployable.
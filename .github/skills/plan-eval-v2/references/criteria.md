# Evaluation Criteria

For each dimension below, you are given a description and list of criteria. The description explains what the dimension is about and must not be evaluated. Your task is to answer each question listed under the `Criteria` sections by giving a specific rating from [rating.md](rating.md). Each decision must be grounded in facts. In highly uncertain situations, think from the shoes of a senior cloud architect and use your best judgement.

Evaluate all four dimensions yourself in a single pass. Do NOT spawn subagents.

Scoring Notes:

- Plans are generated from a single user input and may contain assumptions. This is acceptable.
- Assumptions may explain why some resources are missing. Consider this during evaluation.
- All placeholder values, endpoints, and VNet references should be treated as correctly configured. Do not flag placeholders.
- Focus on structural correctness and compatibility, not cosmetic issues.
- Evaluate only the `plan.resources[]` array and their properties. Do NOT rely on `plan.overallReasoning`, `plan.validation`, or `plan.architecturePrinciples` for factual claims — these are narrative text and may be inconsistent with the actual resources.

Evidence Requirement:

- For every rating, the subagent MUST quote specific property values from the plan JSON to justify the rating (e.g., quote `"sku": "Basic"` or `"addressPrefix": "10.0.1.0/24"`). Ratings without evidence from the actual resource properties are invalid.

## 1. Goal Alignment

### Description

How well does the plan address the stated `inputs.userGoal`?

### Criteria

- How completely does `plan.resources[]` cover the services required by the goal?
- How well does `plan.overallReasoning` explain how the architecture satisfies the goal?
- How relevant are all planned resources to the stated goal?

## 2. Well-Architected Framework Conformance

### Description

Does the plan follow Azure Well-Architected Framework principles?

The five pillars of WAF are:

- Reliability - Redundancy, availability zones, failover
- Security - Network isolation, managed identity, Key Vault usage, encryption
- Cost Optimization - Appropriate SKU tiers, no over-provisioning
- Operational Excellence - Monitoring, diagnostics, tagging
- Performance Efficiency - Correct SKU sizing for workload

### Criteria

- How well does the plan address redundancy, availability zones, and failover?
- How well does the plan enforce network isolation, managed identity, Key Vault usage, and encryption?
- How appropriately are SKU tiers selected to avoid over-provisioning?
- How well does the plan incorporate monitoring, diagnostics, and tagging?
- How correctly are resource SKUs sized for the workload?

### WAF Rating Anchors (use these to calibrate your WAF rating):

- **terrible**: No security controls at all — no NSGs, no identity management, no encryption, no monitoring
- **very poor**: NSGs exist but allow all traffic (`*`); no managed identity; no encryption; no Key Vault
- **weak**: Basic NSGs with some deny rules; no managed identity; no Key Vault; no monitoring resources
- **acceptable**: NSGs properly configured; Key Vault exists but public access; no managed identity; basic monitoring
- **good**: Network isolation via NSGs; managed identity on compute; Key Vault with access policies; basic monitoring and tagging
- **very good**: Private endpoints on data services; Key Vault with RBAC; comprehensive monitoring and diagnostics; consistent tagging; disk encryption
- **excellent**: Zero-trust network design; private endpoints everywhere; managed identity for all services; full WAF pillar coverage across all five pillars

## 3. Dependency Completeness

### Description

Are resource dependencies internally consistent?

### Criteria

- How accurately do `dependencies[]` entries reference existing resources in the plan?
- How free is the dependency graph from circular references?
- How thoroughly are implicit dependencies made explicit (e.g., App Service → App Service Plan)?
- How correctly are subnet delegations and VNet references configured?
- How completely are required parent resources included (e.g., SQL DB → SQL Server)?

## 4. Deployment Viability

### Description

Will the included properties cause deployment failures?

### Criteria

- How compatible are the SKU tiers between paired resources (e.g., Public IP + Load Balancer must both be Standard or both Basic)?
- How free is the plan from subnet allocation conflicts (e.g., exclusive subnets for Application Gateway, AKS)?
- How correctly are storage kinds matched to service requirements (e.g., Functions require `StorageV2`)?
- How free is the network design from CIDR range overlaps?
- How appropriately do selected SKU tiers support the specified zone-redundancy settings?

> Warning - Only evaluate properties that are **present**. Do not penalize for missing properties - only flag conflicts between included values. The `deployable` field should be `true` unless included properties have hard conflicts.

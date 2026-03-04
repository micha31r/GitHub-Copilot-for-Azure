# Evaluation Criteria

Evaluate each dimension independently, then compute `overallScore` as the weighted average.

## Dimensions

### 1. Goal Alignment (weight: 0.30)

How well does the plan address the stated `inputs.userGoal`?

- Are all services required by the goal represented in `plan.resources[]`?
- Does `plan.overallReasoning` explain how the architecture satisfies the goal?
- Are there resources that appear unrelated to the goal?

### 2. Well-Architected Framework Conformance (weight: 0.25)

Does the plan follow Azure Well-Architected Framework principles?

- **Reliability** — Redundancy, availability zones, failover
- **Security** — Network isolation, managed identity, Key Vault usage, encryption
- **Cost Optimization** — Appropriate SKU tiers, no over-provisioning
- **Operational Excellence** — Monitoring, diagnostics, tagging
- **Performance Efficiency** — Correct SKU sizing for workload

> ⚠️ **Warning:** Do not require all five pillars for every plan. Score based on what is relevant to the stated goal and workload.

### 3. Dependency Completeness (weight: 0.25)

Are resource dependencies internally consistent?

- Every `dependencies[]` entry references an existing resource in the plan
- No circular dependencies
- Implicit dependencies are explicit (e.g., App Service → App Service Plan)
- Subnet delegations and VNet references are correct
- Resources that require a parent exist (e.g., SQL DB → SQL Server)

### 4. Deployment Viability (weight: 0.20)

Will the included properties cause deployment failures?

- SKU compatibility between paired resources (e.g., Public IP + Load Balancer must both be Standard or both Basic)
- Subnet conflicts (exclusive subnets for Application Gateway, AKS, etc.)
- Storage kind compatibility (e.g., Functions require `StorageV2`)
- CIDR overlap detection
- Zone redundancy tier requirements

> ⚠️ **Warning:** Only evaluate properties that **are present**. Do not penalize for missing properties — only flag conflicts between included values. The `deployable` field should be 1 unless included properties have hard conflicts.

## Scoring Notes

- Plans are generated from a single user input and may contain assumptions. This is acceptable.
- Assumptions may explain why some resources are missing. Consider this during evaluation.
- All placeholder values, endpoints, and VNet references should be treated as correctly configured. Do not flag placeholders.
- Focus on structural correctness and compatibility, not cosmetic issues.

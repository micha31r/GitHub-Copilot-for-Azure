# App Service Plan

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Web/serverfarms` |
| Bicep API Version | `2025-03-01` |
| CAF Prefix | `asp` |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions.

> Verify at plan time: `microsoft_docs_fetch` → `https://learn.microsoft.com/azure/reliability/availability-service-by-category`

## Subtypes (kind)

The `kind` property is a free-form string:

| Kind | Description |
|------|-------------|
| `linux` | Linux App Service Plan |
| `windows` | Windows App Service Plan (default if omitted) |
| `elastic` | Premium Functions (Elastic Premium) plan |
| `functionapp` | Consumption Functions plan |
| `app` | Windows plan (alternative) |

> **Note:** For Linux plans, also set `properties.reserved: true`.

## SKU Names

Exact `sku.name` values for Bicep. The `sku.tier` is derived but can be set explicitly.

### Free & Shared

| SKU Name | Tier | Description |
|----------|------|-------------|
| `F1` | `Free` | Free tier — 1 GB, 60 min/day compute |
| `D1` | `Shared` | Shared — custom domains, 240 min/day |

### Basic

| SKU Name | Tier | Cores | RAM | Description |
|----------|------|-------|-----|-------------|
| `B1` | `Basic` | 1 | 1.75 GB | Basic small |
| `B2` | `Basic` | 2 | 3.5 GB | Basic medium |
| `B3` | `Basic` | 4 | 7 GB | Basic large |

### Standard

| SKU Name | Tier | Cores | RAM | Description |
|----------|------|-------|-----|-------------|
| `S1` | `Standard` | 1 | 1.75 GB | Standard small — slots, autoscale |
| `S2` | `Standard` | 2 | 3.5 GB | Standard medium |
| `S3` | `Standard` | 4 | 7 GB | Standard large |

### Premium v3

| SKU Name | Tier | Cores | RAM | Description |
|----------|------|-------|-----|-------------|
| `P0v3` | `PremiumV3` | 1 | 4 GB | Premium v3 extra-small |
| `P1v3` | `PremiumV3` | 2 | 8 GB | Premium v3 small |
| `P2v3` | `PremiumV3` | 4 | 16 GB | Premium v3 medium |
| `P3v3` | `PremiumV3` | 8 | 32 GB | Premium v3 large |
| `P1mv3` | `PremiumMV3` | 2 | 16 GB | Memory-optimized v3 |
| `P2mv3` | `PremiumMV3` | 4 | 32 GB | Memory-optimized v3 |
| `P3mv3` | `PremiumMV3` | 8 | 64 GB | Memory-optimized v3 |
| `P4mv3` | `PremiumMV3` | 16 | 128 GB | Memory-optimized v3 |
| `P5mv3` | `PremiumMV3` | 32 | 256 GB | Memory-optimized v3 |

### Isolated v2

| SKU Name | Tier | Cores | RAM | Description |
|----------|------|-------|-----|-------------|
| `I1v2` | `IsolatedV2` | 2 | 8 GB | Isolated v2 small (ASE) |
| `I2v2` | `IsolatedV2` | 4 | 16 GB | Isolated v2 medium |
| `I3v2` | `IsolatedV2` | 8 | 32 GB | Isolated v2 large |
| `I4v2` | `IsolatedV2` | 16 | 64 GB | Isolated v2 extra-large |
| `I5v2` | `IsolatedV2` | 32 | 128 GB | Isolated v2 2x-large |
| `I6v2` | `IsolatedV2` | 64 | 256 GB | Isolated v2 3x-large |

### Functions-Specific

| SKU Name | Tier | Description |
|----------|------|-------------|
| `Y1` | `Dynamic` | Consumption plan — pay-per-execution |
| `FC1` | `FlexConsumption` | Flex Consumption — VNet support |
| `EP1` | `ElasticPremium` | Elastic Premium small — always-warm |
| `EP2` | `ElasticPremium` | Elastic Premium medium |
| `EP3` | `ElasticPremium` | Elastic Premium large |

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 40 |
| Allowed Characters | Alphanumerics and hyphens |
| Scope | Resource group |
| Pattern | `asp-{workload}-{env}-{instance}` |
| Example | `asp-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: 'string'       // required
  location: 'string'   // required
  kind: 'string'       // recommended — 'linux', 'windows', 'elastic', 'functionapp'
  sku: {
    name: 'string'     // required — see SKU Names
    tier: 'string'     // optional — inferred from sku.name
    capacity: int      // optional — number of instances
  }
  properties: {
    reserved: bool     // required for Linux — set to true
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `sku.name` | SKU name | See SKU Names tables |
| `sku.tier` | SKU tier | Derived from SKU name pattern |
| `sku.capacity` | Instance count | Integer |
| `properties.reserved` | Linux plan flag | `true` for Linux, `false` for Windows |
| `properties.perSiteScaling` | Per-app scaling | `true`, `false` |
| `properties.elasticScaleEnabled` | Elastic scale (Premium Functions) | `true`, `false` |
| `properties.zoneRedundant` | Zone redundancy | `true`, `false` (Premium v3+ only, 3+ instances) |
| `properties.maximumElasticWorkerCount` | Max elastic workers | Integer |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **Function App** | Consumption (`Y1`) and Flex (`FC1`) plans cannot be shared with web apps. EP plans can host both functions and web apps. |
| **Linux Apps** | Linux plan (`reserved: true`) cannot host Windows apps and vice versa. |
| **Zone Redundancy** | Requires Premium v3 (`P1v3`+) or Isolated v2. Minimum 3 instances. |
| **Deployment Slots** | Slots share plan capacity. Standard+ tier required. Slots are not available on Free/Basic. |
| **Auto-scale** | Not available on Free/Shared/Basic. Standard+ required for manual scale, auto-scale. |
| **VNet Integration** | Requires Basic or higher. Subnet must be delegated to `Microsoft.Web/serverFarms`. |

## Child Resources

App Service Plan has no significant Bicep child resources — apps and functions reference the plan via `serverFarmId`.

## References

- [Bicep resource reference (2025-03-01)](https://learn.microsoft.com/azure/templates/microsoft.web/serverfarms?pivots=deployment-language-bicep)
- [App Service plan overview](https://learn.microsoft.com/azure/app-service/overview-hosting-plans)
- [Azure naming rules — Web](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftweb)
- [App Service pricing](https://azure.microsoft.com/pricing/details/app-service/)

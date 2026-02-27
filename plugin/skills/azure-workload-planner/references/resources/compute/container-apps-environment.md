# Container Apps Environment

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.App/managedEnvironments` |
| Bicep API Version | `2025-07-01` |
| CAF Prefix | `cae` |

## Region Availability

**Category:** Strategic — demand-driven availability across regions; verify before planning.

> Verify at plan time: `microsoft_docs_fetch` → `https://learn.microsoft.com/azure/reliability/availability-service-by-category`

## Subtypes (kind)

Container Apps Environment does not use `kind` in standard deployments.

## SKU Names

Container Apps Environment does not use a `sku` block. Billing is determined by **workload profiles** configured on the environment.

### Workload Profile Types

| Profile | Description |
|---------|-------------|
| `Consumption` | Serverless — auto-scales, pay-per-use. Default profile. |
| `D4` – `D32` | Dedicated general-purpose (4–32 vCPU) |
| `E4` – `E32` | Dedicated memory-optimized (4–32 vCPU) |

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 60 |
| Allowed Characters | Lowercase letters, numbers, and hyphens. Must start with a letter, end with alphanumeric. |
| Scope | Resource group |
| Pattern | `cae-{workload}-{env}-{instance}` |
| Example | `cae-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource containerAppEnv 'Microsoft.App/managedEnvironments@2025-07-01' = {
  name: 'string'       // required
  location: 'string'   // required
  properties: {
    appLogsConfiguration: {
      destination: 'string'           // recommended — 'log-analytics' or 'azure-monitor'
      logAnalyticsConfiguration: {
        customerId: 'string'          // required when destination is 'log-analytics'
        sharedKey: 'string'           // required when destination is 'log-analytics'
      }
    }
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `properties.appLogsConfiguration.destination` | Log destination | `log-analytics`, `azure-monitor`, `''` (none) |
| `properties.appLogsConfiguration.logAnalyticsConfiguration.customerId` | Log Analytics workspace ID | Workspace customer ID string |
| `properties.vnetConfiguration.infrastructureSubnetId` | VNet subnet | Resource ID — subnet must have minimum /23 prefix |
| `properties.vnetConfiguration.internal` | Internal-only environment | `true`, `false` |
| `properties.zoneRedundant` | Zone redundancy | `true`, `false` |
| `properties.workloadProfiles[].workloadProfileType` | Workload profile type | `Consumption`, `D4`, `D8`, `D16`, `D32`, `E4`, `E8`, `E16`, `E32` |
| `properties.workloadProfiles[].name` | Profile name | String (use `Consumption` for the consumption profile) |
| `properties.workloadProfiles[].minimumCount` | Min instances (dedicated) | Integer |
| `properties.workloadProfiles[].maximumCount` | Max instances (dedicated) | Integer |
| `properties.peerAuthentication.mtls.enabled` | Mutual TLS | `true`, `false` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **Container App** | Container Apps reference the environment via `properties.environmentId`. Apps and environment must be in the same region. |
| **Log Analytics Workspace** | Provide `customerId` and `sharedKey` in `appLogsConfiguration`. Workspace must exist before the environment. |
| **VNet / Subnet** | Subnet must have a minimum /23 prefix. Subnet must be dedicated to the Container Apps Environment (no other resources). Subnet must be delegated to `Microsoft.App/environments`. |
| **Zone Redundancy** | Requires VNet integration. Zone-redundant environments need a /23 subnet in a region with availability zones. |
| **Internal Environment** | When `internal: true`, no public endpoint is created. Requires custom DNS or Private DNS Zone and a VNet with connectivity to clients. |
| **Workload Profiles** | At least one `Consumption` profile must be defined when using workload profiles. Dedicated profiles require `minimumCount` and `maximumCount`. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Certificates | `Microsoft.App/managedEnvironments/certificates` | TLS certificates for custom domains |
| Managed Certificates | `Microsoft.App/managedEnvironments/managedCertificates` | Azure-managed TLS certificates |
| Dapr Components | `Microsoft.App/managedEnvironments/daprComponents` | Dapr integration components |
| Storages | `Microsoft.App/managedEnvironments/storages` | Persistent storage mounts (Azure Files) |

## References

- [Bicep resource reference (2025-07-01)](https://learn.microsoft.com/azure/templates/microsoft.app/managedenvironments?pivots=deployment-language-bicep)
- [Container Apps environments overview](https://learn.microsoft.com/azure/container-apps/environment)
- [Azure naming rules — App](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftapp)
- [Workload profiles overview](https://learn.microsoft.com/azure/container-apps/workload-profiles-overview)

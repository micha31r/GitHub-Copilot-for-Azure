# Container Registry

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.ContainerRegistry/registries` |
| Bicep API Version | `2025-04-01` |
| CAF Prefix | `cr` |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions.

> Verify at plan time: `microsoft_docs_fetch` → `https://learn.microsoft.com/azure/reliability/availability-service-by-category`

## Subtypes (kind)

Container Registry does not use `kind`.

## SKU Names

Exact `sku.name` values for Bicep:

| SKU | Storage | Geo-Replication | Private Link | CMK | Zone Redundancy |
|-----|---------|-----------------|--------------|-----|-----------------|
| `Basic` | 10 GiB | No | No | No | No |
| `Standard` | 100 GiB | No | No | No | No |
| `Premium` | 500 GiB | Yes | Yes | Yes | Yes |

> **Note:** `Classic` SKU is deprecated. Avoid for new deployments.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 5 |
| Max Length | 50 |
| Allowed Characters | Alphanumerics only (`^[a-zA-Z0-9]*$`) — **no hyphens, underscores, or periods** |
| Scope | Global (DNS-based: `{name}.azurecr.io`) |
| Pattern | `cr{workload}{env}{instance}` (no separators) |
| Example | `crdatapipelineprod001` |

## Required Properties (Bicep)

```bicep
resource acr 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  sku: {
    name: 'string'     // required — 'Basic', 'Standard', or 'Premium'
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `properties.adminUserEnabled` | Admin user access | `true`, `false` (default: `false`; prefer managed identity) |
| `properties.publicNetworkAccess` | Public access | `Enabled`, `Disabled` |
| `properties.networkRuleSet.defaultAction` | Network rule | `Allow`, `Deny` (Premium only) |
| `properties.zoneRedundancy` | Zone redundancy | `Enabled`, `Disabled` (Premium only) |
| `properties.encryption.status` | CMK encryption | `enabled`, `disabled` (Premium only) |
| `properties.networkRuleBypassOptions` | Bypass for Azure services | `AzureServices`, `None` |
| `identity.type` | Managed identity | `None`, `SystemAssigned`, `UserAssigned`, `SystemAssigned, UserAssigned` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **AKS** | AKS needs `acrPull` role assignment on the registry. Use managed identity (attach via `az aks update --attach-acr`). |
| **Container App** | Reference in `configuration.registries[]`. Use managed identity or admin credentials. |
| **ML Workspace** | Referenced as `containerRegistry` property. Used for custom training/inference images. |
| **Private Endpoint** | Premium SKU required. Set `publicNetworkAccess: 'Disabled'`. |
| **Geo-Replication** | Premium SKU required. Configure via child `replications` resource. |
| **CMK** | Premium SKU required. Needs user-assigned identity with Key Vault access. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Replications | `Microsoft.ContainerRegistry/registries/replications` | Geo-replication targets |
| Webhooks | `Microsoft.ContainerRegistry/registries/webhooks` | Event notifications |
| Tasks | `Microsoft.ContainerRegistry/registries/tasks` | Automated image builds |
| Scope Maps | `Microsoft.ContainerRegistry/registries/scopeMaps` | Repository-level permissions |
| Tokens | `Microsoft.ContainerRegistry/registries/tokens` | Token-based access |

## References

- [Bicep resource reference (2025-04-01)](https://learn.microsoft.com/azure/templates/microsoft.containerregistry/registries?pivots=deployment-language-bicep)
- [Container Registry overview](https://learn.microsoft.com/azure/container-registry/container-registry-intro)
- [Azure naming rules — Container Registry](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftcontainerregistry)
- [ACR SKU tiers](https://learn.microsoft.com/azure/container-registry/container-registry-skus)

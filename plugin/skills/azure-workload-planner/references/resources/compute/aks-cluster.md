# AKS Cluster

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.ContainerService/managedClusters` |
| Bicep API Version | `2025-10-01` |
| CAF Prefix | `aks` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

`kind` is a free-form string used for portal UI differentiation. Not a closed enum — typically omitted in Bicep.

## SKU Names

| SKU Name | SKU Tier | Description |
|----------|----------|-------------|
| `Base` | `Free` | Free tier — no SLA, no uptime guarantee |
| `Base` | `Standard` | Standard — production, 99.95% SLA with availability zones |
| `Base` | `Premium` | Premium — Standard + long-term support, mission-critical |
| `Automatic` | `Standard` | AKS Automatic — simplified managed experience |
| `Automatic` | `Premium` | AKS Automatic Premium |

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 63 |
| Allowed Characters | Alphanumerics, underscores, and hyphens. Must start and end with alphanumeric. |
| Scope | Resource group |
| Pattern | `aks-{workload}-{env}-{instance}` |
| Example | `aks-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource aksCluster 'Microsoft.ContainerService/managedClusters@2025-10-01' = {
  name: 'string'       // required
  location: 'string'   // required
  sku: {
    name: 'string'     // required — 'Base' or 'Automatic'
    tier: 'string'     // required — 'Free', 'Standard', or 'Premium'
  }
  identity: {
    type: 'SystemAssigned'  // recommended
  }
  properties: {
    dnsPrefix: 'string'     // required (or fqdnSubdomain)
    agentPoolProfiles: [
      {
        name: 'string'      // required — max 12 chars, lowercase alphanumeric
        count: int           // required — number of nodes
        vmSize: 'string'     // required — e.g., 'Standard_DS2_v2'
        mode: 'string'       // required — 'System' or 'User'
      }
    ]
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `properties.dnsPrefix` | DNS prefix for API server | String (globally unique in region) |
| `properties.kubernetesVersion` | Kubernetes version | String (e.g., `1.30`, `1.31`) |
| `properties.agentPoolProfiles[].name` | Node pool name | Linux: max 12 chars; Windows: max 6 chars. Lowercase alphanumeric only. |
| `properties.agentPoolProfiles[].mode` | Pool mode | `System` (required, at least 1), `User` |
| `properties.agentPoolProfiles[].vmSize` | Node VM size | Azure VM SKU string |
| `properties.agentPoolProfiles[].count` | Node count | Integer |
| `properties.agentPoolProfiles[].enableAutoScaling` | Auto-scale nodes | `true`, `false` |
| `properties.agentPoolProfiles[].minCount` | Min nodes (auto-scale) | Integer |
| `properties.agentPoolProfiles[].maxCount` | Max nodes (auto-scale) | Integer |
| `properties.agentPoolProfiles[].osDiskSizeGB` | OS disk size | Integer (GB) |
| `properties.agentPoolProfiles[].availabilityZones` | Zones | `['1']`, `['2']`, `['3']`, or all |
| `properties.agentPoolProfiles[].vnetSubnetID` | Subnet for nodes | Resource ID |
| `properties.networkProfile.networkPlugin` | Network plugin | `azure` (CNI), `kubenet`, `none` |
| `properties.networkProfile.networkPolicy` | Network policy | `azure`, `calico`, `cilium`, `none` |
| `properties.networkProfile.serviceCidr` | Service CIDR | CIDR string (default `10.0.0.0/16`) |
| `properties.networkProfile.dnsServiceIP` | DNS service IP | Must be within serviceCidr |
| `properties.addonProfiles.azureKeyvaultSecretsProvider.enabled` | Key Vault CSI driver | `true`, `false` |
| `properties.addonProfiles.omsagent.enabled` | Container Insights | `true`, `false` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **VNet / Subnet** | With Azure CNI, subnet must have enough IPs for nodes + pods (30 pods/node default × node count). Subnet cannot have other delegations. |
| **kubenet** | Kubenet uses NAT — subnet only needs IPs for nodes. Less IP pressure but no direct pod-to-VNet connectivity. |
| **Key Vault** | Enable `azureKeyvaultSecretsProvider` addon. Use `enableRbacAuthorization: true` on Key Vault with managed identity. |
| **Container Registry** | Attach ACR via `acrPull` role assignment on cluster identity, or use `imagePullSecrets`. |
| **Log Analytics** | Enable `omsagent` addon with `config.logAnalyticsWorkspaceResourceID` pointing to workspace. |
| **Load Balancer** | AKS creates a managed Standard LB by default (`loadBalancerSku: 'standard'`). |
| **System Pool** | At least one agent pool must have `mode: 'System'`. System pools run critical pods (CoreDNS, tunnelfront). |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Agent Pools | `Microsoft.ContainerService/managedClusters/agentPools` | Additional node pools |
| Maintenance | `Microsoft.ContainerService/managedClusters/maintenanceConfigurations` | Maintenance windows |

## References

- [Bicep resource reference (2025-10-01)](https://learn.microsoft.com/azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-bicep)
- [AKS overview](https://learn.microsoft.com/azure/aks/intro-kubernetes)
- [Azure naming rules — ContainerService](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftcontainerservice)
- [AKS networking concepts](https://learn.microsoft.com/azure/aks/concepts-network)

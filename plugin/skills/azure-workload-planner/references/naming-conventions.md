# Azure Naming Conventions

Apply Azure Cloud Adoption Framework (CAF) naming conventions and enforce hard naming constraints per resource type.

## Naming Pattern

```txt
{prefix}-{workload}-{environment}-{region}-{instance}
```

Example: `st-datapipeline-prod-eastus-001`

## CAF Abbreviations

| Resource Type | Abbreviation | Example |
|---------------|--------------|---------|

| Resource Group | `rg` | `rg-datapipeline-prod` |
| Storage Account | `st` | `stdatapipelineprod` |
| App Service | `app` | `app-datapipeline-prod` |
| Function App | `func` | `func-ingest-prod` |
| Key Vault | `kv` | `kv-datapipeline-prod` |
| Cosmos DB | `cosmos` | `cosmos-datapipeline-prod` |
| SQL Server | `sql` | `sql-datapipeline-prod` |
| SQL Database | `sqldb` | `sqldb-orders-prod` |
| Container App | `ca` | `ca-api-prod` |
| AKS Cluster | `aks` | `aks-datapipeline-prod` |
| Virtual Network | `vnet` | `vnet-hub-prod` |
| Subnet | `snet` | `snet-app-prod` |
| NSG | `nsg` | `nsg-app-prod` |
| Log Analytics | `log` | `log-datapipeline-prod` |
| App Insights | `appi` | `appi-datapipeline-prod` |
| Service Bus | `sb` | `sb-datapipeline-prod` |
| Event Hub | `evh` | `evh-datapipeline-prod` |

## Hard Naming Constraints

These constraints cause deployment failures if violated. **The skill MUST enforce them.**

| Resource | Min | Max | Allowed Characters | Scope |
|----------|-----|-----|--------------------|-------|

| Storage Account | 3 | 24 | Lowercase letters and numbers only | Global |
| Key Vault | 3 | 24 | Alphanumeric and hyphens, start with letter | Global |
| Resource Group | 1 | 90 | Alphanumeric, hyphens, underscores, periods, parens | Subscription |
| Function App | 2 | 60 | Alphanumeric and hyphens | Global |
| App Service | 2 | 60 | Alphanumeric and hyphens | Global |
| Cosmos DB Account | 3 | 44 | Lowercase alphanumeric and hyphens | Global |
| SQL Server | 1 | 63 | Lowercase alphanumeric and hyphens, can't start/end with hyphen | Global |
| Container App | 2 | 32 | Lowercase alphanumeric and hyphens | Resource Group |
| AKS Cluster | 1 | 63 | Alphanumeric, hyphens, underscores | Resource Group |
| Virtual Network | 2 | 64 | Alphanumeric, hyphens, underscores, periods | Resource Group |

**Ref:** [Azure resource naming rules](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules)

## Required Subnet Names (Paired Resource Constraints)

Certain Azure services **require** their subnet to have an exact, hardcoded name. Using any other name causes deployment failure.

| Service | Required Subnet Name | Min Size | Notes |
|---------|----------------------|----------|-------|

| Azure Firewall | `AzureFirewallSubnet` | /26 | **Must** be exactly this name. No other name accepted. |
| Azure Firewall (forced tunneling) | `AzureFirewallManagementSubnet` | /26 | Required when forced tunneling is enabled. |
| Azure Bastion | `AzureBastionSubnet` | /26 | **Must** be exactly this name. |
| VPN Gateway / ExpressRoute Gateway | `GatewaySubnet` | /27 | **Must** be exactly this name. Shared by VPN and ExpressRoute. |
| Azure Route Server | `RouteServerSubnet` | /27 | **Must** be exactly this name. |

**Key rules:**

- These names are **case-sensitive** — `azurefirewallsubnet` will fail.
- A VNet can only have **one** of each named subnet.
- These subnets cannot have NSGs applied (except `AzureBastionSubnet` which requires one).
- Do **not** use CAF abbreviation prefixes (`snet-`) for these subnets — use the exact required name.

**Ref:** [Azure Firewall FAQ](https://learn.microsoft.com/azure/firewall/firewall-faq), [Bastion configuration](https://learn.microsoft.com/azure/bastion/configuration-settings)

## Other Paired Resource Naming Constraints

| Pairing | Constraint |
|---------|------------|

| Function Apps sharing a Storage Account | Function app name is truncated to 32 chars for host ID. Two apps with identical first 32 chars on the same storage account cause a **host ID collision** (hard failure in runtime v4.x). Use separate storage accounts or ensure names diverge within 32 chars. |
| AKS Cluster + Resource Group | Auto-generated node RG `MC_{rgName}_{clusterName}_{region}` must be ≤ 80 chars total. |
| SQL Server + SQL Managed Instance | Both share the `<name>.database.windows.net` DNS namespace. Cannot reuse a name for 7 days after deletion of either type. |
| Key Vault (soft-delete) | Cannot reuse a vault name while soft-deleted (7-90 day retention, default 90). With purge protection, no override possible. |
| Windows VM resource name ↔ hostname | Portal uses same value for both; hostname limited to 15 chars (NetBIOS). |
| VMSS instance names | Auto-generated: `{vmss-name}_{guid}` (Flexible, max 44) or `{vmss-name}_{id}` (Uniform, max 64). |
| Private Endpoints + DNS Zones | Each service type requires a fixed Private DNS Zone name (e.g., `privatelink.blob.core.windows.net`). |

## Validation Rules

Before writing a resource name to the plan:

1. Check length against min/max for that resource type
2. Verify only allowed characters are used
3. Check uniqueness scope — globally unique names must be checked
4. Apply CAF abbreviation prefix
5. Include environment suffix for multi-environment plans

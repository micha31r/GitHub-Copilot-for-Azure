# Plan Verification

After generating the full `.azure/infrastructure-plan.json`, run this verification pass before presenting the plan to the user. Walk through each check below, fix any violations in-place using `replace_string_in_file`, and report what was corrected.

## 1. Name Verification

For **every** resource in `plan.resources[]`:

| # | Check | Fix |
|---|-------|-----|

| 1 | Name follows CAF pattern `{prefix}-{workload}-{env}-{region}-{instance}` | Rewrite name using correct CAF abbreviation from [naming-conventions.md](naming-conventions.md) |
| 2 | Name length is within min/max for that resource type | Truncate or restructure name to fit constraints |
| 3 | Name uses only allowed characters for that resource type | Strip or replace disallowed characters |
| 4 | Globally-unique names (Storage, Key Vault, Function App, etc.) avoid predictable collisions | Add distinguishing suffix if needed |
| 5 | Required subnet names match exactly (`AzureFirewallSubnet`, `GatewaySubnet`, `AzureBastionSubnet`, `RouteServerSubnet`, `AzureFirewallManagementSubnet`) | Replace subnet name with the exact required string — no CAF prefix |
| 6 | Function Apps sharing a Storage Account have names that diverge within the first 32 characters | Rename one app or assign separate storage accounts |
| 7 | AKS node resource group composite `MC_{rg}_{cluster}_{region}` ≤ 80 characters | Shorten cluster or resource group name |

## 2. Dependency Verification

Walk the `dependencies` array of every resource:

| # | Check | Fix |
|---|-------|-----|

| 1 | Every name in `dependencies` references an existing resource `name` in the plan | Add the missing resource or remove the stale reference |
| 2 | No circular dependencies exist (A → B → A) | Break the cycle by removing the weaker dependency edge |
| 3 | Implicit dependencies are explicit — e.g., a subnet depends on its VNet, an App Service depends on its App Service Plan | Add missing dependency entries |
| 4 | Provisioning order is achievable — resources can be deployed in an order that satisfies all dependencies | Reorder `plan.resources[]` so dependencies appear first |

## 3. Property & Pairing Verification

Cross-check connected resources against [resource-pairing-constraints.md](resource-pairing-constraints.md):

### 3a. SKU Compatibility

| # | Check | Fix |
|---|-------|-----|

| 1 | Public IP SKU matches Load Balancer SKU (both Standard or both Basic) | Align to Standard (Basic retiring Sep 2025) |
| 2 | Application Gateway v1/v2 on separate subnets; v2 if zone redundancy, autoscaling, or Key Vault integration needed | Upgrade to v2 or split subnets |
| 3 | VPN Gateway SKU supports required features (BGP, IPv6, coexistence) — not Basic if any advanced feature is needed | Upgrade SKU |
| 4 | App Service Plan SKU meets feature requirements (VNet integration ≥ Basic, slots ≥ Standard, isolation ≥ IsolatedV2) | Upgrade plan SKU |
| 5 | Redis Cache tier supports required features (VNet injection = Premium, clustering = Premium/Enterprise) | Upgrade tier |

### 3b. Subnet & Network Conflicts

| # | Check | Fix |
|---|-------|-----|

| 1 | No two services with exclusive subnet requirements share the same subnet | Assign separate subnets |
| 2 | Subnet delegation matches service requirement — delegated for App Service/Container Apps Workload Profiles; NOT delegated for AKS, Consumption-only Container Apps | Fix delegation setting |
| 3 | App Service VNet Integration subnet ≠ App Service Private Endpoint subnet | Split into two subnets |
| 4 | Subnet CIDR sizes meet minimums (/26 for Firewall/Bastion, /27 for Gateway/Container Apps WP, /23 for Container Apps Consumption) | Expand CIDR |
| 5 | GatewaySubnet has no NSG; AzureBastionSubnet has an NSG | Add or remove NSG resource |

### 3c. Storage Pairing

| # | Check | Fix |
|---|-------|-----|

| 1 | Functions storage account uses `StorageV2` or `Storage` kind (not BlobStorage/BlockBlob/FileStorage) | Change `kind` to `StorageV2` |
| 2 | Functions on Consumption plan do not reference network-secured storage | Remove network rules or upgrade to Premium plan |
| 3 | Zone-redundant Functions use ZRS storage (not LRS/GRS) | Change storage SKU to `Standard_ZRS` |
| 4 | VM boot diagnostics storage is not Premium or ZRS | Use `Standard_LRS` or `Standard_GRS` |

### 3d. Cosmos DB

| # | Check | Fix |
|---|-------|-----|

| 1 | Multi-region writes + Strong consistency not configured together | Switch to Session consistency or single-region writes |
| 2 | Serverless accounts are single-region only, no shared-throughput databases | Remove multi-region config or switch to provisioned throughput |

### 3e. Key Vault & CMK

| # | Check | Fix |
|---|-------|-----|

| 1 | Any service using CMK has its Key Vault with `softDeleteEnabled: true` and `enablePurgeProtection: true` | Add properties to Key Vault |
| 2 | CMK at storage creation uses user-assigned managed identity (not system-assigned) | Add a user-assigned identity resource |

### 3f. SQL Database

| # | Check | Fix |
|---|-------|-----|

| 1 | Zone redundancy not configured on Basic/Standard DTU tiers | Upgrade to Premium, Business Critical, or GP vCore |
| 2 | Hyperscale zone-redundant elastic pools use ZRS/GZRS backup storage | Set backup storage redundancy |

### 3g. AKS Networking

| # | Check | Fix |
|---|-------|-----|

| 1 | Pod CIDR does not overlap with cluster subnet, peered VNets, or gateway ranges | Adjust CIDR |
| 2 | Reserved CIDR ranges (169.254.0.0/16, 172.30.0.0/16, 172.31.0.0/16, 192.0.2.0/24) not used | Change to allowed range |
| 3 | CNI Overlay not combined with VM availability sets, virtual nodes, or DCsv2 VMs | Switch CNI plugin or VM series |

## Verification Output

After completing all checks, add a `verification` object to `meta` in the plan JSON:

```json
{
  "meta": {
    "status": "draft",
    "verification": {
      "completedAt": "2026-02-25T12:00:00Z",
      "checksRun": 25,
      "issuesFound": 3,
      "issuesFixed": 3,
      "summary": "Fixed: aligned Public IP to Standard SKU, expanded AzureBastionSubnet to /26, added missing VNet dependency on subnet"
    }
  }
}
```

If any issue **cannot** be auto-fixed (ambiguous user intent, conflicting requirements), flag it in the summary and present it to the user during the Plan Presentation step.

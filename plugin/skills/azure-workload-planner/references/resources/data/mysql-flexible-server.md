# MySQL Flexible Server

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.DBforMySQL/flexibleServers` |
| Bicep API Version | `2023-12-30` |
| CAF Prefix | `mysql` |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions.

> Verify at plan time: `microsoft_docs_fetch` → `https://learn.microsoft.com/azure/reliability/availability-service-by-category`

## Subtypes (kind)

MySQL Flexible Server does not use `kind`.

## SKU Names

The `sku` block requires both `name` and `tier`:

### SKU Tiers

| Tier | Description |
|------|-------------|

| `Burstable` | Cost-effective for low-utilization workloads. B-series VMs. |
| `GeneralPurpose` | Balanced compute and memory. D-series VMs. |
| `MemoryOptimized` | Memory-heavy workloads. E-series VMs. |

### Common SKU Names

| SKU Name | Tier | vCores | Memory |
|----------|------|--------|--------|

| `Standard_B1s` | Burstable | 1 | 1 GiB |
| `Standard_B1ms` | Burstable | 1 | 2 GiB |
| `Standard_B2s` | Burstable | 2 | 4 GiB |
| `Standard_D2ds_v4` | GeneralPurpose | 2 | 8 GiB |
| `Standard_D4ds_v4` | GeneralPurpose | 4 | 16 GiB |
| `Standard_D8ds_v4` | GeneralPurpose | 8 | 32 GiB |
| `Standard_E2ds_v4` | MemoryOptimized | 2 | 16 GiB |
| `Standard_E4ds_v4` | MemoryOptimized | 4 | 32 GiB |
| `Standard_E8ds_v4` | MemoryOptimized | 8 | 64 GiB |

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 3 |
| Max Length | 63 |
| Allowed Characters | Lowercase letters, numbers, and hyphens. Cannot start or end with hyphen. |
| Scope | Global (must be globally unique as DNS name `{name}.mysql.database.azure.com`) |
| Pattern | `mysql-{workload}-{env}-{instance}` |
| Example | `mysql-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource mysqlServer 'Microsoft.DBforMySQL/flexibleServers@2023-12-30' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  sku: {
    name: 'string'     // required — see Common SKU Names table
    tier: 'string'     // required — 'Burstable', 'GeneralPurpose', or 'MemoryOptimized'
  }
  properties: {
    version: 'string'                  // recommended — MySQL version
    administratorLogin: 'string'       // required for new server (createMode: 'Default')
    administratorLoginPassword: 'string' // required for new server
    storage: {
      storageSizeGB: int               // recommended — 20 to 16384
    }
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `sku.name` | VM SKU | See Common SKU Names table |
| `sku.tier` | SKU tier | `Burstable`, `GeneralPurpose`, `MemoryOptimized` |
| `properties.version` | MySQL version | `5.7`, `8.0.21`, `8.4` |
| `properties.administratorLogin` | Admin username | String |
| `properties.administratorLoginPassword` | Admin password | String (secure) |
| `properties.createMode` | Creation mode | `Default`, `PointInTimeRestore`, `GeoRestore`, `Replica` |
| `properties.storage.storageSizeGB` | Storage size in GiB | `20` to `16384` |
| `properties.storage.autoGrow` | Auto-grow storage | `Enabled`, `Disabled` |
| `properties.storage.autoIoScaling` | Auto IO scaling | `Enabled`, `Disabled` |
| `properties.storage.iops` | Provisioned IOPS | Integer |
| `properties.backup.backupRetentionDays` | Backup retention | `1` to `35` |
| `properties.backup.geoRedundantBackup` | Geo-redundant backup | `Enabled`, `Disabled` |
| `properties.highAvailability.mode` | HA mode | `Disabled`, `ZoneRedundant`, `SameZone` |
| `properties.network.delegatedSubnetResourceId` | VNet subnet | Resource ID (delegated subnet) |
| `properties.network.privateDnsZoneResourceId` | Private DNS zone | Resource ID |
| `properties.replicationRole` | Replication role | `None`, `Source`, `Replica` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|

| **VNet (private access)** | Requires a dedicated subnet delegated to `Microsoft.DBforMySQL/flexibleServers`. Subnet must have no other resources. |
| **Private DNS Zone** | Must provide `privateDnsZoneResourceId` referencing `privatelink.mysql.database.azure.com`. DNS zone must be linked to the VNet. |
| **High Availability** | `ZoneRedundant` HA requires `GeneralPurpose` or `MemoryOptimized` tier. Not available with `Burstable`. |
| **Geo-Redundant Backup** | Must be enabled at server creation time. Cannot be changed after creation. Not available in all regions. |
| **Storage Auto-Grow** | Storage can only grow, never shrink. Enabled by default. |
| **Read Replicas** | Source server must have `backup.backupRetentionDays` > 1. Replica count limit: up to 10 replicas. |
| **Key Vault (CMK)** | Customer-managed keys require user-assigned managed identity and Key Vault with purge protection enabled. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|

| Databases | `Microsoft.DBforMySQL/flexibleServers/databases` | Individual databases |
| Configurations | `Microsoft.DBforMySQL/flexibleServers/configurations` | Server parameter settings |
| Firewall Rules | `Microsoft.DBforMySQL/flexibleServers/firewallRules` | Public access IP allow rules |
| Administrators | `Microsoft.DBforMySQL/flexibleServers/administrators` | Azure AD administrators |

## References

- [Bicep resource reference (2023-12-30)](https://learn.microsoft.com/azure/templates/microsoft.dbformysql/flexibleservers?pivots=deployment-language-bicep)
- [MySQL Flexible Server overview](https://learn.microsoft.com/azure/mysql/flexible-server/overview)
- [Azure naming rules — DBforMySQL](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftdbformysql)
- [Compute and storage options](https://learn.microsoft.com/azure/mysql/flexible-server/concepts-compute-storage)

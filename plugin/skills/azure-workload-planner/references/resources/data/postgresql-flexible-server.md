# PostgreSQL Flexible Server

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.DBforPostgreSQL/flexibleServers` |
| Bicep API Version | `2024-08-01` |
| CAF Prefix | `psql` |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions.

> Verify at plan time: `microsoft_docs_fetch` → `https://learn.microsoft.com/azure/reliability/availability-service-by-category`

## Subtypes (kind)

PostgreSQL Flexible Server does not use `kind`.

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
| `Standard_B1ms` | Burstable | 1 | 2 GiB |
| `Standard_B2s` | Burstable | 2 | 4 GiB |
| `Standard_B2ms` | Burstable | 2 | 8 GiB |
| `Standard_D2s_v3` | GeneralPurpose | 2 | 8 GiB |
| `Standard_D4s_v3` | GeneralPurpose | 4 | 16 GiB |
| `Standard_D8s_v3` | GeneralPurpose | 8 | 32 GiB |
| `Standard_E2s_v3` | MemoryOptimized | 2 | 16 GiB |
| `Standard_E4s_v3` | MemoryOptimized | 4 | 32 GiB |
| `Standard_E8s_v3` | MemoryOptimized | 8 | 64 GiB |

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 3 |
| Max Length | 63 |
| Allowed Characters | Lowercase letters, numbers, and hyphens. Cannot start or end with hyphen. |
| Scope | Global (must be globally unique as DNS name `{name}.postgres.database.azure.com`) |
| Pattern | `psql-{workload}-{env}-{instance}` |
| Example | `psql-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  sku: {
    name: 'string'     // required — see Common SKU Names table
    tier: 'string'     // required — 'Burstable', 'GeneralPurpose', or 'MemoryOptimized'
  }
  properties: {
    version: 'string'                  // recommended — PostgreSQL major version
    administratorLogin: 'string'       // required for new server (createMode: 'Default')
    administratorLoginPassword: 'string' // required for new server
    storage: {
      storageSizeGB: int               // recommended — 32 to 32768
    }
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `sku.name` | VM SKU | See Common SKU Names table |
| `sku.tier` | SKU tier | `Burstable`, `GeneralPurpose`, `MemoryOptimized` |
| `properties.version` | PostgreSQL version | `13`, `14`, `15`, `16`, `17`, `18` |
| `properties.administratorLogin` | Admin username | String |
| `properties.administratorLoginPassword` | Admin password | String (secure) |
| `properties.createMode` | Creation mode | `Default`, `PointInTimeRestore`, `GeoRestore`, `Replica`, `ReviveDropped` |
| `properties.storage.storageSizeGB` | Storage size in GiB | `32` to `32768` |
| `properties.storage.autoGrow` | Auto-grow storage | `Enabled`, `Disabled` |
| `properties.backup.backupRetentionDays` | Backup retention | `7` to `35` |
| `properties.backup.geoRedundantBackup` | Geo-redundant backup | `Enabled`, `Disabled` |
| `properties.highAvailability.mode` | HA mode | `Disabled`, `ZoneRedundant`, `SameZone` |
| `properties.network.delegatedSubnetResourceId` | VNet subnet | Resource ID (delegated subnet) |
| `properties.network.privateDnsZoneArmResourceId` | Private DNS zone | Resource ID |
| `properties.authConfig.activeDirectoryAuth` | Entra ID auth | `Enabled`, `Disabled` |
| `properties.authConfig.passwordAuth` | Password auth | `Enabled`, `Disabled` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **VNet (private access)** | Requires a dedicated subnet delegated to `Microsoft.DBforPostgreSQL/flexibleServers`. Subnet must have no other resources. |
| **Private DNS Zone** | For VNet-integrated (private access) servers, use the zone name `{name}.postgres.database.azure.com` (not `privatelink.*`). The `privatelink.postgres.database.azure.com` zone is used for Private Endpoint connectivity only. Provide `privateDnsZoneArmResourceId` and the DNS zone must be linked to the VNet. |
| **High Availability** | `ZoneRedundant` HA requires `GeneralPurpose` or `MemoryOptimized` tier. Not available with `Burstable`. |
| **Geo-Redundant Backup** | Not available in all regions. Cannot be enabled with VNet-integrated (private access) servers in some configurations. |
| **Storage Auto-Grow** | Storage can only grow, never shrink. Minimum increase is based on current size. |
| **Key Vault (CMK)** | Customer-managed keys require user-assigned managed identity and Key Vault with purge protection enabled. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Databases | `Microsoft.DBforPostgreSQL/flexibleServers/databases` | Individual databases |
| Configurations | `Microsoft.DBforPostgreSQL/flexibleServers/configurations` | Server parameter settings |
| Firewall Rules | `Microsoft.DBforPostgreSQL/flexibleServers/firewallRules` | Public access IP allow rules |
| Administrators | `Microsoft.DBforPostgreSQL/flexibleServers/administrators` | Azure AD administrators |

## References

- [Bicep resource reference (2024-08-01)](https://learn.microsoft.com/azure/templates/microsoft.dbforpostgresql/flexibleservers?pivots=deployment-language-bicep)
- [PostgreSQL Flexible Server overview](https://learn.microsoft.com/azure/postgresql/flexible-server/overview)
- [Azure naming rules — DBforPostgreSQL](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftdbforpostgresql)
- [Compute and storage options](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-compute-storage)

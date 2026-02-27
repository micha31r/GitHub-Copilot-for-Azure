# SQL Database

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Sql/servers/databases` |
| Bicep API Version | `2023-08-01` |
| CAF Prefix | `sqldb` |
| Parent Resource | `Microsoft.Sql/servers` (see [sql-server.md](sql-server.md)) |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

SQL Database `kind` is **read-only** — it is computed by Azure and cannot be set in Bicep.

## SKU Names

The `sku.name` is a free-form string, but must match one of the recognized patterns. `sku.tier` selects the service tier.

### SKU Tiers

| Tier | Description |
|------|-------------|
| `Basic` | Basic DTU tier |
| `Standard` | Standard DTU tier |
| `Premium` | Premium DTU tier |
| `GeneralPurpose` | vCore general purpose |
| `BusinessCritical` | vCore business critical |
| `Hyperscale` | vCore hyperscale |

### Common SKU Names

| SKU Name | Tier | Model | Description |
|----------|------|-------|-------------|
| `Basic` | Basic | DTU | 5 DTU |
| `S0` – `S12` | Standard | DTU | 10–3000 DTU |
| `P1` – `P15` | Premium | DTU | 125–4000 DTU |
| `GP_Gen5_2` | GeneralPurpose | vCore | Gen5, 2 vCores |
| `GP_S_Gen5_1` | GeneralPurpose | vCore (Serverless) | Gen5, 1 vCore, auto-pause |
| `BC_Gen5_2` | BusinessCritical | vCore | Gen5, 2 vCores |
| `HS_Gen5_2` | Hyperscale | vCore | Gen5, 2 vCores |

> **Note:** SKU name format for vCore: `{tier-prefix}_Gen5_{vCores}`. Serverless adds `_S_`: `GP_S_Gen5_{vCores}`.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 128 |
| Allowed Characters | Cannot use `<>*%&:\/?` or end with `.` or space |
| Scope | Parent server (unique within the SQL Server) |
| Pattern | `sqldb-{workload}-{env}-{instance}` |
| Example | `sqldb-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01' = {
  name: 'string'       // required
  location: 'string'   // required — must match parent server location
  parent: sqlServer     // required — reference to Microsoft.Sql/servers
  sku: {
    name: 'string'     // recommended — defaults to Standard S0
    tier: 'string'     // recommended — see SKU Tiers table
  }
  properties: {}
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `sku.name` | SKU name | See Common SKU Names table |
| `sku.tier` | Service tier | `Basic`, `Standard`, `Premium`, `GeneralPurpose`, `BusinessCritical`, `Hyperscale` |
| `properties.createMode` | Creation mode | `Default`, `Copy`, `Secondary`, `PointInTimeRestore`, `Restore`, `Recovery`, `RestoreExternalBackup`, `RestoreLongTermRetentionBackup`, `OnlineSecondary` |
| `properties.elasticPoolId` | Elastic pool resource ID | Resource ID string |
| `properties.licenseType` | License model | `BasePrice` (AHUB), `LicenseIncluded` |
| `properties.requestedBackupStorageRedundancy` | Backup redundancy | `Geo`, `Local`, `Zone`, `GeoZone` |
| `properties.zoneRedundant` | Zone redundancy | `true`, `false` |
| `properties.maxSizeBytes` | Max size in bytes | Integer |
| `properties.autoPauseDelay` | Auto-pause minutes (Serverless) | Integer (`-1` = disabled) |
| `properties.minCapacity` | Minimum vCores (Serverless) | Decimal (e.g., `0.5`) |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **SQL Server** | Must be deployed as child of the parent SQL Server. Location must match. |
| **Elastic Pool** | `elasticPoolId` must reference a pool on the same server. Cannot set `sku` when using elastic pool (it inherits pool SKU). |
| **Zone Redundancy** | Only available in `GeneralPurpose`, `BusinessCritical`, and `Hyperscale` tiers. Not available in DTU tiers. |
| **Serverless** | Only available in `GeneralPurpose` tier. SKU name uses `GP_S_Gen5_*` pattern. |
| **Hyperscale** | Cannot move from Hyperscale to other tiers. One-way migration. |
| **Backup Redundancy** | `GeoZone` only available in select regions. `Local` not available in all regions. |

## Child Resources

SQL Database has no significant Bicep child resources — configuration is on the database properties or server-level children.

## References

- [Bicep resource reference (2023-08-01)](https://learn.microsoft.com/azure/templates/microsoft.sql/servers/databases?pivots=deployment-language-bicep)
- [SQL Database overview](https://learn.microsoft.com/azure/azure-sql/database/sql-database-paas-overview)
- [Azure naming rules — SQL](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftsql)
- [SQL Database DTU vs vCore](https://learn.microsoft.com/azure/azure-sql/database/purchasing-models)

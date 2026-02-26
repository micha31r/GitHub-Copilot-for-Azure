# SQL Server

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.Sql/servers` |
| Bicep API Version | `2023-08-01` |
| CAF Prefix | `sql` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

SQL Server `kind` is **read-only** — it is computed by Azure and cannot be set in Bicep.

## SKU Names

SQL Server (logical server) does not use SKU. SKU is configured on the child **databases**.

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 1 |
| Max Length | 63 |
| Allowed Characters | Lowercase letters, numbers, and hyphens. Must start with a letter, end with a letter or number. |
| Scope | Global (must be globally unique as DNS name `{name}.database.windows.net`) |
| Pattern | `sql-{workload}-{env}-{instance}` |
| Example | `sql-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  properties: {
    administratorLogin: 'string'          // required (immutable after creation)
    administratorLoginPassword: 'string'  // required (write-only)
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `properties.administratorLogin` | SQL admin username | String — **immutable** after creation |
| `properties.administratorLoginPassword` | SQL admin password | String — write-only, not returned by GET |
| `properties.administrators` | Azure AD admin config | Object with `azureADOnlyAuthentication`, `login`, `sid`, `tenantId` |
| `properties.minimalTlsVersion` | Minimum TLS version | `None`, `1.0`, `1.1`, `1.2`, `1.3` |
| `properties.publicNetworkAccess` | Public access | `Disabled`, `Enabled` |
| `properties.restrictOutboundNetworkAccess` | Outbound restrictions | `Disabled`, `Enabled` |
| `properties.version` | Server version | `2.0`, `12.0` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|

| **SQL Database** | Databases are child resources — must reference this server as parent. |
| **Key Vault (TDE)** | Key Vault must have `enablePurgeProtection: true`. Must be in same Azure AD tenant. Server needs GET, WRAP KEY, UNWRAP KEY permissions on key. |
| **Virtual Network** | Use `Microsoft.Sql/servers/virtualNetworkRules` to restrict access to specific subnets. Subnets need `Microsoft.Sql` service endpoint. |
| **Private Endpoint** | Set `publicNetworkAccess: 'Disabled'` when using private endpoints exclusively. |
| **Elastic Pool** | Databases using elastic pools reference `elasticPoolId` — server must host both pool and databases. |
| **Failover Group** | Both primary and secondary servers must exist. Databases to be replicated must belong to the primary server. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|

| Databases | `Microsoft.Sql/servers/databases` | SQL databases (see [sql-database.md](sql-database.md)) |
| Elastic Pools | `Microsoft.Sql/servers/elasticPools` | Shared resource pools |
| Firewall Rules | `Microsoft.Sql/servers/firewallRules` | IP-based firewall rules |
| VNet Rules | `Microsoft.Sql/servers/virtualNetworkRules` | Subnet-based access control |
| Failover Groups | `Microsoft.Sql/servers/failoverGroups` | Geo-replication and failover |
| AAD Administrators | `Microsoft.Sql/servers/administrators` | Azure AD admin config |
| Audit Settings | `Microsoft.Sql/servers/auditingSettings` | Server-level auditing |

## References

- [Bicep resource reference (2023-08-01)](https://learn.microsoft.com/azure/templates/microsoft.sql/servers?pivots=deployment-language-bicep)
- [SQL Server overview](https://learn.microsoft.com/azure/azure-sql/database/sql-database-paas-overview)
- [Azure naming rules — SQL](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftsql)
- [SQL Server TDE with Key Vault](https://learn.microsoft.com/azure/azure-sql/database/transparent-data-encryption-byok-overview)

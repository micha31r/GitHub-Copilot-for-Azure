# Cosmos DB

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.DocumentDB/databaseAccounts` |
| Bicep API Version | `2025-04-15` |
| CAF Prefix | `cosmos` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

These are the exact `kind` values accepted in Bicep:

| Kind | Description |
|------|-------------|

| `GlobalDocumentDB` | SQL (NoSQL) API — **default** |
| `MongoDB` | MongoDB API |
| `Parse` | Parse-compatible (legacy) |

> **Note:** Cassandra, Table, and Gremlin APIs are selected via `properties.capabilities`, not `kind`. See Key Properties.

## SKU Names

Cosmos DB does not use a `sku` block. Throughput is configured via `databaseAccountOfferType` and individual database/container settings.

| Property | Value | Description |
|----------|-------|-------------|

| `properties.databaseAccountOfferType` | `Standard` | **Only accepted value** — required |

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 3 |
| Max Length | 44 |
| Allowed Characters | Lowercase letters, numbers, and hyphens. Must start/end with letter or number. No consecutive hyphens. |
| Scope | Global (must be globally unique as DNS name) |
| Pattern | `cosmos-{workload}-{env}-{instance}` |
| Example | `cosmos-datapipeline-prod-001` |
| Regex | `^[a-z0-9]+(-[a-z0-9]+)*$` |

## Required Properties (Bicep)

```bicep
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2025-04-15' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  kind: 'string'       // optional — defaults to 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'  // required — only valid value
    locations: [
      {
        locationName: 'string'        // required
        failoverPriority: int         // required (0 for primary)
        isZoneRedundant: bool         // optional
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'string'  // required
    }
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `properties.consistencyPolicy.defaultConsistencyLevel` | Default consistency | `Eventual`, `Session`, `BoundedStaleness`, `Strong`, `ConsistentPrefix` |
| `properties.enableMultipleWriteLocations` | Multi-region writes | `true`, `false` |
| `properties.enableAutomaticFailover` | Auto failover | `true`, `false` |
| `properties.enableFreeTier` | Free tier (1 per subscription) | `true`, `false` |
| `properties.createMode` | Account creation mode | `Default`, `Restore` |
| `properties.capabilities[].name` | API capabilities | `EnableCassandra`, `EnableTable`, `EnableGremlin`, `EnableServerless`, `EnableMongo` |
| `properties.isVirtualNetworkFilterEnabled` | VNet filtering | `true`, `false` |
| `properties.publicNetworkAccess` | Public access | `Disabled`, `Enabled`, `SecuredByPerimeter` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|

| **Multi-region writes** | `consistencyPolicy.defaultConsistencyLevel` cannot be `Strong` when `enableMultipleWriteLocations: true`. |
| **Serverless** | Cannot combine `EnableServerless` capability with multi-region writes or analytical store. |
| **Free tier** | Only one free-tier account per subscription. Cannot combine with multi-region writes. |
| **VNet** | Set `isVirtualNetworkFilterEnabled: true` and configure `virtualNetworkRules[]` with subnet IDs. Subnets need `Microsoft.AzureCosmosDB` service endpoint. |
| **Private Endpoint** | Set `publicNetworkAccess: 'Disabled'` when using private endpoints exclusively. |
| **Key Vault (CMK)** | Requires `keyVaultKeyUri` in encryption config. Key Vault must be in same region. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|

| SQL Databases | `Microsoft.DocumentDB/databaseAccounts/sqlDatabases` | NoSQL API databases |
| SQL Containers | `Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers` | NoSQL API containers |
| MongoDB Databases | `Microsoft.DocumentDB/databaseAccounts/mongodbDatabases` | MongoDB API databases |
| MongoDB Collections | `Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections` | MongoDB API collections |
| Cassandra Keyspaces | `Microsoft.DocumentDB/databaseAccounts/cassandraKeyspaces` | Cassandra API keyspaces |
| Gremlin Databases | `Microsoft.DocumentDB/databaseAccounts/gremlinDatabases` | Gremlin API graph databases |
| Table Resources | `Microsoft.DocumentDB/databaseAccounts/tables` | Table API tables |

## References

- [Bicep resource reference (2025-04-15)](https://learn.microsoft.com/azure/templates/microsoft.documentdb/databaseaccounts?pivots=deployment-language-bicep)
- [Cosmos DB overview](https://learn.microsoft.com/azure/cosmos-db/introduction)
- [Azure naming rules — Cosmos DB](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftdocumentdb)
- [Consistency levels](https://learn.microsoft.com/azure/cosmos-db/consistency-levels)

# Azure AI Search

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.Search/searchServices` |
| Bicep API Version | `2025-05-01` |
| CAF Prefix | `srch` |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions.

## Subtypes (kind)

This resource does **not** use a `kind` property. All search services are the same type.

## SKU Names

Exact `sku.name` values for Bicep:

| SKU | Description | Max Partitions | Max Replicas |
|-----|-------------|----------------|--------------|

| `free` | Free tier — 1 index, 50 MB storage | 1 | 1 |
| `basic` | Basic tier — 15 indexes, 2 GB storage | 1 | 3 |
| `standard` | Standard S1 — 50 indexes, 25 GB/partition | 12 | 12 |
| `standard2` | Standard S2 — 200 indexes, 100 GB/partition | 12 | 12 |
| `standard3` | Standard S3 — 200 indexes, 200 GB/partition; supports HighDensity | 12 | 12 |
| `storage_optimized_l1` | Storage Optimized L1 — 10 indexes, 1 TB/partition | 12 | 12 |
| `storage_optimized_l2` | Storage Optimized L2 — 10 indexes, 2 TB/partition | 12 | 12 |

> **Note:** SKU **cannot** be changed after creation. You must create a new service to change SKU.

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 2 |
| Max Length | 60 |
| Allowed Characters | Lowercase letters, numbers, and hyphens only |
| Pattern (regex) | `^(?=.{2,60}$)[a-z0-9][a-z0-9]+(-[a-z0-9]+)*$` |
| Scope | Global (must be globally unique — forms `{name}.search.windows.net`) |
| Example | `srch-products-prod-001` |

> Must start and end with a lowercase letter or number. No consecutive hyphens. No uppercase.

## Required Properties (Bicep)

```bicep
resource searchService 'Microsoft.Search/searchServices@2025-05-01' = {
  name: 'string'        // required, 2-60 chars, globally unique
  location: 'string'    // required
  sku: {
    name: 'string'      // required — see SKU Names table
  }
  properties: {
    replicaCount: int    // optional, default 1
    partitionCount: int  // optional, default 1
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `properties.replicaCount` | Number of replicas | 1–12 (standard); 1–3 (basic); minimum 2 for read HA, 3 for read/write HA |
| `properties.partitionCount` | Number of partitions | 1, 2, 3, 4, 6, or 12 (must be a factor of 12) |
| `properties.hostingMode` | Hosting mode | `Default`, `HighDensity` (HighDensity only for `standard3` SKU) |
| `properties.semanticSearch` | Semantic search capability | `disabled`, `free`, `standard` |
| `properties.publicNetworkAccess` | Public network access | `Enabled`, `Disabled`, `SecuredByPerimeter` |
| `properties.disableLocalAuth` | Disable API key auth | `true`, `false` |
| `properties.authOptions.aadOrApiKey` | Entra ID + API key auth | Object with `aadAuthFailureMode`: `http401WithBearerChallenge` or `http403` |
| `properties.authOptions.apiKeyOnly` | API key only auth | Object (empty) |
| `properties.computeType` | Compute type | `Default`, `Confidential` |
| `properties.encryptionWithCmk.enforcement` | CMK enforcement | `Disabled`, `Enabled`, `Unspecified` |
| `properties.networkRuleSet.bypass` | Bypass trusted services | `AzureServices`, `None` |

## Pairing Constraints

| Paired With | Constraint |
|-------------|------------|

| **Cognitive Services (AI Enrichment)** | For AI enrichment pipelines (skillsets), attach a Cognitive Services account. Must be `kind: 'CognitiveServices'` or `kind: 'AIServices'` and in the same region as the search service. |
| **Storage Account (Indexers)** | Indexer data sources support Blob, Table, and File storage. Storage must be accessible (same VNet or public). For managed identity access, assign `Storage Blob Data Reader` role. |
| **Cosmos DB (Indexers)** | Indexer data source for Cosmos DB. Requires connection string or managed identity with `Cosmos DB Account Reader Role`. |
| **SQL Database (Indexers)** | Indexer data source. Requires change tracking enabled on the source table. |
| **Private Endpoints** | When `publicNetworkAccess: 'Disabled'`, create shared private link resources for outbound connections to data sources. |
| **Managed Identity** | Assign system or user-assigned identity for secure connections to data sources. Use RBAC instead of connection strings. |
| **Semantic Search** | Requires `semanticSearch` property set to `free` or `standard`. Available on `basic` and above SKUs. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|

| Private Endpoint Connections | `Microsoft.Search/searchServices/privateEndpointConnections` | Private networking |
| Shared Private Link Resources | `Microsoft.Search/searchServices/sharedPrivateLinkResources` | Outbound private connections to data sources |
| Network Security Perimeter | `Microsoft.Search/searchServices/networkSecurityPerimeterConfigurations` | NSP configuration |

## References

- [Bicep resource reference (2025-05-01)](https://learn.microsoft.com/azure/templates/microsoft.search/searchservices?pivots=deployment-language-bicep)
- [All API versions](https://learn.microsoft.com/azure/templates/microsoft.search/allversions)
- [Azure naming rules — Search](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftsearch)
- [Service limits](https://learn.microsoft.com/azure/search/search-limits-quotas-capacity)
- [CAF abbreviations](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)

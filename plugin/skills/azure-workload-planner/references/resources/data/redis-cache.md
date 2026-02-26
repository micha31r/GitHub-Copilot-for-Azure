# Redis Cache

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Cache/redis` |
| Bicep API Version | `2024-11-01` |
| CAF Prefix | `redis` |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions.

> Verify at plan time: `microsoft_docs_fetch` → `https://learn.microsoft.com/azure/reliability/availability-service-by-category`

## Subtypes (kind)

Redis Cache does not use `kind`.

## SKU Names

All three SKU fields are **required**:

| SKU Name | SKU Family | Capacity Range | Description |
|----------|------------|----------------|-------------|
| `Basic` | `C` | `0` – `6` | Basic — no SLA, no replication, dev/test |
| `Standard` | `C` | `0` – `6` | Standard — SLA, replication, 2 nodes |
| `Premium` | `P` | `1` – `5` | Premium — clustering, VNet, persistence, geo-replication |

### Capacity Sizes (C Family)

| Capacity | Cache Size |
|----------|------------|
| `0` | 250 MB |
| `1` | 1 GB |
| `2` | 2.5 GB |
| `3` | 6 GB |
| `4` | 13 GB |
| `5` | 26 GB |
| `6` | 53 GB |

### Capacity Sizes (P Family)

| Capacity | Cache Size (per shard) |
|----------|------------------------|
| `1` | 6 GB |
| `2` | 13 GB |
| `3` | 26 GB |
| `4` | 53 GB |
| `5` | 120 GB |

> **Note:** `sku.family` must be `'C'` for Basic/Standard and `'P'` for Premium. Mismatched family causes deployment failure.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 63 |
| Allowed Characters | Alphanumerics and hyphens. Must start and end with alphanumeric. No consecutive hyphens. |
| Scope | Global (must be globally unique as DNS name `{name}.redis.cache.windows.net`) |
| Pattern | `redis-{workload}-{env}-{instance}` |
| Example | `redis-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource redisCache 'Microsoft.Cache/redis@2024-11-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  properties: {
    sku: {
      name: 'string'     // required — 'Basic', 'Standard', or 'Premium'
      family: 'string'   // required — 'C' (Basic/Standard) or 'P' (Premium)
      capacity: int      // required — see Capacity tables
    }
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `properties.sku.name` | SKU tier | `Basic`, `Standard`, `Premium` |
| `properties.sku.family` | SKU family | `C` (Basic/Standard), `P` (Premium) |
| `properties.sku.capacity` | Cache size | `0`–`6` (C) or `1`–`5` (P) |
| `properties.enableNonSslPort` | Allow non-SSL (port 6379) | `true`, `false` (default: `false`) |
| `properties.minimumTlsVersion` | Minimum TLS | `1.0`, `1.1`, `1.2` |
| `properties.redisConfiguration.maxmemory-policy` | Eviction policy | `volatile-lru`, `allkeys-lru`, `volatile-random`, `allkeys-random`, `volatile-ttl`, `noeviction` |
| `properties.shardCount` | Cluster shard count (Premium) | Integer (max `10`) |
| `properties.replicasPerMaster` | Replicas (Premium) | Integer |
| `properties.publicNetworkAccess` | Public access | `Disabled`, `Enabled` |
| `properties.subnetId` | VNet injection subnet (Premium) | Resource ID |
| `zones` | Availability zones | `['1']`, `['2']`, `['3']` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **VNet** | Only Premium SKU supports VNet injection via `subnetId`. Basic/Standard use firewall rules only. |
| **Private Endpoint** | Available for Standard and Premium. Set `publicNetworkAccess: 'Disabled'` when using private endpoints. |
| **Clustering** | Only Premium SKU supports `shardCount`. Basic and Standard are single-node/two-node only. |
| **Persistence** | Only Premium SKU supports RDB/AOF persistence. Requires a storage account for RDB exports. |
| **Geo-replication** | Only Premium SKU. Primary and secondary must be Premium with same shard count. |
| **Zones** | Zone redundancy requires Premium SKU with multiple replicas. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Firewall Rules | `Microsoft.Cache/redis/firewallRules` | IP-based access rules |
| Linked Servers | `Microsoft.Cache/redis/linkedServers` | Geo-replication links |
| Patch Schedules | `Microsoft.Cache/redis/patchSchedules` | Maintenance windows |

## References

- [Bicep resource reference (2024-11-01)](https://learn.microsoft.com/azure/templates/microsoft.cache/redis?pivots=deployment-language-bicep)
- [Azure Cache for Redis overview](https://learn.microsoft.com/azure/azure-cache-for-redis/cache-overview)
- [Azure naming rules — Cache](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftcache)
- [Redis Cache tiers](https://learn.microsoft.com/azure/azure-cache-for-redis/cache-overview#service-tiers)

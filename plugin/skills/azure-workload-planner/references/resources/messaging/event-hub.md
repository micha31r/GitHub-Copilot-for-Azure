# Event Hub Namespace

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.EventHub/namespaces` |
| Bicep API Version | `2024-01-01` |
| CAF Prefix | `evhns` (namespace) / `evh` (event hub) |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

Event Hub does not use `kind`.

## SKU Names

| SKU Name | SKU Tier | Description |
|----------|----------|-------------|

| `Basic` | `Basic` | Basic — 1 consumer group, 1-day retention, 100 brokered connections |
| `Standard` | `Standard` | Standard — 20 consumer groups, 7-day retention, 1000 connections |
| `Premium` | `Premium` | Premium — dedicated capacity, 90-day retention, VNet, zones |

> **Note:** Event Hubs Dedicated is a separate resource type (`Microsoft.EventHub/clusters`), not a SKU.

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 6 |
| Max Length | 50 |
| Allowed Characters | Alphanumerics and hyphens. Must start with a letter, end with letter or number. |
| Scope | Global (must be globally unique as DNS name `{name}.servicebus.windows.net`) |
| Pattern | `evhns-{workload}-{env}-{instance}` |
| Regex | `^[a-zA-Z][a-zA-Z0-9-]{4,48}[a-zA-Z0-9]$` |
| Example | `evhns-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource eventHubNs 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  sku: {
    name: 'string'     // required — 'Basic', 'Standard', or 'Premium'
    tier: 'string'     // optional — matches sku.name
    capacity: int      // optional — throughput units (Standard: 1–40) or processing units (Premium: 1–16)
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `sku.name` | Pricing tier | `Basic`, `Standard`, `Premium` |
| `sku.tier` | Tier (matches name) | `Basic`, `Standard`, `Premium` |
| `sku.capacity` | Throughput/processing units | Integer (Standard: `1`–`40`, Premium: `1`–`16`) |
| `properties.isAutoInflateEnabled` | Auto-inflate (Standard) | `true`, `false` |
| `properties.maximumThroughputUnits` | Max TU for auto-inflate | `1` to `40` |
| `properties.zoneRedundant` | Zone redundancy | `true`, `false` |
| `properties.minimumTlsVersion` | Minimum TLS | `1.0`, `1.1`, `1.2` |
| `properties.publicNetworkAccess` | Public access | `Disabled`, `Enabled`, `SecuredByPerimeter` |
| `properties.disableLocalAuth` | Disable SAS keys | `true`, `false` |
| `properties.kafkaEnabled` | Kafka protocol support | `true` (Standard/Premium), `false` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|

| **VNet** | Only Premium SKU supports VNet service endpoints and private endpoints natively. |
| **Zone Redundancy** | Available in Standard (with ≥4 TU recommended) and Premium. |
| **Kafka** | Kafka protocol support available in Standard and Premium only (not Basic). |
| **Capture** | Event capture to Storage/Data Lake available in Standard and Premium only. |
| **Consumer Groups** | Basic: 1 consumer group. Standard: 20. Premium: unlimited. |
| **Retention** | Basic: 1 day. Standard: 1–7 days. Premium: up to 90 days. |
| **Function App** | Event Hub trigger uses connection string or managed identity. Set `EventHubConnection` in app settings. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|

| Event Hubs | `Microsoft.EventHub/namespaces/eventhubs` | Individual event hubs |
| Auth Rules | `Microsoft.EventHub/namespaces/authorizationRules` | SAS access policies |
| Consumer Groups | `Microsoft.EventHub/namespaces/eventhubs/consumergroups` | Consumer group definitions |
| Disaster Recovery | `Microsoft.EventHub/namespaces/disasterRecoveryConfigs` | Geo-DR config |
| Network Rules | `Microsoft.EventHub/namespaces/networkRuleSets` | Network access rules |
| Schema Groups | `Microsoft.EventHub/namespaces/schemagroups` | Schema registry |

## References

- [Bicep resource reference (2024-01-01)](https://learn.microsoft.com/azure/templates/microsoft.eventhub/namespaces?pivots=deployment-language-bicep)
- [Event Hubs overview](https://learn.microsoft.com/azure/event-hubs/event-hubs-about)
- [Azure naming rules — EventHub](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsofteventhub)
- [Event Hubs tiers](https://learn.microsoft.com/azure/event-hubs/event-hubs-quotas)

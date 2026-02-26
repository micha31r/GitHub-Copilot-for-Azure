# Service Bus Namespace

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.ServiceBus/namespaces` |
| Bicep API Version | `2024-01-01` |
| CAF Prefix | `sbns` (namespace) / `sbq` (queue) / `sbt` (topic) |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

Service Bus does not use `kind`.

## SKU Names

| SKU Name | SKU Tier | Description |
|----------|----------|-------------|

| `Basic` | `Basic` | Basic — queues only, no topics, 256 KB message size |
| `Standard` | `Standard` | Standard — queues + topics, 256 KB messages, shared capacity |
| `Premium` | `Premium` | Premium — dedicated capacity, 100 MB messages, VNet, zones |

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 6 |
| Max Length | 50 |
| Allowed Characters | Alphanumerics and hyphens. Must start with a letter, end with letter or number. |
| Scope | Global (must be globally unique as DNS name `{name}.servicebus.windows.net`) |
| Pattern | `sbns-{workload}-{env}-{instance}` |
| Example | `sbns-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource serviceBus 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  sku: {
    name: 'string'     // required — 'Basic', 'Standard', or 'Premium'
    tier: 'string'     // optional — matches sku.name
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `sku.name` | Pricing tier | `Basic`, `Standard`, `Premium` |
| `sku.tier` | Tier (matches name) | `Basic`, `Standard`, `Premium` |
| `sku.capacity` | Messaging units (Premium) | `1`, `2`, `4`, `8`, `16` |
| `properties.zoneRedundant` | Zone redundancy (Premium) | `true`, `false` |
| `properties.premiumMessagingPartitions` | Partitions (Premium) | `1`, `2`, `4` |
| `properties.minimumTlsVersion` | Minimum TLS | `1.0`, `1.1`, `1.2` |
| `properties.publicNetworkAccess` | Public access | `Disabled`, `Enabled`, `SecuredByPerimeter` |
| `properties.disableLocalAuth` | Disable SAS keys | `true`, `false` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|

| **Topics** | Only Standard and Premium SKUs support topics and subscriptions. Basic supports queues only. |
| **VNet** | Only Premium SKU supports VNet service endpoints and private endpoints. |
| **Zone Redundancy** | Only Premium SKU supports zone redundancy. |
| **Partitioning** | Premium messaging partitions cannot be changed after creation. |
| **Message Size** | Basic/Standard: max 256 KB. Premium: max 100 MB. Plan accordingly for large payloads. |
| **Function App** | Service Bus trigger uses connection string or managed identity. Set `ServiceBusConnection` in app settings. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|

| Queues | `Microsoft.ServiceBus/namespaces/queues` | Message queues |
| Topics | `Microsoft.ServiceBus/namespaces/topics` | Pub/sub topics (Standard/Premium) |
| Auth Rules | `Microsoft.ServiceBus/namespaces/authorizationRules` | SAS access policies |
| Disaster Recovery | `Microsoft.ServiceBus/namespaces/disasterRecoveryConfigs` | Geo-DR config |
| Network Rules | `Microsoft.ServiceBus/namespaces/networkRuleSets` | Network access rules |

## References

- [Bicep resource reference (2024-01-01)](https://learn.microsoft.com/azure/templates/microsoft.servicebus/namespaces?pivots=deployment-language-bicep)
- [Service Bus overview](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-messaging-overview)
- [Azure naming rules — ServiceBus](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftservicebus)
- [Service Bus tiers](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-premium-messaging)

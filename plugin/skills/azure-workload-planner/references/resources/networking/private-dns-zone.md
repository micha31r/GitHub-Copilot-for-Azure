# Private DNS Zone

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Network/privateDnsZones` |
| Bicep API Version | `2024-06-01` |
| CAF Prefix | *(none — name is the DNS domain, e.g., `privatelink.database.windows.net`)* |

## Region Availability

**Category:** Foundational — global resource, available in all Azure regions.

> **Note:** Private DNS Zones use `location: 'global'` — they are not region-scoped.

## Subtypes (kind)

Private DNS Zone does not use `kind`.

## SKU Names

Private DNS Zone does not use a `sku` block.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 (per label) |
| Max Length | 63 characters per label, up to 34 labels, total max 253 characters |
| Allowed Characters | Alphanumerics, hyphens, and underscores per label, separated by periods. Labels cannot start or end with hyphen. |
| Scope | Resource group |
| Pattern | `privatelink.{service-specific-domain}` |
| Example | `privatelink.blob.core.windows.net` |

### Common Private DNS Zone Names

| Service | Zone Name |
|---------|-----------|
| Azure SQL / SQL Server | `privatelink.database.windows.net` |
| Storage — Blob | `privatelink.blob.core.windows.net` |
| Storage — File | `privatelink.file.core.windows.net` |
| Storage — Queue | `privatelink.queue.core.windows.net` |
| Storage — Table | `privatelink.table.core.windows.net` |
| Key Vault | `privatelink.vaultcore.azure.net` |
| Container Registry | `privatelink.azurecr.io` |
| Azure Cosmos DB (SQL API) | `privatelink.documents.azure.com` |
| Azure Database for PostgreSQL | `privatelink.postgres.database.azure.com` |
| Azure Database for MySQL | `privatelink.mysql.database.azure.com` |
| App Service / Function App | `privatelink.azurewebsites.net` |
| Event Hub | `privatelink.servicebus.windows.net` |
| Service Bus | `privatelink.servicebus.windows.net` |

## Required Properties (Bicep)

```bicep
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'string'         // required — the DNS zone name (e.g., 'privatelink.blob.core.windows.net')
  location: 'global'     // required — must always be 'global'
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `location` | Must be `'global'` | `global` |
| `tags` | Resource tags | Object of key/value pairs |

> **Note:** Private DNS Zones have minimal top-level properties. Configuration is done via child resources (virtual network links, record sets).

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **Virtual Network** | Must create a `virtualNetworkLinks` child resource to link the DNS zone to each VNet that needs resolution. |
| **Private Endpoint** | Use a `privateDnsZoneGroups` child on the Private Endpoint to auto-register A records, or manually create A record sets. |
| **VNet Link (auto-registration)** | Only one Private DNS Zone with `registrationEnabled: true` can be linked per VNet. Auto-registration creates DNS records for VMs in the VNet. |
| **Hub-Spoke VNet** | Link the Private DNS Zone to the hub VNet. Spoke VNets resolve via hub DNS forwarder or VNet link. |
| **PostgreSQL Flexible Server** | For Private Endpoint access, zone name is `privatelink.postgres.database.azure.com`. For VNet-integrated (private access) servers, the zone name is `{name}.postgres.database.azure.com` (not `privatelink.*`). Referenced via `properties.network.privateDnsZoneArmResourceId`. |
| **MySQL Flexible Server** | For Private Endpoint access, zone name is `privatelink.mysql.database.azure.com`. For VNet-integrated (private access) servers, the zone name is `{name}.mysql.database.azure.com` (not `privatelink.*`). Referenced via `properties.network.privateDnsZoneResourceId`. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Virtual Network Links | `Microsoft.Network/privateDnsZones/virtualNetworkLinks` | Link DNS zone to a VNet for resolution |
| A Records | `Microsoft.Network/privateDnsZones/A` | IPv4 address records |
| AAAA Records | `Microsoft.Network/privateDnsZones/AAAA` | IPv6 address records |
| CNAME Records | `Microsoft.Network/privateDnsZones/CNAME` | Canonical name records |
| SOA Records | `Microsoft.Network/privateDnsZones/SOA` | Start of authority records |

## References

- [Bicep resource reference (2024-06-01)](https://learn.microsoft.com/azure/templates/microsoft.network/privatednszones?pivots=deployment-language-bicep)
- [Private DNS Zone overview](https://learn.microsoft.com/azure/dns/private-dns-overview)
- [Private endpoint DNS configuration](https://learn.microsoft.com/azure/private-link/private-endpoint-dns)
- [Azure naming rules — Network](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftnetwork)

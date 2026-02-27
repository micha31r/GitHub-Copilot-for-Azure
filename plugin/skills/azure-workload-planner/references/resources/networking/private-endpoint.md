# Private Endpoint

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Network/privateEndpoints` |
| Bicep API Version | `2024-07-01` |
| CAF Prefix | `pep` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

Private Endpoint does not use `kind`.

## SKU Names

Private Endpoint does not use a `sku` block.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 2 |
| Max Length | 64 |
| Allowed Characters | Alphanumerics, underscores, periods, hyphens. Must start with alphanumeric, end with alphanumeric or underscore. |
| Scope | Resource group |
| Pattern | `pep-{target-resource}-{env}-{instance}` |
| Example | `pep-stprod-prod-001` |

## Required Properties (Bicep)

```bicep
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  name: 'string'       // required
  location: 'string'   // required
  properties: {
    subnet: {
      id: 'string'     // required — resource ID of the subnet
    }
    privateLinkServiceConnections: [
      {
        name: 'string'                   // required
        properties: {
          privateLinkServiceId: 'string'  // required — resource ID of the target resource
          groupIds: [
            'string'                      // required — sub-resource group (e.g., 'blob', 'vault', 'sqlServer')
          ]
        }
      }
    ]
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `properties.subnet.id` | Subnet hosting the PE NIC | Resource ID of a subnet |
| `properties.privateLinkServiceConnections[].properties.privateLinkServiceId` | Target resource | Resource ID of the private-link-enabled resource |
| `properties.privateLinkServiceConnections[].properties.groupIds` | Sub-resource type | Array of strings (e.g., `['blob']`, `['vault']`, `['sqlServer']`, `['sites']`) |
| `properties.manualPrivateLinkServiceConnections` | Manual approval connections | Same structure as `privateLinkServiceConnections` (requires target owner approval) |
| `properties.customDnsConfigs` | Custom DNS records | Read-only — populated after creation |
| `properties.customNetworkInterfaceName` | Custom NIC name | String — name for the PE-managed NIC |
| `properties.ipConfigurations[].properties.privateIPAddress` | Static private IP | IP address string (optional — dynamic by default) |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **Subnet** | The subnet must not have NSG rules that block private endpoint traffic. Subnet must have `privateEndpointNetworkPolicies` set to `Disabled` (default) for network policies to be bypassed. |
| **Private DNS Zone** | Create a `Microsoft.Network/privateDnsZones/virtualNetworkLinks` to link the DNS zone to the VNet. Create an A record or use a private DNS zone group to auto-register DNS. |
| **Private DNS Zone Group** | Use `privateEndpoint/privateDnsZoneGroups` child resource to auto-register DNS records in the Private DNS Zone. |
| **Key Vault** | Group ID: `vault`. DNS zone: `privatelink.vaultcore.azure.net`. |
| **Storage Account** | Group IDs: `blob`, `file`, `queue`, `table`, `web`, `dfs`. Each requires its own PE and DNS zone. |
| **SQL Server** | Group ID: `sqlServer`. DNS zone: `privatelink.database.windows.net`. |
| **Container Registry** | Group ID: `registry`. DNS zone: `privatelink.azurecr.io`. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Private DNS Zone Groups | `Microsoft.Network/privateEndpoints/privateDnsZoneGroups` | Auto-register DNS records in Private DNS Zones |

## References

- [Bicep resource reference (2024-07-01)](https://learn.microsoft.com/azure/templates/microsoft.network/privateendpoints?pivots=deployment-language-bicep)
- [Private Endpoint overview](https://learn.microsoft.com/azure/private-link/private-endpoint-overview)
- [Azure naming rules — Network](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftnetwork)
- [Private DNS zone values](https://learn.microsoft.com/azure/private-link/private-endpoint-dns)

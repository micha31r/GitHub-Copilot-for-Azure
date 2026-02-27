# Subnet

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Network/virtualNetworks/subnets` |
| Bicep API Version | `2024-07-01` |
| CAF Prefix | `snet` |
| Parent Resource | `Microsoft.Network/virtualNetworks` (see [virtual-network.md](virtual-network.md)) |

## Region Availability

**Category:** Foundational — child resource; follows parent Virtual Network availability.

## Subtypes (kind)

Subnet does not use `kind` or `sku`.

## SKU Names

Subnet does not use a `sku` block.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 80 |
| Allowed Characters | Alphanumerics, underscores, periods, hyphens. Must start with alphanumeric, end with alphanumeric or underscore. |
| Scope | Parent virtual network |
| Pattern | `snet-{purpose}-{instance}` |
| Example | `snet-app-001` |

### Mandatory Subnet Names

Certain Azure services require exact subnet names:

| Service | Required Subnet Name | Minimum Prefix |
|---------|----------------------|----------------|
| Azure Firewall | `AzureFirewallSubnet` | /26 |
| Azure Firewall Management | `AzureFirewallManagementSubnet` | /26 |
| Azure Bastion | `AzureBastionSubnet` | /26 |
| VPN Gateway | `GatewaySubnet` | /27 |
| Route Server | `RouteServerSubnet` | /27 |

## Required Properties (Bicep)

```bicep
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = {
  name: 'string'       // required
  parent: vnet          // required — reference to VNet
  properties: {
    addressPrefix: 'string'  // required — e.g., '10.0.1.0/24'
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `properties.addressPrefix` | CIDR block for the subnet | CIDR string |
| `properties.networkSecurityGroup.id` | Associated NSG | Resource ID |
| `properties.routeTable.id` | Associated route table | Resource ID |
| `properties.serviceEndpoints[].service` | Service endpoints | `Microsoft.Storage`, `Microsoft.Sql`, `Microsoft.KeyVault`, `Microsoft.AzureCosmosDB`, etc. |
| `properties.delegations[].properties.serviceName` | Subnet delegation | Service name string (e.g., `Microsoft.Web/serverFarms`) |
| `properties.privateEndpointNetworkPolicies` | Private endpoint policies | `Disabled`, `Enabled`, `NetworkSecurityGroupEnabled`, `RouteTableEnabled` |
| `properties.privateLinkServiceNetworkPolicies` | Private link policies | `Disabled`, `Enabled` |
| `properties.natGateway.id` | NAT Gateway association | Resource ID |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **NSG** | Cannot attach NSG to `GatewaySubnet`. NSG on `AzureBastionSubnet` requires specific required rules. |
| **Delegations** | A subnet can only be delegated to one service. Delegated subnets cannot host other resource types. |
| **Service Endpoints** | Must match the service being accessed (e.g., `Microsoft.Sql` for SQL Server VNet rules). |
| **Private Endpoints** | Set `privateEndpointNetworkPolicies: 'Enabled'` to apply NSG/route table to private endpoints (default is `Disabled`). |
| **AKS** | AKS subnet needs enough IPs for all nodes + pods. Cannot be delegated or have conflicting service endpoints. |
| **Application Gateway** | Dedicated subnet required — cannot coexist with other resources except other App Gateways. |
| **Azure Firewall** | Subnet must be named `AzureFirewallSubnet`, minimum /26. Cannot have other resources. |

## Child Resources

Subnet has no child resource types.

## References

- [Bicep resource reference (2024-07-01)](https://learn.microsoft.com/azure/templates/microsoft.network/virtualnetworks/subnets?pivots=deployment-language-bicep)
- [Virtual Network subnets](https://learn.microsoft.com/azure/virtual-network/virtual-network-manage-subnet)
- [Azure naming rules — Network](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftnetwork)
- [Subnet delegation](https://learn.microsoft.com/azure/virtual-network/subnet-delegation-overview)

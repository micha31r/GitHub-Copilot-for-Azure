# Network Security Group

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Network/networkSecurityGroups` |
| Bicep API Version | `2025-05-01` |
| CAF Prefix | `nsg` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

NSG does not use `kind` or `sku`.

## SKU Names

NSG does not use a `sku` block.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 80 |
| Allowed Characters | Alphanumerics, underscores, periods, hyphens. Must start with alphanumeric, end with alphanumeric or underscore. |
| Scope | Resource group |
| Pattern | `nsg-{workload}-{env}-{instance}` |
| Example | `nsg-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource nsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'string'       // required
  location: 'string'   // required
  properties: {
    securityRules: [    // optional — can also use child resources
      {
        name: 'string'           // required
        properties: {
          priority: int          // required — 100–4096, unique per direction
          direction: 'string'    // required
          access: 'string'       // required
          protocol: 'string'     // required
          sourceAddressPrefix: 'string'       // required (or sourceAddressPrefixes)
          destinationAddressPrefix: 'string'  // required (or destinationAddressPrefixes)
          sourcePortRange: 'string'           // required (or sourcePortRanges)
          destinationPortRange: 'string'      // required (or destinationPortRanges)
        }
      }
    ]
  }
}
```

## Key Properties

### Security Rule Enums

| Property | Values |
|----------|--------|
| `access` | `Allow`, `Deny` |
| `direction` | `Inbound`, `Outbound` |
| `protocol` | `*`, `Ah`, `Esp`, `Icmp`, `Tcp`, `Udp` |

### Rule Properties

| Property | Description | Values |
|----------|-------------|--------|
| `priority` | Rule evaluation order (lower = first) | `100` to `4096` |
| `sourceAddressPrefix` | Source CIDR or tag | CIDR, `*`, `Internet`, `VirtualNetwork`, `AzureLoadBalancer` |
| `destinationAddressPrefix` | Destination CIDR or tag | CIDR, `*`, `Internet`, `VirtualNetwork` |
| `sourcePortRange` | Source port range | `*`, single port, or range `80-443` |
| `destinationPortRange` | Destination port range | `*`, single port, or range `80-443` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **GatewaySubnet** | Cannot attach NSG to `GatewaySubnet`. |
| **AzureBastionSubnet** | NSG on Bastion subnet requires specific inbound/outbound rules (see [Azure Bastion NSG](https://learn.microsoft.com/azure/bastion/bastion-nsg)). |
| **Application Gateway** | NSG on App Gateway subnet must allow `GatewayManager` service tag on ports `65200–65535` (v2) and health probe traffic. |
| **Load Balancer** | Must allow `AzureLoadBalancer` service tag for health probes. |
| **Virtual Network** | NSG is associated to subnets, not directly to VNets. Each subnet can have at most one NSG. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Security Rules | `Microsoft.Network/networkSecurityGroups/securityRules` | Individual security rules (alternative to inline) |

## References

- [Bicep resource reference (2025-05-01)](https://learn.microsoft.com/azure/templates/microsoft.network/networksecuritygroups?pivots=deployment-language-bicep)
- [NSG overview](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [Azure naming rules — Network](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftnetwork)
- [NSG security rules](https://learn.microsoft.com/azure/virtual-network/network-security-group-how-it-works)

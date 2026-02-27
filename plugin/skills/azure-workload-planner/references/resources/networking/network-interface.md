# Network Interface

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.Network/networkInterfaces` |
| Bicep API Version | `2025-05-01` |
| CAF Prefix | `nic` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

Network Interface does not use `kind`.

## SKU Names

Network Interface does not use a `sku` block.

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 1 |
| Max Length | 80 |
| Allowed Characters | Alphanumerics, underscores, periods, hyphens. Must start with alphanumeric, end with alphanumeric or underscore. |
| Scope | Resource group |
| Pattern | `nic-{vm-name}-{instance}` |
| Example | `nic-vm-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource nic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: 'string'       // required
  location: 'string'   // required
  properties: {
    ipConfigurations: [
      {
        name: 'string'           // required
        properties: {
          subnet: {
            id: 'string'         // required — resource ID of the subnet
          }
          privateIPAllocationMethod: 'string'  // required — 'Dynamic' or 'Static'
        }
      }
    ]
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `properties.ipConfigurations[].properties.subnet.id` | Subnet reference | Resource ID |
| `properties.ipConfigurations[].properties.privateIPAllocationMethod` | IP allocation | `Dynamic`, `Static` |
| `properties.ipConfigurations[].properties.privateIPAddress` | Static private IP | IP address string (required when allocation is `Static`) |
| `properties.ipConfigurations[].properties.publicIPAddress.id` | Public IP reference | Resource ID |
| `properties.ipConfigurations[].properties.primary` | Primary IP config | `true`, `false` |
| `properties.enableAcceleratedNetworking` | SR-IOV acceleration | `true`, `false` |
| `properties.enableIPForwarding` | IP forwarding (for NVAs) | `true`, `false` |
| `properties.networkSecurityGroup.id` | NSG association | Resource ID |
| `properties.dnsSettings.dnsServers` | Custom DNS servers | Array of IP strings |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|

| **Virtual Machine** | Each VM requires at least one NIC. NIC must be in the same region and subscription as the VM. |
| **Subnet** | NIC must reference a subnet. The subnet determines the VNet, NSG, and route table that apply. |
| **NSG** | NSG can be associated at the NIC level or at the subnet level (or both). NIC-level NSG is evaluated after subnet-level NSG. |
| **Public IP** | Public IP and NIC must be in the same region. Public IP SKU must match — Standard NIC requires Standard Public IP. |
| **Load Balancer** | NIC IP configuration can reference `loadBalancerBackendAddressPools` and `loadBalancerInboundNatRules`. Load balancer and NIC must be in the same VNet. |
| **Accelerated Networking** | Not all VM sizes support accelerated networking. Must verify VM size compatibility. |
| **VM Scale Set** | NICs for VMSS instances are managed by the scale set — do not create standalone NICs for VMSS. |
| **Application Gateway** | NIC IP configuration can reference `applicationGatewayBackendAddressPools`. |

## Child Resources

Network Interface has no significant Bicep child resources — IP configurations are inline.

## References

- [Bicep resource reference (2025-05-01)](https://learn.microsoft.com/azure/templates/microsoft.network/networkinterfaces?pivots=deployment-language-bicep)
- [Network interfaces overview](https://learn.microsoft.com/azure/virtual-network/virtual-network-network-interface)
- [Azure naming rules — Network](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftnetwork)
- [Accelerated networking](https://learn.microsoft.com/azure/virtual-network/accelerated-networking-overview)

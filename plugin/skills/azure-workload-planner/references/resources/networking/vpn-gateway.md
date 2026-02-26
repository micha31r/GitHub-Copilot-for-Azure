# VPN Gateway

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.Network/virtualNetworkGateways` |
| Bicep API Version | `2025-05-01` |
| CAF Prefix | `vpng` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

VPN Gateway does not use `kind`. The gateway type is set via `properties.gatewayType`.

### Gateway Types

| Gateway Type | Description |
|--------------|-------------|

| `Vpn` | VPN gateway (site-to-site, point-to-site, VNet-to-VNet) |
| `ExpressRoute` | ExpressRoute gateway |
| `LocalGateway` | Local network gateway |

### VPN Types (for `gatewayType: 'Vpn'`)

| VPN Type | Description |
|----------|-------------|

| `RouteBased` | Route-based VPN — **recommended**, required for most scenarios |
| `PolicyBased` | Policy-based VPN — limited to 1 S2S tunnel, IKEv1 only |

## SKU Names

| SKU Name | Gateway Type | Max S2S Tunnels | Max P2S Connections | Throughput |
|----------|--------------|-----------------|---------------------|------------|

| `Basic` | Vpn | 10 | 128 | 100 Mbps |
| `VpnGw1` | Vpn | 30 | 250 | 650 Mbps |
| `VpnGw1AZ` | Vpn | 30 | 250 | 650 Mbps (zone-redundant) |
| `VpnGw2` | Vpn | 30 | 500 | 1 Gbps |
| `VpnGw2AZ` | Vpn | 30 | 500 | 1 Gbps (zone-redundant) |
| `VpnGw3` | Vpn | 30 | 1000 | 1.25 Gbps |
| `VpnGw3AZ` | Vpn | 30 | 1000 | 1.25 Gbps (zone-redundant) |
| `VpnGw4` | Vpn | 100 | 5000 | 5 Gbps |
| `VpnGw4AZ` | Vpn | 100 | 5000 | 5 Gbps (zone-redundant) |
| `VpnGw5` | Vpn | 100 | 10000 | 10 Gbps |
| `VpnGw5AZ` | Vpn | 100 | 10000 | 10 Gbps (zone-redundant) |
| `ErGw1AZ` | ExpressRoute | N/A | N/A | 1 Gbps |
| `ErGw2AZ` | ExpressRoute | N/A | N/A | 2 Gbps |
| `ErGw3AZ` | ExpressRoute | N/A | N/A | 10 Gbps |
| `ErGwScale` | ExpressRoute | N/A | N/A | Scalable |
| `Standard` | ExpressRoute | N/A | N/A | 1 Gbps (legacy) |
| `HighPerformance` | ExpressRoute | N/A | N/A | 2 Gbps (legacy) |
| `UltraPerformance` | ExpressRoute | N/A | N/A | 10 Gbps (legacy) |

> **Note:** `sku.tier` must match `sku.name` (same values).

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 1 |
| Max Length | 80 |
| Allowed Characters | Alphanumerics, underscores, periods, hyphens. Must start with alphanumeric, end with alphanumeric or underscore. |
| Scope | Resource group |
| Pattern | `vpng-{workload}-{env}-{instance}` |
| Example | `vpng-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource vpnGw 'Microsoft.Network/virtualNetworkGateways@2025-05-01' = {
  name: 'string'       // required
  location: 'string'   // required
  properties: {
    gatewayType: 'string'  // required — 'Vpn' or 'ExpressRoute'
    vpnType: 'string'      // required for Vpn — 'RouteBased' or 'PolicyBased'
    sku: {
      name: 'string'       // required — see SKU Names
      tier: 'string'       // required — must match sku.name
    }
    ipConfigurations: [
      {
        name: 'string'     // required
        properties: {
          subnet: { id: 'string' }          // required — must be GatewaySubnet
          publicIPAddress: { id: 'string' } // required
        }
      }
    ]
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `properties.gatewayType` | Gateway type | `Vpn`, `ExpressRoute`, `LocalGateway` |
| `properties.vpnType` | VPN type | `RouteBased`, `PolicyBased` |
| `properties.vpnGatewayGeneration` | Hardware generation | `Generation1`, `Generation2`, `None` |
| `properties.enableBgp` | Enable BGP | `true`, `false` |
| `properties.activeActive` | Active-active mode | `true`, `false` (requires 2 public IPs) |
| `properties.vpnClientConfiguration` | Point-to-site config | Object with `vpnClientAddressPool`, `vpnClientProtocols`, `vpnAuthenticationTypes` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|

| **VNet** | Requires a subnet named exactly `GatewaySubnet` with minimum /27 prefix. |
| **Public IP** | Basic VPN SKU requires Basic public IP. VpnGw1+ requires Standard public IP. |
| **Active-Active** | Requires 2 public IPs and 2 IP configurations. Only supported with VpnGw1+. |
| **Zone-Redundant** | Must use `AZ` SKU variant (e.g., `VpnGw1AZ`). Requires Standard SKU public IPs. |
| **ExpressRoute** | Cannot coexist with VPN gateway on the same `GatewaySubnet` — use separate subnets or VPN+ER coexistence configurations. |
| **PolicyBased** | Limited to 1 S2S tunnel, no P2S, no VNet-to-VNet. Use `RouteBased` for most scenarios. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|

| NAT Rules | `Microsoft.Network/virtualNetworkGateways/natRules` | NAT rule definitions |

## References

- [Bicep resource reference (2025-05-01)](https://learn.microsoft.com/azure/templates/microsoft.network/virtualnetworkgateways?pivots=deployment-language-bicep)
- [VPN Gateway overview](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpngateways)
- [Azure naming rules — Network](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftnetwork)
- [VPN Gateway SKUs](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsku)

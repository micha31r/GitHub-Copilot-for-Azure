# NAT Gateway

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Network/natGateways` |
| Bicep API Version | `2025-05-01` |
| CAF Prefix | `ng` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

NAT Gateway does not use `kind`.

## SKU Names

| SKU Name | Description |
|----------|-------------|
| `Standard` | Standard NAT Gateway — production workloads |

> **Note:** Only `Standard` SKU is available. Basic SKU does not exist for NAT Gateway.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 80 |
| Allowed Characters | Alphanumerics, underscores, periods, hyphens. Must start with alphanumeric, end with alphanumeric or underscore. |
| Scope | Resource group |
| Pattern | `ng-{workload}-{env}-{instance}` |
| Example | `ng-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource natGateway 'Microsoft.Network/natGateways@2025-05-01' = {
  name: 'string'       // required
  location: 'string'   // required
  sku: {
    name: 'Standard'   // required — only valid value
  }
  properties: {
    publicIpAddresses: [
      {
        id: 'string'   // recommended — resource ID of a Standard SKU Public IP
      }
    ]
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `sku.name` | SKU tier | `Standard` |
| `properties.idleTimeoutInMinutes` | Idle timeout | `4` to `120` (default: `4`) |
| `properties.publicIpAddresses` | Public IP associations | Array of `{ id: 'resourceId' }` |
| `properties.publicIpPrefixes` | Public IP prefix associations | Array of `{ id: 'resourceId' }` |
| `zones` | Availability zones | Array of strings (e.g., `['1']`, `['2']`, `['3']`) |

> **Note:** NAT Gateway supports up to 16 public IP addresses and/or public IP prefixes combined, providing up to 64,000 SNAT ports per IP.

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **Subnet** | NAT Gateway is associated on the subnet side: set `subnet.properties.natGateway.id` to the NAT Gateway resource ID. A subnet can have at most one NAT Gateway. |
| **Public IP** | Public IP must use `Standard` SKU and `Static` allocation. Public IP and NAT Gateway must be in the same region. |
| **Public IP Prefix** | Public IP prefix must use `Standard` SKU. Provides contiguous outbound IPs. |
| **Availability Zones** | NAT Gateway can be zonal (pinned to one zone) or non-zonal. Public IPs must match the same zone or be zone-redundant. |
| **Load Balancer** | NAT Gateway takes precedence over outbound rules of a Standard Load Balancer when both are on the same subnet. |
| **VPN Gateway / ExpressRoute** | `GatewaySubnet` does not support NAT Gateway association. |
| **Azure Firewall** | NAT Gateway can be associated with the `AzureFirewallSubnet` for deterministic outbound IPs in SNAT scenarios. |

## Child Resources

NAT Gateway has no Bicep child resources.

## References

- [Bicep resource reference (2025-05-01)](https://learn.microsoft.com/azure/templates/microsoft.network/natgateways?pivots=deployment-language-bicep)
- [NAT Gateway overview](https://learn.microsoft.com/azure/nat-gateway/nat-overview)
- [Azure naming rules — Network](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftnetwork)
- [NAT Gateway and availability zones](https://learn.microsoft.com/azure/nat-gateway/nat-availability-zones)

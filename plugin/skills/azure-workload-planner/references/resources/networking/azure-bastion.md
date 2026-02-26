# Azure Bastion

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Network/bastionHosts` |
| Bicep API Version | `2025-05-01` |
| CAF Prefix | `bas` |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions.

> Verify at plan time: `microsoft_docs_fetch` → `https://learn.microsoft.com/azure/reliability/availability-service-by-category`

## Subtypes (kind)

Azure Bastion does not use `kind`.

## SKU Names

| SKU Name | Description |
|----------|-------------|
| `Developer` | Dev/test only — single VM, no scaling, limited features |
| `Basic` | Basic — RDP/SSH, 2 instances, manual |
| `Standard` | Standard — Basic + host scaling, native client, IP-based, file transfer |
| `Premium` | Premium — Standard + session recording, private-only |

> **Note:** SKU upgrade path: Developer → Basic → Standard → Premium. Downgrade is not supported.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 80 |
| Allowed Characters | Alphanumerics, underscores, periods, hyphens. Must start with alphanumeric, end with alphanumeric or underscore. |
| Scope | Resource group |
| Pattern | `bas-{workload}-{env}-{instance}` |
| Example | `bas-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource bastion 'Microsoft.Network/bastionHosts@2025-05-01' = {
  name: 'string'       // required
  location: 'string'   // required
  sku: {
    name: 'string'     // required — 'Developer', 'Basic', 'Standard', or 'Premium'
  }
  properties: {
    ipConfigurations: [           // required (except Developer SKU)
      {
        name: 'string'           // required
        properties: {
          subnet: {
            id: 'string'         // required — must be AzureBastionSubnet
          }
          publicIPAddress: {
            id: 'string'         // required
          }
        }
      }
    ]
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `sku.name` | SKU tier | `Developer`, `Basic`, `Standard`, `Premium` |
| `properties.scaleUnits` | Instance count (Standard/Premium) | `2` to `50` (default: `2`) |
| `properties.enableTunneling` | Native client support | `true`, `false` (Standard/Premium only) |
| `properties.enableIpConnect` | IP-based connection | `true`, `false` (Standard/Premium only) |
| `properties.enableFileCopy` | File transfer | `true`, `false` (Standard/Premium only) |
| `properties.enableShareableLink` | Shareable links | `true`, `false` (Standard/Premium only) |
| `properties.disableCopyPaste` | Disable clipboard | `true`, `false` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **VNet** | Requires a subnet named exactly `AzureBastionSubnet` with minimum /26 prefix. |
| **Developer SKU** | Does NOT require `AzureBastionSubnet` or public IP. Deploys as shared infrastructure. Only connects to VMs in the same VNet. |
| **Public IP** | Requires Standard SKU public IP with Static allocation. |
| **NSG** | NSG on `AzureBastionSubnet` requires mandatory inbound (HTTPS 443 from Internet, GatewayManager 443) and outbound rules (see [Bastion NSG docs](https://learn.microsoft.com/azure/bastion/bastion-nsg)). |
| **VMs** | Target VMs must be in the same VNet as Bastion (or peered VNets with Standard/Premium SKU). |

## Child Resources

Azure Bastion has no child resource types.

## References

- [Bicep resource reference (2025-05-01)](https://learn.microsoft.com/azure/templates/microsoft.network/bastionhosts?pivots=deployment-language-bicep)
- [Azure Bastion overview](https://learn.microsoft.com/azure/bastion/bastion-overview)
- [Azure naming rules — Network](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftnetwork)
- [Bastion configuration settings](https://learn.microsoft.com/azure/bastion/configuration-settings)

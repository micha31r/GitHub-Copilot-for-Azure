# Application Gateway

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Network/applicationGateways` |
| Bicep API Version | `2024-07-01` |
| CAF Prefix | `agw` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

Application Gateway does not use `kind`.

## SKU Names

| SKU Name | SKU Tier | Description |
|----------|----------|-------------|
| `Standard_v2` | `Standard_v2` | Standard v2 — **recommended**, zone-aware, autoscaling |
| `WAF_v2` | `WAF_v2` | WAF v2 — Standard_v2 + Web Application Firewall |
| `Basic` | `Basic` | Basic App Gateway (limited scenarios) |
| `Standard_Small` | `Standard` | v1 Small (legacy) |
| `Standard_Medium` | `Standard` | v1 Medium (legacy) |
| `Standard_Large` | `Standard` | v1 Large (legacy) |
| `WAF_Medium` | `WAF` | v1 WAF Medium (legacy) |
| `WAF_Large` | `WAF` | v1 WAF Large (legacy) |

### SKU Families (v2 only)

| Family | Description |
|--------|-------------|
| `Generation_1` | Gen1 hardware |
| `Generation_2` | Gen2 hardware |

> **Note:** v1 SKUs are being retired April 2026. Always use `Standard_v2` or `WAF_v2` for new deployments.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 80 |
| Allowed Characters | Alphanumerics, underscores, periods, hyphens. Must start with alphanumeric, end with alphanumeric or underscore. |
| Scope | Resource group |
| Pattern | `agw-{workload}-{env}-{instance}` |
| Example | `agw-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource appGw 'Microsoft.Network/applicationGateways@2024-07-01' = {
  name: 'string'       // required
  location: 'string'   // required
  properties: {
    sku: {
      name: 'string'    // required — see SKU Names
      tier: 'string'    // required — must match SKU name pattern
      capacity: int     // required for v1; optional for v2 with autoscale
    }
    gatewayIPConfigurations: [
      {
        name: 'string'
        properties: {
          subnet: { id: 'string' }  // required — dedicated subnet
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'string'
        properties: {
          publicIPAddress: { id: 'string' }  // for public frontend
        }
      }
    ]
    frontendPorts: [
      {
        name: 'string'
        properties: { port: int }
      }
    ]
    backendAddressPools: [
      {
        name: 'string'
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'string'
        properties: {
          port: int
          protocol: 'string'  // 'Http' or 'Https'
        }
      }
    ]
    httpListeners: [
      {
        name: 'string'
        properties: {
          frontendIPConfiguration: { id: 'string' }
          frontendPort: { id: 'string' }
          protocol: 'string'  // 'Http' or 'Https'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'string'
        properties: {
          ruleType: 'string'  // 'Basic' or 'PathBasedRouting'
          priority: int
          httpListener: { id: 'string' }
          backendAddressPool: { id: 'string' }
          backendHttpSettings: { id: 'string' }
        }
      }
    ]
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `properties.sku.name` | SKU name | See SKU Names table |
| `properties.sku.tier` | SKU tier | Must match SKU name |
| `properties.autoscaleConfiguration.minCapacity` | Min instances (v2) | Integer (`0` to `125`) |
| `properties.autoscaleConfiguration.maxCapacity` | Max instances (v2) | Integer (`2` to `125`) |
| `properties.webApplicationFirewallConfiguration.enabled` | Enable WAF | `true`, `false` (WAF SKUs only) |
| `properties.webApplicationFirewallConfiguration.firewallMode` | WAF mode | `Detection`, `Prevention` |
| `properties.sslCertificates[].properties.data` | SSL cert (base64 PFX) | Base64 string |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **Subnet** | Requires a dedicated subnet — no other resources allowed in the subnet (except other App Gateways). |
| **Public IP** | v2 SKU requires Standard SKU public IP with Static allocation. |
| **NSG** | NSG on App Gateway subnet must allow `GatewayManager` service tag on ports `65200–65535` (v2) or `65503–65534` (v1). |
| **WAF** | WAF configuration only available with `WAF_v2` or `WAF_Large`/`WAF_Medium` SKUs. |
| **Zones** | v2 supports availability zones. Specify `zones: ['1','2','3']` for zone-redundant deployment. |
| **Key Vault** | For SSL certificates, use `sslCertificates[].properties.keyVaultSecretId` to reference Key Vault certificates. User-assigned managed identity required. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Private Endpoint Connections | `Microsoft.Network/applicationGateways/privateEndpointConnections` | Private link connections |

## References

- [Bicep resource reference (2024-07-01)](https://learn.microsoft.com/azure/templates/microsoft.network/applicationgateways?pivots=deployment-language-bicep)
- [Application Gateway overview](https://learn.microsoft.com/azure/application-gateway/overview)
- [Azure naming rules — Network](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftnetwork)
- [App Gateway v2 features](https://learn.microsoft.com/azure/application-gateway/application-gateway-autoscaling-zone-redundant)

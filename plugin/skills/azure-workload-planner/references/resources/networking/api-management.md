# API Management

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.ApiManagement/service` |
| Bicep API Version | `2024-05-01` |
| CAF Prefix | `apim` |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions.

> Verify at plan time: `microsoft_docs_fetch` → `https://learn.microsoft.com/azure/reliability/availability-service-by-category`

## Subtypes (kind)

API Management does not use `kind`.

## SKU Names

Exact `sku` values for Bicep — both `name` and `capacity` are required:

| SKU Name | Description | VNet Support |
|----------|-------------|--------------|

| `Consumption` | Serverless, pay-per-call, no capacity setting | None |
| `Developer` | Development/test, no SLA | External, Internal |
| `Basic` | Entry-level production | None |
| `BasicV2` | Basic with new platform features | VNet integration |
| `Standard` | Medium-traffic production | None |
| `StandardV2` | Standard with new platform features | VNet integration |
| `Premium` | Enterprise, multi-region, VNet | External, Internal |
| `PremiumV2` | Premium with new platform features | VNet integration |
| `Isolated` | Fully isolated (single-tenant) | Internal |

> **Note:** `capacity` is required for all SKUs except `Consumption`. It represents the number of scale units.

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 1 |
| Max Length | 50 |
| Allowed Characters | Alphanumerics and hyphens. Must start with a letter, end with alphanumeric. |
| Scope | Global (must be globally unique as DNS name `{name}.azure-api.net`) |
| Pattern | `apim-{workload}-{env}-{instance}` |
| Example | `apim-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  sku: {
    name: 'string'     // required — see SKU Names table
    capacity: int      // required (except Consumption, set to 0)
  }
  properties: {
    publisherEmail: 'string'  // required
    publisherName: 'string'   // required
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `sku.name` | Pricing tier | `Consumption`, `Developer`, `Basic`, `BasicV2`, `Standard`, `StandardV2`, `Premium`, `PremiumV2`, `Isolated` |
| `sku.capacity` | Scale units | Integer (`0` for Consumption, `1`+ for others) |
| `properties.publisherEmail` | Publisher email | Email string (required) |
| `properties.publisherName` | Publisher name | String (required) |
| `properties.virtualNetworkType` | VNet integration mode | `None`, `External`, `Internal` |
| `properties.virtualNetworkConfiguration.subnetResourceId` | VNet subnet | Resource ID |
| `properties.customProperties` | Custom settings | Object (e.g., `{ 'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false' }`) |
| `properties.publicNetworkAccess` | Public access | `Enabled`, `Disabled` |
| `properties.certificates` | Gateway certificates | Array of certificate configurations |
| `properties.hostnameConfigurations` | Custom domains | Array of hostname/certificate pairs |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|

| **VNet (External)** | Only available with `Developer`, `Premium`, or `Isolated` SKU. Subnet must be dedicated with an NSG allowing APIM management traffic. |
| **VNet (Internal)** | Same as External but no public gateway endpoint. Requires Private DNS or custom DNS for resolution. |
| **Application Gateway** | Common pattern: App Gateway in front of Internal-mode APIM. App Gateway uses the APIM private IP as backend. |
| **Key Vault** | Named values and certificates can reference Key Vault secrets. Requires managed identity with `Key Vault Secrets User` role. |
| **Application Insights** | Set `properties.customProperties` with `Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2` and logger resource for diagnostics. |
| **NSG (VNet mode)** | Subnet NSG must allow: inbound on ports 3443 (management), 80/443 (client); outbound to Azure Storage, SQL, Event Hub, and other dependencies. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|

| APIs | `Microsoft.ApiManagement/service/apis` | API definitions |
| Products | `Microsoft.ApiManagement/service/products` | API product groupings |
| Subscriptions | `Microsoft.ApiManagement/service/subscriptions` | API access subscriptions |
| Named Values | `Microsoft.ApiManagement/service/namedValues` | Configuration properties |
| Loggers | `Microsoft.ApiManagement/service/loggers` | Application Insights / Event Hub loggers |
| Backends | `Microsoft.ApiManagement/service/backends` | Backend service definitions |
| Policies | `Microsoft.ApiManagement/service/policies` | Global API policies |

## References

- [Bicep resource reference (2024-05-01)](https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service?pivots=deployment-language-bicep)
- [API Management overview](https://learn.microsoft.com/azure/api-management/api-management-key-concepts)
- [Azure naming rules — ApiManagement](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftapimanagement)
- [VNet integration](https://learn.microsoft.com/azure/api-management/virtual-network-concepts)

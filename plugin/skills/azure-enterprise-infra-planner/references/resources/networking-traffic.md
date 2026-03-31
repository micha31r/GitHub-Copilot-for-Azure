# Networking (Traffic) Resources

| Resource | ARM Type | API Version | CAF Prefix | Naming Scope | Region |
|----------|----------|-------------|------------|--------------|--------|
| API Management | `Microsoft.ApiManagement/service` | `2024-05-01` | `apim` | Global | Mainstream |
| Application Gateway | `Microsoft.Network/applicationGateways` | `2024-07-01` | `agw` | Resource group | Foundational |
| Front Door | `Microsoft.Cdn/profiles` | `2025-06-01` | `afd` | Resource group | Foundational |
| Load Balancer | `Microsoft.Network/loadBalancers` | `2024-07-01` | `lbi`/`lbe` | Resource group | Foundational |

## Documentation

| Resource | Bicep Reference | Service Overview | Additional |
|----------|----------------|------------------|------------|
| API Management | [2024-05-01](https://learn.microsoft.com/azure/templates/microsoft.apimanagement/service?pivots=deployment-language-bicep) | [APIM overview](https://learn.microsoft.com/azure/api-management/api-management-key-concepts) | [VNet integration](https://learn.microsoft.com/azure/api-management/virtual-network-concepts) |
| Application Gateway | [2024-07-01](https://learn.microsoft.com/azure/templates/microsoft.network/applicationgateways?pivots=deployment-language-bicep) | [App Gateway overview](https://learn.microsoft.com/azure/application-gateway/overview) | [v2 features](https://learn.microsoft.com/azure/application-gateway/application-gateway-autoscaling-zone-redundant) |
| Front Door | [2025-06-01](https://learn.microsoft.com/azure/templates/microsoft.cdn/profiles?pivots=deployment-language-bicep) | [Front Door overview](https://learn.microsoft.com/azure/frontdoor/front-door-overview) | [Routing architecture](https://learn.microsoft.com/azure/frontdoor/front-door-routing-architecture) |
| Load Balancer | [2024-07-01](https://learn.microsoft.com/azure/templates/microsoft.network/loadbalancers?pivots=deployment-language-bicep) | [LB overview](https://learn.microsoft.com/azure/load-balancer/load-balancer-overview) | [Standard LB](https://learn.microsoft.com/azure/load-balancer/load-balancer-standard-overview) |

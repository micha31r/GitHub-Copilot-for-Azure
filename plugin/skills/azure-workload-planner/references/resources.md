# Resource Reference Index

Quick-lookup table mapping Azure resource types to their reference files. Each file contains verified Bicep types, subtypes, SKUs, naming rules, required properties, pairing constraints, and source URLs.

## Resource Files

### Compute

| Resource | ARM Type | File | CAF Prefix | Naming Scope | Region Category |
|----------|----------|------|------------|--------------|-----------------|
| App Service | `Microsoft.Web/sites` | [app-service.md](resources/compute/app-service.md) | `app` | Global | Mainstream |
| App Service Plan | `Microsoft.Web/serverfarms` | [app-service-plan.md](resources/compute/app-service-plan.md) | `asp` | Resource group | Mainstream |
| Function App | `Microsoft.Web/sites` | [function-app.md](resources/compute/function-app.md) | `func` | Global | Mainstream |
| Container App | `Microsoft.App/containerApps` | [container-app.md](resources/compute/container-app.md) | `ca` | Environment | Strategic |
| AKS Cluster | `Microsoft.ContainerService/managedClusters` | [aks-cluster.md](resources/compute/aks-cluster.md) | `aks` | Resource group | Foundational |
| Virtual Machine | `Microsoft.Compute/virtualMachines` | [virtual-machine.md](resources/compute/virtual-machine.md) | `vm` | Resource group | Foundational |
| VM Scale Set | `Microsoft.Compute/virtualMachineScaleSets` | [vm-scale-set.md](resources/compute/vm-scale-set.md) | `vmss` | Resource group | Foundational |
| Managed Disk | `Microsoft.Compute/disks` | [managed-disk.md](resources/compute/managed-disk.md) | `osdisk`/`disk` | Resource group | Foundational |
| Availability Set | `Microsoft.Compute/availabilitySets` | [availability-set.md](resources/compute/availability-set.md) | `avail` | Resource group | Foundational |
| Container Registry | `Microsoft.ContainerRegistry/registries` | [container-registry.md](resources/compute/container-registry.md) | `cr` | Global | Mainstream |

### Data

| Resource | ARM Type | File | CAF Prefix | Naming Scope | Region Category |
|----------|----------|------|------------|--------------|-----------------|
| Storage Account | `Microsoft.Storage/storageAccounts` | [storage-account.md](resources/data/storage-account.md) | `st` | Global | Foundational |
| Cosmos DB | `Microsoft.DocumentDB/databaseAccounts` | [cosmos-db.md](resources/data/cosmos-db.md) | `cosmos` | Global | Foundational |
| SQL Server | `Microsoft.Sql/servers` | [sql-server.md](resources/data/sql-server.md) | `sql` | Global | Foundational |
| SQL Database | `Microsoft.Sql/servers/databases` | [sql-database.md](resources/data/sql-database.md) | `sqldb` | Parent server | Foundational |
| Redis Cache | `Microsoft.Cache/redis` | [redis-cache.md](resources/data/redis-cache.md) | `redis` | Global | Mainstream |
| Data Factory | `Microsoft.DataFactory/factories` | [data-factory.md](resources/data/data-factory.md) | `adf` | Global | Mainstream |
| Synapse Workspace | `Microsoft.Synapse/workspaces` | [synapse-workspace.md](resources/data/synapse-workspace.md) | `synw` | Global | Strategic |

### Networking

| Resource | ARM Type | File | CAF Prefix | Naming Scope | Region Category |
|----------|----------|------|------------|--------------|-----------------|
| Virtual Network | `Microsoft.Network/virtualNetworks` | [virtual-network.md](resources/networking/virtual-network.md) | `vnet` | Resource group | Foundational |
| Subnet | `Microsoft.Network/virtualNetworks/subnets` | [subnet.md](resources/networking/subnet.md) | `snet` | Parent VNet | Foundational |
| NSG | `Microsoft.Network/networkSecurityGroups` | [nsg.md](resources/networking/nsg.md) | `nsg` | Resource group | Foundational |
| Public IP | `Microsoft.Network/publicIPAddresses` | [public-ip.md](resources/networking/public-ip.md) | `pip` | Resource group | Foundational |
| Load Balancer | `Microsoft.Network/loadBalancers` | [load-balancer.md](resources/networking/load-balancer.md) | `lbi`/`lbe` | Resource group | Foundational |
| Application Gateway | `Microsoft.Network/applicationGateways` | [application-gateway.md](resources/networking/application-gateway.md) | `agw` | Resource group | Foundational |
| VPN Gateway | `Microsoft.Network/virtualNetworkGateways` | [vpn-gateway.md](resources/networking/vpn-gateway.md) | `vpng` | Resource group | Foundational |
| Azure Firewall | `Microsoft.Network/azureFirewalls` | [azure-firewall.md](resources/networking/azure-firewall.md) | `afw` | Resource group | Mainstream |
| Azure Bastion | `Microsoft.Network/bastionHosts` | [azure-bastion.md](resources/networking/azure-bastion.md) | `bas` | Resource group | Mainstream |

### Messaging

| Resource | ARM Type | File | CAF Prefix | Naming Scope | Region Category |
|----------|----------|------|------------|--------------|-----------------|
| Service Bus | `Microsoft.ServiceBus/namespaces` | [service-bus.md](resources/messaging/service-bus.md) | `sbns` | Global | Foundational |
| Event Hub | `Microsoft.EventHub/namespaces` | [event-hub.md](resources/messaging/event-hub.md) | `evhns` | Global | Foundational |

### Observability

| Resource | ARM Type | File | CAF Prefix | Naming Scope | Region Category |
|----------|----------|------|------------|--------------|-----------------|
| Log Analytics | `Microsoft.OperationalInsights/workspaces` | [log-analytics.md](resources/observability/log-analytics.md) | `log` | Resource group | Mainstream |
| App Insights | `Microsoft.Insights/components` | [app-insights.md](resources/observability/app-insights.md) | `appi` | Resource group | Mainstream |

### AI & Machine Learning

| Resource | ARM Type | File | CAF Prefix | Naming Scope | Region Category |
|----------|----------|------|------------|--------------|-----------------|
| ML Workspace | `Microsoft.MachineLearningServices/workspaces` | [ml-workspace.md](resources/ai/ml-workspace.md) | `mlw`/`hub`/`proj` | Resource group | Mainstream |
| Cognitive Services | `Microsoft.CognitiveServices/accounts` | [cognitive-services.md](resources/ai/cognitive-services.md) | varies by kind | Resource group | Mainstream |
| AI Search | `Microsoft.Search/searchServices` | [search-service.md](resources/ai/search-service.md) | `srch` | Global | Mainstream |

### Security

| Resource | ARM Type | File | CAF Prefix | Naming Scope | Region Category |
|----------|----------|------|------------|--------------|-----------------|
| Key Vault | `Microsoft.KeyVault/vaults` | [key-vault.md](resources/security/key-vault.md) | `kv` | Global | Foundational |

## Region Categories

Categories from [Available services by region types and categories](https://learn.microsoft.com/azure/reliability/availability-service-by-category):

| Category | Region Availability |
|----------|---------------------|
| **Foundational** | Available in all recommended and alternate regions — no verification needed |
| **Mainstream** | Available in all recommended regions; demand-driven in alternate regions — verify if targeting alternate region |
| **Strategic** | Demand-driven across regions — always verify before planning |

> Only Mainstream and Strategic resources require region verification. Fetch via `microsoft_docs_fetch` → `https://learn.microsoft.com/azure/reliability/availability-service-by-category`

## Usage

During Phase 2 (Plan Generation), for each resource being added to the plan:

1. Look up the resource type in this index
2. Load the corresponding `.md` file
3. Use the file's **Identity** section for ARM type and API version
4. Use **Subtypes** and **SKU Names** to select valid `kind` and `sku` values
5. Use **Naming** to generate a compliant name
6. Use **Required Properties** as the Bicep template skeleton
7. Use **Pairing Constraints** to validate against already-planned resources
8. Run verification checks from [verification.md](verification.md)

## Globally-Unique Names

These resources require globally unique names (DNS-based):

| Resource | DNS Pattern |
|----------|-------------|
| Storage Account | `{name}.blob.core.windows.net` |
| Key Vault | `{name}.vault.azure.net` |
| Cosmos DB | `{name}.documents.azure.com` |
| SQL Server | `{name}.database.windows.net` |
| Function App | `{name}.azurewebsites.net` |
| App Service | `{name}.azurewebsites.net` |
| Redis Cache | `{name}.redis.cache.windows.net` |
| Service Bus | `{name}.servicebus.windows.net` |
| Event Hub | `{name}.servicebus.windows.net` |
| Data Factory | `{name}.adf.azure.com` |
| Synapse Workspace | `{name}.dev.azuresynapse.net` |
| Container Registry | `{name}.azurecr.io` |
| AI Search | `{name}.search.windows.net` |

## Shared ARM Types

Some resource types share the same ARM type and are distinguished by `kind`:

| ARM Type | `kind` Value | Resource |
|----------|--------------|----------|
| `Microsoft.Web/sites` | `app` / `app,linux` | App Service |
| `Microsoft.Web/sites` | `functionapp` / `functionapp,linux` | Function App |
| `Microsoft.MachineLearningServices/workspaces` | _(omitted)_ / `Default` | ML Workspace |
| `Microsoft.MachineLearningServices/workspaces` | `Hub` | AI Foundry Hub |
| `Microsoft.MachineLearningServices/workspaces` | `Project` | AI Foundry Project |
| `Microsoft.MachineLearningServices/workspaces` | `FeatureStore` | Feature Store |

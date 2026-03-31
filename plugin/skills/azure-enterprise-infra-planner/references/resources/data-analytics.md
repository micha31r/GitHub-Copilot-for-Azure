# Data (Analytics) Resources

| Resource | ARM Type | API Version | CAF Prefix | Naming Scope | Region |
|----------|----------|-------------|------------|--------------|--------|
| Cosmos DB | `Microsoft.DocumentDB/databaseAccounts` | `2025-04-15` | `cosmos` | Global | Foundational |
| Data Factory | `Microsoft.DataFactory/factories` | `2018-06-01` | `adf` | Global | Mainstream |
| Redis Cache | `Microsoft.Cache/redis` | `2024-11-01` | `redis` | Global | Mainstream |
| Storage Account | `Microsoft.Storage/storageAccounts` | `2025-01-01` | `st` | Global | Foundational |
| Synapse Workspace | `Microsoft.Synapse/workspaces` | `2021-06-01` | `synw` | Global | Strategic |

## Documentation

| Resource | Bicep Reference | Service Overview | Additional |
|----------|----------------|------------------|------------|
| Cosmos DB | [2025-04-15](https://learn.microsoft.com/azure/templates/microsoft.documentdb/databaseaccounts?pivots=deployment-language-bicep) | [Cosmos DB overview](https://learn.microsoft.com/azure/cosmos-db/introduction) | [Consistency levels](https://learn.microsoft.com/azure/cosmos-db/consistency-levels) |
| Data Factory | [2018-06-01](https://learn.microsoft.com/azure/templates/microsoft.datafactory/factories?pivots=deployment-language-bicep) | [ADF overview](https://learn.microsoft.com/azure/data-factory/introduction) | [ADF naming rules](https://learn.microsoft.com/azure/data-factory/naming-rules) |
| Redis Cache | [2024-11-01](https://learn.microsoft.com/azure/templates/microsoft.cache/redis?pivots=deployment-language-bicep) | [Redis overview](https://learn.microsoft.com/azure/azure-cache-for-redis/cache-overview) | [Service tiers](https://learn.microsoft.com/azure/azure-cache-for-redis/cache-overview#service-tiers) |
| Storage Account | [2025-01-01](https://learn.microsoft.com/azure/templates/microsoft.storage/storageaccounts?pivots=deployment-language-bicep) | [Storage overview](https://learn.microsoft.com/azure/storage/common/storage-account-overview) | [Storage redundancy](https://learn.microsoft.com/azure/storage/common/storage-redundancy) |
| Synapse Workspace | [2021-06-01](https://learn.microsoft.com/azure/templates/microsoft.synapse/workspaces?pivots=deployment-language-bicep) | [Synapse overview](https://learn.microsoft.com/azure/synapse-analytics/overview-what-is) | [All API versions](https://learn.microsoft.com/azure/templates/microsoft.synapse/allversions) |

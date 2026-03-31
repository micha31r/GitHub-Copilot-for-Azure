# AI & ML Resources

| Resource | ARM Type | API Version | CAF Prefix | Naming Scope | Region |
|----------|----------|-------------|------------|--------------|--------|
| Cognitive Services | `Microsoft.CognitiveServices/accounts` | `2025-06-01` | varies by kind | Resource group | Mainstream |
| ML Workspace | `Microsoft.MachineLearningServices/workspaces` | `2025-06-01` | `mlw`/`hub`/`proj` | Resource group | Mainstream |
| AI Search | `Microsoft.Search/searchServices` | `2025-05-01` | `srch` | Global | Mainstream |

## Documentation

| Resource | Bicep Reference | Service Overview | Additional |
|----------|----------------|------------------|------------|
| Cognitive Services | [2025-06-01](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/accounts?pivots=deployment-language-bicep) | [Custom subdomain names](https://learn.microsoft.com/azure/ai-services/cognitive-services-custom-subdomains) | [All API versions](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/allversions) |
| ML Workspace | [2025-06-01](https://learn.microsoft.com/azure/templates/microsoft.machinelearningservices/workspaces?pivots=deployment-language-bicep) | [ML Services](https://learn.microsoft.com/azure/templates/microsoft.machinelearningservices/allversions) | [All API versions](https://learn.microsoft.com/azure/templates/microsoft.machinelearningservices/allversions) |
| AI Search | [2025-05-01](https://learn.microsoft.com/azure/templates/microsoft.search/searchservices?pivots=deployment-language-bicep) | [Service limits](https://learn.microsoft.com/azure/search/search-limits-quotas-capacity) | [All API versions](https://learn.microsoft.com/azure/templates/microsoft.search/allversions) |

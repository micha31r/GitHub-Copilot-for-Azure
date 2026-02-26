# Azure Data Factory

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.DataFactory/factories` |
| Bicep API Version | `2018-06-01` |
| CAF Prefix | `adf` |

## Region Availability

**Category:** Mainstream — available in all recommended regions within 90 days of GA. Demand-driven in alternate regions.

## Subtypes (kind)

Does not use `kind`. Azure Data Factory has no `kind` property — there is only one factory type.

## SKU Names

Does not use `sku`. Azure Data Factory does not have SKU tiers — pricing is based on pipeline activity runs, data movement, and integration runtime hours.

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 3 |
| Max Length | 63 |
| Allowed Characters | Alphanumerics and hyphens. Must start and end with alphanumeric. Every dash must be preceded and followed by a letter or number. No consecutive dashes. |
| Pattern (ARM) | `^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$` |
| Scope | Global (unique across all of Azure, case-insensitive) |
| Pattern (CAF) | `adf-{workload}-{env}-{region}-{instance}` |
| Example | `adf-etl-prod-eastus2-001` |

## Required Properties (Bicep)

```bicep
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  properties: {}        // required (can be empty object)
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `properties.publicNetworkAccess` | Allow public network access | `'Enabled'`, `'Disabled'` |
| `properties.repoConfiguration.type` | Git repo type | `'FactoryGitHubConfiguration'`, `'FactoryVSTSConfiguration'` |
| `properties.repoConfiguration.accountName` | Git account name | string (required when repo configured) |
| `properties.repoConfiguration.repositoryName` | Git repo name | string (required when repo configured) |
| `properties.repoConfiguration.collaborationBranch` | Collaboration branch | string (required when repo configured) |
| `properties.repoConfiguration.rootFolder` | Root folder in repo | string (required when repo configured) |
| `properties.encryption.keyName` | CMK key name | string (required for CMK) |
| `properties.encryption.vaultBaseUrl` | Key Vault URL for CMK | string (required for CMK) |
| `properties.globalParameters.{name}.type` | Global parameter type | `'Array'`, `'Bool'`, `'Float'`, `'Int'`, `'Object'`, `'String'` |
| `properties.purviewConfiguration.purviewResourceId` | Purview resource ID | string |
| `identity.type` | Managed identity type | `'SystemAssigned'`, `'SystemAssigned,UserAssigned'`, `'UserAssigned'` |

## Pairing Constraints

| Paired With | Constraint |
|-------------|------------|

| **Storage Account** | Linked service requires `Storage Blob Data Contributor` role on the storage account for the ADF managed identity. For ADLS Gen2, also requires `Storage Blob Data Reader` at minimum. |
| **Key Vault** | For CMK encryption, Key Vault must have `softDeleteEnabled: true` and `enablePurgeProtection: true`. ADF managed identity needs `Key Vault Crypto Service Encryption User` role or equivalent access policy. |
| **Managed VNet** | When `managedVirtualNetworks` is configured, all outbound connections must use managed private endpoints (`factories/managedVirtualNetworks/managedPrivateEndpoints`). |
| **Private Endpoint** | When `publicNetworkAccess: 'Disabled'`, must create private endpoint to `dataFactory` sub-resource for studio access and pipeline connectivity. |
| **Purview** | Requires Microsoft Purview instance resource ID. ADF managed identity must have `Data Curator` role in Purview. |
| **Integration Runtime** | Self-hosted IR requires network line-of-sight to on-premises sources. Azure IR regional choice affects data residency. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|

| Change Data Capture | `Microsoft.DataFactory/factories/adfcdcs` | CDC configurations |
| Credentials | `Microsoft.DataFactory/factories/credentials` | Managed identity credentials |
| Data Flows | `Microsoft.DataFactory/factories/dataflows` | Mapping data flows |
| Datasets | `Microsoft.DataFactory/factories/datasets` | Dataset definitions |
| Global Parameters | `Microsoft.DataFactory/factories/globalParameters` | Factory-scoped parameters |
| Integration Runtimes | `Microsoft.DataFactory/factories/integrationRuntimes` | Azure, self-hosted, or SSIS runtimes |
| Linked Services | `Microsoft.DataFactory/factories/linkedservices` | Connection definitions |
| Managed VNets | `Microsoft.DataFactory/factories/managedVirtualNetworks` | Managed virtual networks |
| Managed Private Endpoints | `Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints` | Private endpoints within managed VNet |
| Pipelines | `Microsoft.DataFactory/factories/pipelines` | Data pipeline definitions |
| Private Endpoint Connections | `Microsoft.DataFactory/factories/privateEndpointConnections` | Inbound private endpoint connections |
| Triggers | `Microsoft.DataFactory/factories/triggers` | Schedule/event triggers |

## References

- [Bicep resource reference (2018-06-01)](https://learn.microsoft.com/azure/templates/microsoft.datafactory/factories?pivots=deployment-language-bicep)
- [Azure Data Factory overview](https://learn.microsoft.com/azure/data-factory/introduction)
- [Azure naming rules — DataFactory](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftdatafactory)
- [ADF naming rules](https://learn.microsoft.com/azure/data-factory/naming-rules)
- [All DataFactory resource types](https://learn.microsoft.com/azure/templates/microsoft.datafactory/allversions)

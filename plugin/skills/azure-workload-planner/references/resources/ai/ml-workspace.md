# Machine Learning Workspace

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.MachineLearningServices/workspaces` |
| Bicep API Version | `2025-06-01` |
| CAF Prefix | `mlw` (Default workspace), `hub` (Foundry Hub), `proj` (Foundry Project) |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions.

## Subtypes (kind)

The `kind` property is typed as `string` in the schema (not a strict enum). Known values from CAF and Microsoft Learn:

| Kind | Description | CAF Prefix |
|------|-------------|------------|
| *(omitted / Default)* | Standard ML workspace | `mlw` |
| `Hub` | Azure AI Foundry hub — central governance, shared resources | `hub` |
| `Project` | Azure AI Foundry project — child of a Hub, scoped work area | `proj` |
| `FeatureStore` | Feature store workspace for ML feature management | `mlw` |

> **Note:** When `kind` is `Project`, you **must** set `properties.hubResourceId` to the parent Hub's ARM resource ID.

## SKU Names

Exact `sku.name` values for Bicep (string). The `sku.tier` enum values are: `Basic`, `Free`, `Premium`, `Standard`.

| SKU Name | Tier | Notes |
|----------|------|-------|
| `Basic` | `Basic` | Default for standard ML workspaces |
| `Standard` | `Standard` | Used for Hub/Project workspaces |
| `Free` | `Free` | Limited-feature tier |
| `Premium` | `Premium` | Advanced features |

> **Guidance:** Most ML workspaces use `Basic`/`Basic`. Hub and Project workspaces typically use `Basic`/`Basic` as well. `Free` and `Premium` appear in the ARM schema enum but are not distinct ML pricing tiers — use `Basic` or `Standard` for production.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 3 |
| Max Length | 33 |
| Allowed Characters | Alphanumerics, hyphens, underscores |
| Pattern (regex) | `^[a-zA-Z0-9][a-zA-Z0-9_-]{2,32}$` |
| Scope | Resource group |
| Example | `mlw-datascience-prod-001` |

> Must start with an alphanumeric character. Hyphens and underscores allowed after the first character.

## Required Properties (Bicep)

```bicep
resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2025-06-01' = {
  name: 'string'         // required, 3-33 chars
  location: 'string'     // required
  identity: {
    type: 'string'       // required — 'SystemAssigned' | 'UserAssigned' | 'SystemAssigned,UserAssigned' | 'None'
  }
  sku: {
    name: 'string'       // required — see SKU Names table
    tier: 'string'       // optional — see SKU Names table
  }
  kind: 'string'         // optional — see Subtypes table
  properties: {
    storageAccount: 'string'        // ARM resource ID — required for Default/Hub
    keyVault: 'string'              // ARM resource ID — required for Default/Hub
    applicationInsights: 'string'   // ARM resource ID — recommended
    containerRegistry: 'string'     // ARM resource ID — optional
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `identity.type` | Managed identity type | `None`, `SystemAssigned`, `UserAssigned`, `SystemAssigned,UserAssigned` |
| `properties.storageAccount` | Linked Storage Account resource ID | ARM resource ID (cannot change after creation) |
| `properties.keyVault` | Linked Key Vault resource ID | ARM resource ID (cannot change after creation) |
| `properties.applicationInsights` | Linked App Insights resource ID | ARM resource ID |
| `properties.containerRegistry` | Linked ACR resource ID | ARM resource ID |
| `properties.hubResourceId` | Parent Hub resource ID (kind=Project only) | ARM resource ID |
| `properties.workspaceHubConfig` | Hub-specific configuration (kind=Hub only) | Object |
| `properties.publicNetworkAccess` | Public network access | `Enabled`, `Disabled` |
| `properties.managedNetwork.isolationMode` | Network isolation mode | `AllowInternetOutbound`, `AllowOnlyApprovedOutbound`, `Disabled` |
| `properties.hbiWorkspace` | High business impact flag | `true`, `false` |
| `properties.systemDatastoresAuthMode` | Datastore auth mode | `AccessKey`, `Identity`, `UserDelegationSAS` |
| `properties.featureStoreSettings` | Feature store config (kind=FeatureStore) | Object |

## Pairing Constraints

| Paired With | Constraint |
|-------------|------------|
| **Storage Account** | Must be linked via `properties.storageAccount`. Cannot change after creation. Use `StorageV2` kind with standard SKU. |
| **Key Vault** | Must be linked via `properties.keyVault`. Cannot change after creation. Requires soft-delete enabled. |
| **Application Insights** | Linked via `properties.applicationInsights`. Should use workspace-based App Insights (backed by Log Analytics). |
| **Container Registry** | Optional but recommended for custom environments. Linked via `properties.containerRegistry`. |
| **Hub workspace (kind=Project)** | Must set `properties.hubResourceId` to the parent Hub's ARM resource ID. The Project inherits the Hub's linked resources. |
| **VNet Integration** | When `managedNetwork.isolationMode` is `AllowOnlyApprovedOutbound`, must configure outbound rules for all dependent services. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Computes | `Microsoft.MachineLearningServices/workspaces/computes` | Compute targets (clusters, instances) |
| Connections | `Microsoft.MachineLearningServices/workspaces/connections` | Service connections (Azure OpenAI, etc.) |
| Datastores | `Microsoft.MachineLearningServices/workspaces/datastores` | Data source references |
| Endpoints | `Microsoft.MachineLearningServices/workspaces/endpoints` | Inference endpoints |
| Online Endpoints | `Microsoft.MachineLearningServices/workspaces/onlineEndpoints` | Real-time inference endpoints |
| Batch Endpoints | `Microsoft.MachineLearningServices/workspaces/batchEndpoints` | Batch inference endpoints |
| Serverless Endpoints | `Microsoft.MachineLearningServices/workspaces/serverlessEndpoints` | Serverless model endpoints |
| Outbound Rules | `Microsoft.MachineLearningServices/workspaces/outboundRules` | Managed network rules |
| Schedules | `Microsoft.MachineLearningServices/workspaces/schedules` | Pipeline/job schedules |
| Private Endpoint Connections | `Microsoft.MachineLearningServices/workspaces/privateEndpointConnections` | Private networking |

## References

- [Bicep resource reference (2025-06-01)](https://learn.microsoft.com/azure/templates/microsoft.machinelearningservices/workspaces?pivots=deployment-language-bicep)
- [All API versions](https://learn.microsoft.com/azure/templates/microsoft.machinelearningservices/allversions)
- [Azure naming rules — ML Services](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftmachinelearningservices)
- [CAF abbreviations](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)

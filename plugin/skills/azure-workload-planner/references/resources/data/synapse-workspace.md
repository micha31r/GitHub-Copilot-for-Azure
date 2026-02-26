# Azure Synapse Workspace

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Synapse/workspaces` |
| Bicep API Version | `2021-06-01` |
| CAF Prefix | `synw` |

## Region Availability

**Category:** Strategic — demand-driven availability across regions. Always verify target region supports Azure Synapse Analytics before planning.

## Subtypes (kind)

Does not use `kind`. Azure Synapse Workspace has no `kind` property — there is only one workspace type.

## SKU Names

Does not use `sku`. The workspace resource itself has no SKU. Compute costs are determined by child resources:

- **SQL Pools** (`workspaces/sqlPools`) — have DWU-based SKUs (e.g., `DW100c` through `DW30000c`)
- **Spark Pools** (`workspaces/bigDataPools`) — priced by node size and count

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 50 |
| Allowed Characters | Lowercase letters, numbers, and hyphens. Must start and end with a letter or number. Cannot contain `-ondemand`. |
| Scope | Global (must be globally unique) |
| Pattern (CAF) | `synw-{workload}-{env}-{region}-{instance}` |
| Example | `synw-analytics-prod-eastus2-001` |

## Required Properties (Bicep)

```bicep
resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  properties: {
    defaultDataLakeStorage: {
      accountUrl: 'string'   // required — ADLS Gen2 DFS endpoint (e.g., https://{account}.dfs.core.windows.net)
      filesystem: 'string'   // required — ADLS Gen2 container/filesystem name
    }
    sqlAdministratorLogin: 'string'            // required
    sqlAdministratorLoginPassword: 'string'    // required
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `properties.defaultDataLakeStorage.accountUrl` | ADLS Gen2 account DFS URL | string (required) |
| `properties.defaultDataLakeStorage.filesystem` | ADLS Gen2 filesystem/container | string (required) |
| `properties.defaultDataLakeStorage.resourceId` | ARM resource ID of storage account | string |
| `properties.defaultDataLakeStorage.createManagedPrivateEndpoint` | Auto-create managed PE to storage | `true`, `false` |
| `properties.sqlAdministratorLogin` | SQL admin username | string (required) |
| `properties.sqlAdministratorLoginPassword` | SQL admin password | string (required, secure) |
| `properties.publicNetworkAccess` | Public network access | `'Enabled'`, `'Disabled'` |
| `properties.managedVirtualNetwork` | Enable managed VNet | `'default'` (enabled) or `''` (disabled) |
| `properties.managedVirtualNetworkSettings.preventDataExfiltration` | Block data exfiltration | `true`, `false` |
| `properties.managedVirtualNetworkSettings.allowedAadTenantIdsForLinking` | Allowed tenant IDs for linking | string[] |
| `properties.azureADOnlyAuthentication` | Entra ID-only auth | `true`, `false` |
| `properties.trustedServiceBypassEnabled` | Allow trusted Azure services | `true`, `false` |
| `properties.encryption.cmk.key.name` | CMK key name | string |
| `properties.encryption.cmk.key.keyVaultUrl` | Key Vault key URL | string |
| `properties.purviewConfiguration.purviewResourceId` | Purview resource ID | string |
| `properties.managedResourceGroupName` | Name for managed RG | string (max 90 chars) |
| `properties.virtualNetworkProfile.computeSubnetId` | Subnet for compute | string (ARM resource ID) |
| `identity.type` | Managed identity type | `'None'`, `'SystemAssigned'`, `'SystemAssigned,UserAssigned'` |

## Pairing Constraints

| Paired With | Constraint |
|-------------|------------|
| **ADLS Gen2 Storage Account** | **Required.** Storage account must have `isHnsEnabled: true` (hierarchical namespace / Data Lake Storage Gen2) and `kind: 'StorageV2'`. Synapse managed identity needs `Storage Blob Data Contributor` role on the storage account. |
| **Key Vault** | For CMK encryption, Key Vault must have `softDeleteEnabled: true` and `enablePurgeProtection: true`. Synapse managed identity needs `Get`, `Unwrap Key`, and `Wrap Key` permissions. |
| **Managed VNet** | When `managedVirtualNetwork: 'default'`, all outbound connections require managed private endpoints. Set at creation time — cannot be changed after. |
| **Private Endpoint** | When `publicNetworkAccess: 'Disabled'`, create private endpoints for sub-resources: `Dev` (Studio), `Sql` (dedicated SQL), `SqlOnDemand` (serverless SQL). |
| **Purview** | Requires Microsoft Purview resource ID. Synapse managed identity needs appropriate Purview roles. |
| **VNet (compute subnet)** | `virtualNetworkProfile.computeSubnetId` must reference an existing subnet. The subnet must be delegated to `Microsoft.Synapse/workspaces` if required by the deployment model. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Administrators | `Microsoft.Synapse/workspaces/administrators` | Workspace active directory admin |
| Auditing Settings | `Microsoft.Synapse/workspaces/auditingSettings` | SQL auditing configuration |
| Entra ID Only Auth | `Microsoft.Synapse/workspaces/azureADOnlyAuthentications` | Enforce Entra ID-only auth |
| Spark Pools | `Microsoft.Synapse/workspaces/bigDataPools` | Apache Spark pools |
| Dedicated SQL TLS | `Microsoft.Synapse/workspaces/dedicatedSQLminimalTlsSettings` | Minimum TLS version |
| Encryption Protector | `Microsoft.Synapse/workspaces/encryptionProtector` | CMK encryption protector |
| Extended Auditing | `Microsoft.Synapse/workspaces/extendedAuditingSettings` | Extended auditing settings |
| Firewall Rules | `Microsoft.Synapse/workspaces/firewallRules` | IP firewall rules |
| Integration Runtimes | `Microsoft.Synapse/workspaces/integrationRuntimes` | Integration runtimes |
| Keys | `Microsoft.Synapse/workspaces/keys` | Workspace encryption keys |
| Libraries | `Microsoft.Synapse/workspaces/libraries` | Spark pool libraries |
| Managed Identity SQL | `Microsoft.Synapse/workspaces/managedIdentitySqlControlSettings` | Managed identity SQL access |
| Private Endpoints | `Microsoft.Synapse/workspaces/privateEndpointConnections` | Private endpoint connections |
| Security Alerts | `Microsoft.Synapse/workspaces/securityAlertPolicies` | Security alert policies |
| SQL Administrators | `Microsoft.Synapse/workspaces/sqlAdministrators` | SQL admin configuration |
| SQL Pools | `Microsoft.Synapse/workspaces/sqlPools` | Dedicated SQL pools |
| Vulnerability Assessments | `Microsoft.Synapse/workspaces/vulnerabilityAssessments` | Vulnerability assessment settings |

## References

- [Bicep resource reference (2021-06-01)](https://learn.microsoft.com/azure/templates/microsoft.synapse/workspaces?pivots=deployment-language-bicep)
- [Azure Synapse Analytics overview](https://learn.microsoft.com/azure/synapse-analytics/overview-what-is)
- [Azure naming rules — Synapse](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftsynapse)
- [All Synapse resource types](https://learn.microsoft.com/azure/templates/microsoft.synapse/allversions)

# Key Vault

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.KeyVault/vaults` |
| Bicep API Version | `2025-05-01` |
| CAF Prefix | `kv` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

Key Vault does not use `kind`. All vaults share the same resource type.

## SKU Names

Exact `sku` values for Bicep — both `name` and `family` are required:

| SKU Name | SKU Family | Description |
|----------|------------|-------------|
| `standard` | `A` | Software-protected keys, secrets, and certificates |
| `premium` | `A` | Adds HSM-protected keys |

> **Note:** `sku.family` must always be `'A'` — it is the only accepted value.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 3 |
| Max Length | 24 |
| Allowed Characters | Alphanumerics and hyphens. Must start with a letter, end with a letter or digit. No consecutive hyphens. |
| Scope | Global (must be globally unique as DNS name) |
| Pattern | `kv-{workload}-{env}-{instance}` |
| Example | `kv-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource vault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  properties: {
    tenantId: 'string'  // required — Azure AD tenant ID
    sku: {
      family: 'A'       // required — only valid value
      name: 'string'    // required — 'standard' or 'premium'
    }
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `properties.enableSoftDelete` | Soft delete protection | `true` (default, cannot be disabled once enabled) |
| `properties.enablePurgeProtection` | Prevent purge during retention | `true`, `false` (cannot be disabled once enabled) |
| `properties.enableRbacAuthorization` | Use RBAC instead of access policies | `true`, `false` |
| `properties.softDeleteRetentionInDays` | Soft delete retention period | `7` to `90` (default: `90`) |
| `properties.enabledForDeployment` | Allow VMs to retrieve certificates | `true`, `false` |
| `properties.enabledForDiskEncryption` | Allow Azure Disk Encryption | `true`, `false` |
| `properties.enabledForTemplateDeployment` | Allow ARM to retrieve secrets | `true`, `false` |
| `properties.publicNetworkAccess` | Public network access | `Disabled`, `Enabled` |
| `properties.networkAcls.defaultAction` | Default network rule | `Allow`, `Deny` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **Storage Account (CMK)** | Must have `enableSoftDelete: true` AND `enablePurgeProtection: true`. |
| **Storage Account (CMK at creation)** | Storage must use user-assigned managed identity — system-assigned only works for existing accounts. |
| **SQL Server (TDE)** | Must enable `enablePurgeProtection`. Key Vault and SQL Server must be in the same Azure AD tenant. |
| **AKS (secrets)** | Use `enableRbacAuthorization: true` with Azure RBAC for secrets access. AKS needs `azureKeyvaultSecretsProvider` addon. |
| **Disk Encryption** | Must set `enabledForDiskEncryption: true`. Premium SKU required for HSM-protected keys. |
| **Private Endpoint** | Set `publicNetworkAccess: 'Disabled'` and `networkAcls.defaultAction: 'Deny'` when using private endpoints. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Secrets | `Microsoft.KeyVault/vaults/secrets` | Store secret values |
| Keys | `Microsoft.KeyVault/vaults/keys` | Cryptographic keys |
| Key Versions | `Microsoft.KeyVault/vaults/keys/versions` | Key version management |
| Access Policies | `Microsoft.KeyVault/vaults/accessPolicies` | Vault-level access (legacy; prefer RBAC) |
| Private Endpoints | `Microsoft.KeyVault/vaults/privateEndpointConnections` | Private link connections |

## References

- [Bicep resource reference (2025-05-01)](https://learn.microsoft.com/azure/templates/microsoft.keyvault/vaults?pivots=deployment-language-bicep)
- [Key Vault overview](https://learn.microsoft.com/azure/key-vault/general/overview)
- [Azure naming rules — Key Vault](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftkeyvault)
- [Key Vault soft-delete](https://learn.microsoft.com/azure/key-vault/general/soft-delete-overview)

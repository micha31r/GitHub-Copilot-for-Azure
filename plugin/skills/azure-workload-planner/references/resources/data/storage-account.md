# Storage Account

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Storage/storageAccounts` |
| Bicep API Version | `2025-01-01` |
| CAF Prefix | `st` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

These are the exact `kind` values accepted in Bicep. Using any other value causes deployment failure.

| Kind | Description | Access Tier Support |
|------|-------------|---------------------|
| `StorageV2` | General-purpose v2 — **recommended default** | Hot, Cool, Cold |
| `Storage` | General-purpose v1 (legacy) | N/A |
| `BlobStorage` | Blob-only (legacy, use StorageV2 instead) | Hot, Cool |
| `BlockBlobStorage` | Premium block blob | Premium (fixed) |
| `FileStorage` | Premium file shares only | Premium (fixed) |

## SKU Names

Exact `sku.name` values for Bicep:

| SKU | Redundancy | Compatible Kinds |
|-----|------------|------------------|
| `Standard_LRS` | Locally redundant | StorageV2, Storage, BlobStorage |
| `Standard_GRS` | Geo-redundant | StorageV2, Storage, BlobStorage |
| `Standard_RAGRS` | Read-access geo-redundant | StorageV2, Storage, BlobStorage |
| `Standard_ZRS` | Zone-redundant | StorageV2 |
| `Standard_GZRS` | Geo-zone-redundant | StorageV2 |
| `Standard_RAGZRS` | Read-access geo-zone-redundant | StorageV2 |
| `Premium_LRS` | Premium locally redundant | BlockBlobStorage, FileStorage |
| `Premium_ZRS` | Premium zone-redundant | BlockBlobStorage, FileStorage |
| `StandardV2_LRS` | Standard v2 locally redundant | StorageV2 |
| `StandardV2_ZRS` | Standard v2 zone-redundant | StorageV2 |
| `StandardV2_GRS` | Standard v2 geo-redundant | StorageV2 |
| `StandardV2_GZRS` | Standard v2 geo-zone-redundant | StorageV2 |
| `PremiumV2_LRS` | Premium v2 locally redundant | BlockBlobStorage |
| `PremiumV2_ZRS` | Premium v2 zone-redundant | BlockBlobStorage |

> **Note:** SKU cannot be changed to `Standard_ZRS`, `Premium_LRS`, or `Premium_ZRS` after creation.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 3 |
| Max Length | 24 |
| Allowed Characters | Lowercase letters and numbers only (no hyphens, no underscores) |
| Scope | Global (must be globally unique) |
| Pattern | `st{workload}{env}{instance}` (no separators) |
| Example | `stdatapipelineprod001` |

## Required Properties (Bicep)

```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: 'string'       // required, globally unique
  location: 'string'   // required
  kind: 'string'       // required — see Subtypes table
  sku: {
    name: 'string'     // required — see SKU Names table
  }
  properties: {
    accessTier: 'string'  // required when kind = 'BlobStorage'; optional otherwise
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `properties.accessTier` | Billing tier for blobs | `Hot`, `Cool`, `Cold`, `Premium` |
| `properties.allowBlobPublicAccess` | Allow anonymous blob access | `true`, `false` (default: `false`) |
| `properties.supportsHttpsTrafficOnly` | Require HTTPS | `true` (recommended), `false` |
| `properties.minimumTlsVersion` | Minimum TLS version | `TLS1_0`, `TLS1_1`, `TLS1_2` |
| `properties.networkAcls.defaultAction` | Network default action | `Allow`, `Deny` |
| `properties.encryption.keySource` | Encryption key source | `Microsoft.Storage`, `Microsoft.Keyvault` |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **Azure Functions** | Must use `StorageV2` or `Storage` kind. `BlobStorage`, `BlockBlobStorage`, `FileStorage` not supported (missing Queue/Table). |
| **Functions (Consumption plan)** | Cannot use network-secured storage (VNet rules). Only Premium/Dedicated plans support VNet-restricted storage. |
| **Functions (zone-redundant)** | Must use ZRS SKU (`Standard_ZRS`). LRS/GRS not sufficient. |
| **VM Boot Diagnostics** | Cannot use Premium storage or ZRS. Use `Standard_LRS` or `Standard_GRS`. Managed boot diagnostics (no storage account required) is also available. |
| **CMK Encryption** | Key Vault must have `softDeleteEnabled: true` AND `enablePurgeProtection: true`. |
| **CMK at creation** | Requires user-assigned managed identity (system-assigned only works for existing accounts). |
| **Geo-redundant failover** | Certain features (SFTP, NFS 3.0, etc.) block GRS/GZRS failover. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Blob Services | `Microsoft.Storage/storageAccounts/blobServices` | Configure blob-specific settings |
| Containers | `Microsoft.Storage/storageAccounts/blobServices/containers` | Blob containers |
| File Services | `Microsoft.Storage/storageAccounts/fileServices` | File share settings |
| File Shares | `Microsoft.Storage/storageAccounts/fileServices/shares` | SMB/NFS file shares |
| Queue Services | `Microsoft.Storage/storageAccounts/queueServices` | Queue settings |
| Queues | `Microsoft.Storage/storageAccounts/queueServices/queues` | Storage queues |
| Table Services | `Microsoft.Storage/storageAccounts/tableServices` | Table settings |
| Tables | `Microsoft.Storage/storageAccounts/tableServices/tables` | Storage tables |

## References

- [Bicep resource reference (2025-01-01)](https://learn.microsoft.com/azure/templates/microsoft.storage/storageaccounts?pivots=deployment-language-bicep)
- [Storage account overview](https://learn.microsoft.com/azure/storage/common/storage-account-overview)
- [Azure naming rules — Storage](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftstorage)
- [Storage redundancy](https://learn.microsoft.com/azure/storage/common/storage-redundancy)

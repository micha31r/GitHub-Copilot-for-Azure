// ---------------------------------------------------------------------------
// modules/security.bicep — Key Vault
// ---------------------------------------------------------------------------

@description('Azure region')
param location string

@description('Environment name')
param environmentName string

@description('Workload name')
param workloadName string

@description('Azure AD tenant ID')
param tenantId string

// ── Key Vault ───────────────────────────────────────────────────────────────

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: 'kv-${workloadName}-${environmentName}-001'
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultName string = keyVault.name

@description('Region.')
param location string

@description('Workload short name.')
param workloadName string

@description('Environment short code.')
param environment string

@description('Globally-unique suffix for Key Vault name.')
param uniqueSuffix string

@description('Resource tags.')
param tags object

var kvName = toLower('kv-${workloadName}-${environment}-${substring(uniqueSuffix, 0, 6)}')
var idName = 'id-vmworkload-${workloadName}-${environment}'

resource workloadIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: idName
  location: location
  tags: tags
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

output workloadIdentityId string = workloadIdentity.id
output workloadIdentityPrincipalId string = workloadIdentity.properties.principalId
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri

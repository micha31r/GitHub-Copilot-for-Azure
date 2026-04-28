@description('Azure region.')
param location string

@description('Common name prefix.')
param namePrefix string

@description('Common tags.')
param tags object

@description('Admin password for jumpbox; persisted as the initial Key Vault secret.')
@secure()
param jumpAdminPassword string

@description('Principal that should receive Key Vault Secrets Officer on the vault.')
param keyVaultAdminObjectId string

resource uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-vm-${namePrefix}'
  location: location
  tags: tags
}

resource kv 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: take('kv-${namePrefix}-${uniqueString(resourceGroup().id)}', 24)
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Built-in role IDs
var keyVaultSecretsUserRoleId      = '4633458b-17de-408a-b874-0445c86b69e6'
var keyVaultSecretsOfficerRoleId   = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'

resource kvSecretsUserToUai 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(kv.id, uai.id, keyVaultSecretsUserRoleId)
  properties: {
    principalId: uai.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
  }
}

resource kvSecretsOfficerToAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(keyVaultAdminObjectId)) {
  scope: kv
  name: guid(kv.id, keyVaultAdminObjectId, keyVaultSecretsOfficerRoleId)
  properties: {
    principalId: keyVaultAdminObjectId
    principalType: 'User'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsOfficerRoleId)
  }
}

resource jumpAdminSecret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: kv
  name: 'jumpAdminPassword'
  properties: {
    value: jumpAdminPassword
    attributes: {
      enabled: true
    }
  }
}

output userAssignedIdentityId string = uai.id
output userAssignedIdentityPrincipalId string = uai.properties.principalId
output keyVaultId string = kv.id
output keyVaultName string = kv.name

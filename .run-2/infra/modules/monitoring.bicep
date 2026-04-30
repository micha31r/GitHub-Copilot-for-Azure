@description('Region.')
param location string

@description('Workload short name.')
param workloadName string

@description('Environment short code.')
param environment string

@description('Globally-unique suffix for storage account name.')
param uniqueSuffix string

@description('Resource tags.')
param tags object

var stName = toLower('st${workloadName}${environment}${substring(uniqueSuffix, 0, 6)}')
var lawName = 'log-${workloadName}-${environment}-${location}'

resource law 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: lawName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
  }
}

resource diagStorage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: stName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    allowCrossTenantReplication: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

output workspaceId string = law.id
output workspaceName string = law.name
output diagnosticsStorageId string = diagStorage.id
output diagnosticsStorageName string = diagStorage.name
output diagnosticsStorageEndpoint string = diagStorage.properties.primaryEndpoints.blob

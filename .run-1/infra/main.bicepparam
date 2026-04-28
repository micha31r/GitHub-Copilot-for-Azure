using './main.bicep'

param location = 'westus2'
param resourceGroupName = 'rg-tiered-net-westus2'
param namePrefix = 'tiered'

// Replace before deploying.
param jumpAdminUsername = 'azjumpadmin'
param jumpAdminPassword = readEnvironmentVariable('JUMP_ADMIN_PASSWORD', '')
param adminSourceCidr = readEnvironmentVariable('ADMIN_SOURCE_CIDR', '0.0.0.0/32')
param keyVaultAdminObjectId = readEnvironmentVariable('KEYVAULT_ADMIN_OBJECT_ID', '')

param tags = {
  workload: 'tiered-network'
  managedBy: 'bicep'
  environment: 'shared'
}

targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'westus2'

@description('Resource group name.')
param resourceGroupName string = 'rg-tiered-net-westus2'

@description('Common name prefix used to derive resource names.')
param namePrefix string = 'tiered'

@description('Admin username for the jumpbox VM.')
param jumpAdminUsername string

@description('Admin password for the jumpbox VM. Stored in Key Vault as an initial secret.')
@secure()
param jumpAdminPassword string

@description('Source CIDR allowed to RDP/SSH to the jumpbox (e.g. 203.0.113.10/32).')
param adminSourceCidr string

@description('Object ID of the principal that should receive Key Vault Secrets Officer on the new vault (typically the deploying user).')
param keyVaultAdminObjectId string

@description('Common tags applied to every resource.')
param tags object = {
  workload: 'tiered-network'
  managedBy: 'bicep'
  environment: 'shared'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
  }
}

module security 'modules/security.bicep' = {
  name: 'security'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    jumpAdminPassword: jumpAdminPassword
    keyVaultAdminObjectId: keyVaultAdminObjectId
  }
}

module networking 'modules/networking.bicep' = {
  name: 'networking'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    adminSourceCidr: adminSourceCidr
  }
}

module compute 'modules/compute.bicep' = {
  name: 'compute'
  scope: rg
  params: {
    location: location
    namePrefix: namePrefix
    tags: tags
    jumpAdminUsername: jumpAdminUsername
    jumpAdminPassword: jumpAdminPassword
    mgmtSubnetId: networking.outputs.mgmtSubnetId
    webSubnetId: networking.outputs.webSubnetId
    appSubnetId: networking.outputs.appSubnetId
    dataSubnetId: networking.outputs.dataSubnetId
    appBackendPoolId: networking.outputs.appBackendPoolId
    jumpPublicIpId: networking.outputs.jumpPublicIpId
    userAssignedIdentityId: security.outputs.userAssignedIdentityId
  }
}

output resourceGroupName string = rg.name
output vnetId string = networking.outputs.vnetId
output internalLoadBalancerFrontendIp string = networking.outputs.appLbFrontendPrivateIp
output jumpboxPublicIp string = networking.outputs.jumpPublicIpAddress
output keyVaultName string = security.outputs.keyVaultName

targetScope = 'subscription'

@description('Azure region for all resources.')
param location string = 'eastus2'

@description('Workload short name used in resource naming.')
param workloadName string = '3tier'

@description('Environment short code.')
@allowed([ 'dev', 'test', 'prod' ])
param environment string = 'prod'

@description('Resource group name.')
param resourceGroupName string = 'rg-${workloadName}-${environment}-${location}'

@description('Tags applied to every resource.')
param tags object = {
  workload: workloadName
  env: environment
  owner: 'platform'
}

@description('Admin username for Linux VMs.')
param adminUsername string = 'azureuser'

@description('SSH public key for Linux VMs (string). In production source from Key Vault.')
@secure()
param adminSshPublicKey string

@description('VNet address space.')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Web/app/db VMSS instance count.')
param vmssInstanceCount int = 2

@description('VMSS SKU for web and app tiers.')
param webAppVmSize string = 'Standard_D2s_v5'

@description('VMSS SKU for db tier.')
param dbVmSize string = 'Standard_D4s_v5'

@description('Jumpbox VM SKU.')
param jumpVmSize string = 'Standard_B2s'

@description('Suffix used for globally-unique resource names (Storage, Key Vault).')
param uniqueSuffix string = uniqueString(subscription().id, workloadName, environment)

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
    workloadName: workloadName
    environment: environment
    uniqueSuffix: uniqueSuffix
    tags: tags
  }
}

module security 'modules/security.bicep' = {
  name: 'security'
  scope: rg
  params: {
    location: location
    workloadName: workloadName
    environment: environment
    uniqueSuffix: uniqueSuffix
    tags: tags
  }
}

module networking 'modules/networking.bicep' = {
  name: 'networking'
  scope: rg
  params: {
    location: location
    workloadName: workloadName
    environment: environment
    vnetAddressPrefix: vnetAddressPrefix
    tags: tags
  }
}

module traffic 'modules/traffic.bicep' = {
  name: 'traffic'
  scope: rg
  params: {
    location: location
    workloadName: workloadName
    environment: environment
    tags: tags
    appGwSubnetId: networking.outputs.appGwSubnetId
    appSubnetId: networking.outputs.appSubnetId
    dbSubnetId: networking.outputs.dbSubnetId
  }
}

module compute 'modules/compute.bicep' = {
  name: 'compute'
  scope: rg
  params: {
    location: location
    tags: tags
    adminUsername: adminUsername
    adminSshPublicKey: adminSshPublicKey
    vmssInstanceCount: vmssInstanceCount
    webAppVmSize: webAppVmSize
    dbVmSize: dbVmSize
    jumpVmSize: jumpVmSize
    webSubnetId: networking.outputs.webSubnetId
    appSubnetId: networking.outputs.appSubnetId
    dbSubnetId: networking.outputs.dbSubnetId
    jumpSubnetId: networking.outputs.jumpSubnetId
    webNsgId: networking.outputs.webNsgId
    appNsgId: networking.outputs.appNsgId
    dbNsgId: networking.outputs.dbNsgId
    jumpNsgId: networking.outputs.jumpNsgId
    appGwBackendPoolId: traffic.outputs.appGwBackendPoolId
    lbiAppBackendPoolId: traffic.outputs.lbiAppBackendPoolId
    lbiDbBackendPoolId: traffic.outputs.lbiDbBackendPoolId
    workloadIdentityId: security.outputs.workloadIdentityId
    diagnosticsStorageEndpoint: monitoring.outputs.diagnosticsStorageEndpoint
  }
}

module privateDns 'modules/privatedns.bicep' = {
  name: 'privatedns'
  scope: rg
  params: {
    vnetId: networking.outputs.vnetId
    keyVaultId: security.outputs.keyVaultId
    appSubnetId: networking.outputs.appSubnetId
    tags: tags
  }
}

output resourceGroupName string = rg.name
output appGatewayPublicIp string = traffic.outputs.appGwPublicIp
output bastionName string = networking.outputs.bastionName
output keyVaultUri string = security.outputs.keyVaultUri

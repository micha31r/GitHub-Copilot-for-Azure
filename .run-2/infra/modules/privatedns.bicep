@description('VNet ID for private DNS link.')
param vnetId string

@description('Key Vault ID for the private endpoint target.')
param keyVaultId string

@description('Subnet ID where the Key Vault private endpoint is placed.')
param appSubnetId string

@description('Resource tags.')
param tags object

resource kvDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource kvDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: kvDnsZone
  name: 'kv-vnet-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnetId }
  }
}

resource kvPe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-kv'
  location: resourceGroup().location
  tags: tags
  properties: {
    subnet: { id: appSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'kv-conn'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: [ 'vault' ]
        }
      }
    ]
  }
}

resource kvPeDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: kvPe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vault'
        properties: { privateDnsZoneId: kvDnsZone.id }
      }
    ]
  }
}

output privateDnsZoneId string = kvDnsZone.id
output keyVaultPrivateEndpointId string = kvPe.id

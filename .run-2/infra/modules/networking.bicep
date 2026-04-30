@description('Region.')
param location string

@description('Workload short name.')
param workloadName string

@description('Environment short code.')
param environment string

@description('VNet address space.')
param vnetAddressPrefix string

@description('Resource tags.')
param tags object

var vnetName = 'vnet-${workloadName}-${environment}-${location}'
var bastionName = 'bas-${workloadName}-${environment}'

// ---------- NSGs ----------

resource nsgAgw 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-agw'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowGatewayManager'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 110
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowHttpInbound'
        properties: {
          priority: 210
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-web'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowIntraSubnet'
        properties: {
          priority: 90
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '10.10.1.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.1.0/24'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 105
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowAppGwToWeb'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.0.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.1.0/24'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowJumpSshToWeb'
        properties: {
          priority: 300
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.4.0/27'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.1.0/24'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DenyOtherVNet'
        properties: {
          priority: 4000
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-app'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowIntraSubnet'
        properties: {
          priority: 90
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '10.10.2.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.2.0/24'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 105
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowWebToApp'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.1.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.2.0/24'
          destinationPortRange: '8080'
        }
      }
      {
        name: 'AllowJumpSshToApp'
        properties: {
          priority: 300
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.4.0/27'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.2.0/24'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DenyOtherVNet'
        properties: {
          priority: 4000
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nsgDb 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-db'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowIntraSubnet'
        properties: {
          priority: 90
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '10.10.3.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.3.0/24'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 105
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowAppToDb'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.2.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.3.0/24'
          destinationPortRange: '5432'
        }
      }
      {
        name: 'AllowJumpSshToDb'
        properties: {
          priority: 300
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.4.0/27'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.3.0/24'
          destinationPortRange: '22'
        }
      }
      {
        name: 'DenyOtherVNet'
        properties: {
          priority: 4000
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nsgJump 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-jump'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowBastionSshRdp'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.10.5.0/26'
          sourcePortRange: '*'
          destinationAddressPrefix: '10.10.4.0/27'
          destinationPortRanges: [ '22', '3389' ]
        }
      }
      {
        name: 'DenyOtherVNet'
        properties: {
          priority: 4000
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nsgBastion 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-bastion'
  location: location
  tags: tags
  properties: {
    securityRules: [
      { name: 'AllowHttpsInbound', properties: { priority: 120, access: 'Allow', direction: 'Inbound', protocol: 'Tcp', sourceAddressPrefix: 'Internet', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '443' } }
      { name: 'AllowGatewayManagerInbound', properties: { priority: 130, access: 'Allow', direction: 'Inbound', protocol: 'Tcp', sourceAddressPrefix: 'GatewayManager', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '443' } }
      { name: 'AllowAzureLoadBalancerInbound', properties: { priority: 140, access: 'Allow', direction: 'Inbound', protocol: 'Tcp', sourceAddressPrefix: 'AzureLoadBalancer', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '443' } }
      { name: 'AllowBastionHostCommunication', properties: { priority: 150, access: 'Allow', direction: 'Inbound', protocol: '*', sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*', destinationAddressPrefix: 'VirtualNetwork', destinationPortRanges: [ '8080', '5701' ] } }
      { name: 'AllowSshRdpOutbound', properties: { priority: 100, access: 'Allow', direction: 'Outbound', protocol: '*', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: 'VirtualNetwork', destinationPortRanges: [ '22', '3389' ] } }
      { name: 'AllowAzureCloudOutbound', properties: { priority: 110, access: 'Allow', direction: 'Outbound', protocol: 'Tcp', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: 'AzureCloud', destinationPortRange: '443' } }
      { name: 'AllowBastionCommunicationOutbound', properties: { priority: 120, access: 'Allow', direction: 'Outbound', protocol: '*', sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*', destinationAddressPrefix: 'VirtualNetwork', destinationPortRanges: [ '8080', '5701' ] } }
      { name: 'AllowGetSessionInformation', properties: { priority: 130, access: 'Allow', direction: 'Outbound', protocol: '*', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: 'Internet', destinationPortRange: '80' } }
    ]
  }
}

// ---------- Public IPs ----------

resource pipNat 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-nat-${location}'
  location: location
  tags: tags
  sku: { name: 'Standard', tier: 'Regional' }
  zones: [ '1' ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

resource pipBastion 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-bastion-${workloadName}-${environment}'
  location: location
  tags: tags
  sku: { name: 'Standard', tier: 'Regional' }
  zones: [ '1', '2', '3' ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ---------- NAT Gateway ----------

resource natGw 'Microsoft.Network/natGateways@2024-05-01' = {
  name: 'ng-egress-${location}'
  location: location
  tags: tags
  sku: { name: 'Standard' }
  zones: [ '1' ]
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      { id: pipNat.id }
    ]
  }
}

// ---------- VNet ----------

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [ vnetAddressPrefix ] }
    subnets: [
      {
        name: 'snet-agw'
        properties: {
          addressPrefix: '10.10.0.0/24'
          networkSecurityGroup: { id: nsgAgw.id }
        }
      }
      {
        name: 'snet-web'
        properties: {
          addressPrefix: '10.10.1.0/24'
          networkSecurityGroup: { id: nsgWeb.id }
          natGateway: { id: natGw.id }
        }
      }
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.10.2.0/24'
          networkSecurityGroup: { id: nsgApp.id }
          natGateway: { id: natGw.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-db'
        properties: {
          addressPrefix: '10.10.3.0/24'
          networkSecurityGroup: { id: nsgDb.id }
          natGateway: { id: natGw.id }
        }
      }
      {
        name: 'snet-jump'
        properties: {
          addressPrefix: '10.10.4.0/27'
          networkSecurityGroup: { id: nsgJump.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.10.5.0/26'
          networkSecurityGroup: { id: nsgBastion.id }
        }
      }
    ]
  }
}

// ---------- Bastion ----------

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    ipConfigurations: [
      {
        name: 'ipcfg'
        properties: {
          subnet: { id: '${vnet.id}/subnets/AzureBastionSubnet' }
          publicIPAddress: { id: pipBastion.id }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output appGwSubnetId string = '${vnet.id}/subnets/snet-agw'
output webSubnetId string = '${vnet.id}/subnets/snet-web'
output appSubnetId string = '${vnet.id}/subnets/snet-app'
output dbSubnetId string = '${vnet.id}/subnets/snet-db'
output jumpSubnetId string = '${vnet.id}/subnets/snet-jump'
output bastionSubnetId string = '${vnet.id}/subnets/AzureBastionSubnet'
output webNsgId string = nsgWeb.id
output appNsgId string = nsgApp.id
output dbNsgId string = nsgDb.id
output jumpNsgId string = nsgJump.id
output bastionName string = bastion.name

@description('Azure region.')
param location string

@description('Common name prefix.')
param namePrefix string

@description('Common tags.')
param tags object

@description('Source CIDR allowed to RDP/SSH to the jumpbox.')
param adminSourceCidr string

var vnetCidr      = '10.10.0.0/16'
var mgmtCidr      = '10.10.0.0/24'
var webCidr       = '10.10.1.0/24'
var appCidr       = '10.10.2.0/24'
var dataCidr      = '10.10.3.0/24'
var appLbFrontIp  = '10.10.2.10'

// ---------- NSGs ----------

resource nsgMgmt 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: 'nsg-mgmt-${namePrefix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-FromAdminCidr'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: adminSourceCidr
          sourcePortRange: '*'
          destinationAddressPrefix: mgmtCidr
          destinationPortRange: '3389'
        }
      }
      {
        name: 'Allow-SSH-FromAdminCidr'
        properties: {
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: adminSourceCidr
          sourcePortRange: '*'
          destinationAddressPrefix: mgmtCidr
          destinationPortRange: '22'
        }
      }
      {
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: 'nsg-web-${namePrefix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-Internet'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: webCidr
          destinationPortRange: '80'
        }
      }
      {
        name: 'Allow-HTTPS-Internet'
        properties: {
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: webCidr
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-Mgmt-FromJumpbox'
        properties: {
          priority: 1020
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: mgmtCidr
          sourcePortRange: '*'
          destinationAddressPrefix: webCidr
          destinationPortRange: '*'
        }
      }
      {
        name: 'Allow-AzureLB-Probe'
        properties: {
          priority: 1100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: 'nsg-app-${namePrefix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-AppPort-FromWeb'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: webCidr
          sourcePortRange: '*'
          destinationAddressPrefix: appCidr
          destinationPortRange: '8080'
        }
      }
      {
        name: 'Allow-Mgmt-FromJumpbox'
        properties: {
          priority: 1020
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: mgmtCidr
          sourcePortRange: '*'
          destinationAddressPrefix: appCidr
          destinationPortRange: '*'
        }
      }
      {
        name: 'Allow-AzureLB-Probe'
        properties: {
          priority: 1100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nsgData 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: 'nsg-data-${namePrefix}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SQL-FromApp'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: appCidr
          sourcePortRange: '*'
          destinationAddressPrefix: dataCidr
          destinationPortRange: '1433'
        }
      }
      {
        name: 'Allow-Mgmt-FromJumpbox'
        properties: {
          priority: 1020
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: mgmtCidr
          sourcePortRange: '*'
          destinationAddressPrefix: dataCidr
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ---------- VNet + Subnets ----------

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: 'vnet-${namePrefix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }
    subnets: [
      {
        name: 'snet-mgmt'
        properties: {
          addressPrefix: mgmtCidr
          networkSecurityGroup: {
            id: nsgMgmt.id
          }
        }
      }
      {
        name: 'snet-web'
        properties: {
          addressPrefix: webCidr
          networkSecurityGroup: {
            id: nsgWeb.id
          }
        }
      }
      {
        name: 'snet-app'
        properties: {
          addressPrefix: appCidr
          networkSecurityGroup: {
            id: nsgApp.id
          }
        }
      }
      {
        name: 'snet-data'
        properties: {
          addressPrefix: dataCidr
          networkSecurityGroup: {
            id: nsgData.id
          }
        }
      }
    ]
  }
}

// ---------- Public IP for Jumpbox ----------

resource pipJump 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: 'pip-jump-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

// ---------- Internal Load Balancer (app tier) ----------

resource lbApp 'Microsoft.Network/loadBalancers@2024-07-01' = {
  name: 'lbi-app-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'feip-app'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/snet-app'
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: appLbFrontIp
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'bepool-app'
      }
    ]
    probes: [
      {
        name: 'probe-http'
        properties: {
          protocol: 'Http'
          port: 8080
          requestPath: '/health'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'rule-http'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lbi-app-${namePrefix}', 'feip-app')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lbi-app-${namePrefix}', 'bepool-app')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'lbi-app-${namePrefix}', 'probe-http')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 8080
          idleTimeoutInMinutes: 4
          enableTcpReset: true
          loadDistribution: 'Default'
          disableOutboundSnat: true
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output mgmtSubnetId string = '${vnet.id}/subnets/snet-mgmt'
output webSubnetId string = '${vnet.id}/subnets/snet-web'
output appSubnetId string = '${vnet.id}/subnets/snet-app'
output dataSubnetId string = '${vnet.id}/subnets/snet-data'
output jumpPublicIpId string = pipJump.id
output jumpPublicIpAddress string = pipJump.properties.ipAddress
output appLbId string = lbApp.id
output appLbFrontendPrivateIp string = appLbFrontIp
output appBackendPoolId string = '${lbApp.id}/backendAddressPools/bepool-app'

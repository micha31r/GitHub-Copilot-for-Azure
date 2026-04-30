@description('Region.')
param location string

@description('Resource tags.')
param tags object

@description('Linux admin username.')
param adminUsername string

@description('SSH public key.')
@secure()
param adminSshPublicKey string

@description('VMSS instance count for tiers.')
param vmssInstanceCount int

@description('Web/app tier VM size.')
param webAppVmSize string

@description('Db tier VM size.')
param dbVmSize string

@description('Jumpbox VM size.')
param jumpVmSize string

param webSubnetId string
param appSubnetId string
param dbSubnetId string
param jumpSubnetId string
param webNsgId string
param appNsgId string
param dbNsgId string
param jumpNsgId string
param appGwBackendPoolId string
param lbiAppBackendPoolId string
param lbiDbBackendPoolId string
param workloadIdentityId string
param diagnosticsStorageEndpoint string

var ubuntuImage = {
  publisher: 'Canonical'
  offer: 'ubuntu-24_04-lts'
  sku: 'server'
  version: 'latest'
}

var sshConfig = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminSshPublicKey
      }
    ]
  }
}

// ---------- Web VMSS ----------

resource vmssWeb 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = {
  name: 'vmss-web'
  location: location
  tags: tags
  zones: [ '1', '2', '3' ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${workloadIdentityId}': {} }
  }
  sku: { name: webAppVmSize, capacity: vmssInstanceCount, tier: 'Standard' }
  properties: {
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    singlePlacementGroup: false
    virtualMachineProfile: {
      securityProfile: {
        securityType: 'TrustedLaunch'
        uefiSettings: { secureBootEnabled: true, vTpmEnabled: true }
        encryptionAtHost: true
      }
      diagnosticsProfile: { bootDiagnostics: { enabled: true, storageUri: diagnosticsStorageEndpoint } }
      osProfile: {
        computerNamePrefix: 'web'
        adminUsername: adminUsername
        linuxConfiguration: sshConfig
      }
      storageProfile: {
        imageReference: ubuntuImage
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: { storageAccountType: 'Premium_LRS' }
        }
      }
      networkProfile: {
        networkApiVersion: '2024-05-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-web'
            properties: {
              primary: true
              enableAcceleratedNetworking: true
              networkSecurityGroup: { id: webNsgId }
              ipConfigurations: [
                {
                  name: 'ipcfg'
                  properties: {
                    subnet: { id: webSubnetId }
                    applicationGatewayBackendAddressPools: [ { id: appGwBackendPoolId } ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

// ---------- App VMSS ----------

resource vmssApp 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = {
  name: 'vmss-app'
  location: location
  tags: tags
  zones: [ '1', '2', '3' ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${workloadIdentityId}': {} }
  }
  sku: { name: webAppVmSize, capacity: vmssInstanceCount, tier: 'Standard' }
  properties: {
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    singlePlacementGroup: false
    virtualMachineProfile: {
      securityProfile: {
        securityType: 'TrustedLaunch'
        uefiSettings: { secureBootEnabled: true, vTpmEnabled: true }
        encryptionAtHost: true
      }
      diagnosticsProfile: { bootDiagnostics: { enabled: true, storageUri: diagnosticsStorageEndpoint } }
      osProfile: {
        computerNamePrefix: 'app'
        adminUsername: adminUsername
        linuxConfiguration: sshConfig
      }
      storageProfile: {
        imageReference: ubuntuImage
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: { storageAccountType: 'Premium_LRS' }
        }
      }
      networkProfile: {
        networkApiVersion: '2024-05-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-app'
            properties: {
              primary: true
              enableAcceleratedNetworking: true
              networkSecurityGroup: { id: appNsgId }
              ipConfigurations: [
                {
                  name: 'ipcfg'
                  properties: {
                    subnet: { id: appSubnetId }
                    loadBalancerBackendAddressPools: [ { id: lbiAppBackendPoolId } ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

// ---------- Db VMSS ----------

resource vmssDb 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = {
  name: 'vmss-db'
  location: location
  tags: tags
  zones: [ '1', '2', '3' ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${workloadIdentityId}': {} }
  }
  sku: { name: dbVmSize, capacity: vmssInstanceCount, tier: 'Standard' }
  properties: {
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    singlePlacementGroup: false
    virtualMachineProfile: {
      securityProfile: {
        securityType: 'TrustedLaunch'
        uefiSettings: { secureBootEnabled: true, vTpmEnabled: true }
        encryptionAtHost: true
      }
      diagnosticsProfile: { bootDiagnostics: { enabled: true, storageUri: diagnosticsStorageEndpoint } }
      osProfile: {
        computerNamePrefix: 'db'
        adminUsername: adminUsername
        linuxConfiguration: sshConfig
      }
      storageProfile: {
        imageReference: ubuntuImage
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: { storageAccountType: 'Premium_LRS' }
        }
      }
      networkProfile: {
        networkApiVersion: '2024-05-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-db'
            properties: {
              primary: true
              enableAcceleratedNetworking: true
              networkSecurityGroup: { id: dbNsgId }
              ipConfigurations: [
                {
                  name: 'ipcfg'
                  properties: {
                    subnet: { id: dbSubnetId }
                    loadBalancerBackendAddressPools: [ { id: lbiDbBackendPoolId } ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

// ---------- Jumpbox VM ----------

resource nicJump 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-jump'
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: false
    networkSecurityGroup: { id: jumpNsgId }
    ipConfigurations: [
      {
        name: 'ipcfg'
        properties: {
          subnet: { id: jumpSubnetId }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vmJump 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: 'vm-jump'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${workloadIdentityId}': {} }
  }
  properties: {
    hardwareProfile: { vmSize: jumpVmSize }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: { secureBootEnabled: true, vTpmEnabled: true }
      encryptionAtHost: true
    }
    diagnosticsProfile: { bootDiagnostics: { enabled: true, storageUri: diagnosticsStorageEndpoint } }
    osProfile: {
      computerName: 'vm-jump'
      adminUsername: adminUsername
      linuxConfiguration: sshConfig
    }
    storageProfile: {
      imageReference: ubuntuImage
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [
        { id: nicJump.id, properties: { primary: true } }
      ]
    }
  }
}

output webVmssId string = vmssWeb.id
output appVmssId string = vmssApp.id
output dbVmssId string = vmssDb.id
output jumpVmId string = vmJump.id

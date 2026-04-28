@description('Azure region.')
param location string

@description('Common name prefix.')
param namePrefix string

@description('Common tags.')
param tags object

@description('Admin username for the jumpbox VM.')
param jumpAdminUsername string

@description('Admin password for the jumpbox VM.')
@secure()
param jumpAdminPassword string

@description('Resource ID of snet-mgmt.')
param mgmtSubnetId string

@description('Resource ID of snet-web.')
param webSubnetId string

@description('Resource ID of snet-app.')
param appSubnetId string

@description('Resource ID of snet-data.')
param dataSubnetId string

@description('Resource ID of the internal LB backend pool the app tier joins.')
param appBackendPoolId string

@description('Resource ID of the jumpbox public IP.')
param jumpPublicIpId string

@description('Resource ID of the user-assigned managed identity.')
param userAssignedIdentityId string

@description('VM size used for the jumpbox and tier VMSS.')
param vmSize string = 'Standard_D2s_v5'

@description('Instance count per tier VMSS.')
param tierInstanceCount int = 2

// ---------- Jumpbox NIC ----------

resource nicJump 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: 'nic-jump-${namePrefix}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: mgmtSubnetId
          }
          publicIPAddress: {
            id: jumpPublicIpId
          }
        }
      }
    ]
  }
}

// ---------- Jumpbox VM (Windows Server 2022, TrustedLaunch) ----------

resource vmJump 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: 'vm-jump-${namePrefix}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    osProfile: {
      computerName: 'vm-jump'
      adminUsername: jumpAdminUsername
      adminPassword: jumpAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          assessmentMode: 'AutomaticByPlatform'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Detach'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicJump.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// ---------- Web Tier VMSS ----------

resource vmssWeb 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = {
  name: 'vmss-web-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: tierInstanceCount
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    virtualMachineProfile: {
      securityProfile: {
        securityType: 'TrustedLaunch'
        uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
        }
      }
      osProfile: {
        computerNamePrefix: 'web'
        adminUsername: jumpAdminUsername
        adminPassword: jumpAdminPassword
        linuxConfiguration: {
          disablePasswordAuthentication: false
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: 'ubuntu-24_04-lts'
          sku: 'server'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
          deleteOption: 'Detach'
        }
      }
      networkProfile: {
        networkApiVersion: '2024-07-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-web'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    subnet: {
                      id: webSubnetId
                    }
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

// ---------- App Tier VMSS (joins ILB backend pool) ----------

resource vmssApp 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = {
  name: 'vmss-app-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: tierInstanceCount
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    virtualMachineProfile: {
      securityProfile: {
        securityType: 'TrustedLaunch'
        uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
        }
      }
      osProfile: {
        computerNamePrefix: 'app'
        adminUsername: jumpAdminUsername
        adminPassword: jumpAdminPassword
        linuxConfiguration: {
          disablePasswordAuthentication: false
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: 'ubuntu-24_04-lts'
          sku: 'server'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
          deleteOption: 'Detach'
        }
      }
      networkProfile: {
        networkApiVersion: '2024-07-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-app'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    subnet: {
                      id: appSubnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: appBackendPoolId
                      }
                    ]
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

// ---------- Data Tier VMSS (placeholder) ----------

resource vmssData 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = {
  name: 'vmss-data-${namePrefix}'
  location: location
  tags: tags
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: tierInstanceCount
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    virtualMachineProfile: {
      securityProfile: {
        securityType: 'TrustedLaunch'
        uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
        }
      }
      osProfile: {
        computerNamePrefix: 'data'
        adminUsername: jumpAdminUsername
        adminPassword: jumpAdminPassword
        linuxConfiguration: {
          disablePasswordAuthentication: false
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: 'ubuntu-24_04-lts'
          sku: 'server'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
          deleteOption: 'Detach'
        }
      }
      networkProfile: {
        networkApiVersion: '2024-07-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-data'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    subnet: {
                      id: dataSubnetId
                    }
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

output jumpVmId string = vmJump.id
output webVmssId string = vmssWeb.id
output appVmssId string = vmssApp.id
output dataVmssId string = vmssData.id

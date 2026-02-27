// ---------------------------------------------------------------------------
// modules/compute.bicep — App Service Plan + App Service
// ---------------------------------------------------------------------------

@description('Azure region')
param location string

@description('Environment name')
param environmentName string

@description('Workload name')
param workloadName string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Key Vault URI')
param keyVaultUri string

// ── App Service Plan (F1 Free — $0/month) ───────────────────────────────────

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: 'asp-${workloadName}-${environmentName}-001'
  location: location
  kind: 'linux'
  sku: {
    name: 'F1'
    tier: 'Free'
    capacity: 1
  }
  properties: {
    reserved: true // required for Linux
  }
}

// ── App Service (Linux Node.js 20) ──────────────────────────────────────────

resource appService 'Microsoft.Web/sites@2024-11-01' = {
  name: 'app-${workloadName}-${environmentName}-001'
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: false // not available on Free tier
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'KEY_VAULT_URI'
          value: keyVaultUri
        }
      ]
    }
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output appServiceId string = appService.id
output appServiceDefaultHostname string = 'https://${appService.properties.defaultHostName}'
output appServicePrincipalId string = appService.identity.principalId
output appServicePlanId string = appServicePlan.id

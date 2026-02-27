// ---------------------------------------------------------------------------
// main.bicep — Orchestrator for multi-environment web app infrastructure
// Generated from: .azure/infrastructure-plan.json (plan-multienv-webapp-001)
// ---------------------------------------------------------------------------

targetScope = 'resourceGroup'

// ── Parameters ──────────────────────────────────────────────────────────────

@description('Azure region for all resources')
param location string

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('Workload name used in resource naming')
param workloadName string = 'webapp'

@description('SQL Server administrator login')
param sqlAdminLogin string

@secure()
@description('SQL Server administrator password')
param sqlAdminPassword string

@description('Azure AD tenant ID for Key Vault')
param tenantId string = subscription().tenantId

// ── Modules ─────────────────────────────────────────────────────────────────

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-${environmentName}'
  params: {
    location: location
    environmentName: environmentName
    workloadName: workloadName
  }
}

module security 'modules/security.bicep' = {
  name: 'security-${environmentName}'
  params: {
    location: location
    environmentName: environmentName
    workloadName: workloadName
    tenantId: tenantId
  }
}

module data 'modules/data.bicep' = {
  name: 'data-${environmentName}'
  params: {
    location: location
    environmentName: environmentName
    workloadName: workloadName
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
  }
}

module compute 'modules/compute.bicep' = {
  name: 'compute-${environmentName}'
  params: {
    location: location
    environmentName: environmentName
    workloadName: workloadName
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    keyVaultUri: security.outputs.keyVaultUri
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output appServiceUrl string = compute.outputs.appServiceDefaultHostname
output sqlServerFqdn string = data.outputs.sqlServerFqdn
output redisHostName string = data.outputs.redisHostName
output keyVaultUri string = security.outputs.keyVaultUri
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

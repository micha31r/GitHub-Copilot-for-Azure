// ---------------------------------------------------------------------------
// modules/monitoring.bicep — Log Analytics + Application Insights
// ---------------------------------------------------------------------------

@description('Azure region')
param location string

@description('Environment name')
param environmentName string

@description('Workload name')
param workloadName string

// ── Log Analytics Workspace ─────────────────────────────────────────────────

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'log-${workloadName}-${environmentName}-001'
  location: location
  properties: {
    sku: {
      name: 'Free'
    }
    retentionInDays: 7
  }
}

// ── Application Insights ────────────────────────────────────────────────────

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${workloadName}-${environmentName}-001'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output logWorkspaceId string = logWorkspace.id
output appInsightsId string = appInsights.id
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

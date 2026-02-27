// ---------------------------------------------------------------------------
// modules/data.bicep — SQL Server + SQL Database + Redis Cache
// ---------------------------------------------------------------------------

@description('Azure region')
param location string

@description('Environment name')
param environmentName string

@description('Workload name')
param workloadName string

@description('SQL Server administrator login')
param sqlAdminLogin string

@secure()
@description('SQL Server administrator password')
param sqlAdminPassword string

// ── SQL Server (logical server — free) ──────────────────────────────────────

resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = {
  name: 'sql-${workloadName}-${environmentName}-001'
  location: location
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// ── SQL Database (Basic 5 DTU — ~$5/month) ──────────────────────────────────

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01' = {
  name: 'sqldb-${workloadName}-${environmentName}-001'
  location: location
  parent: sqlServer
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    maxSizeBytes: 2147483648 // 2 GB
    requestedBackupStorageRedundancy: 'Local'
    zoneRedundant: false
  }
}

// ── Redis Cache (Basic C0 250MB — ~$16/month) ───────────────────────────────

resource redisCache 'Microsoft.Cache/redis@2024-11-01' = {
  name: 'redis-${workloadName}-${environmentName}-001'
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output redisHostName string = redisCache.properties.hostName
output redisSslPort int = redisCache.properties.sslPort

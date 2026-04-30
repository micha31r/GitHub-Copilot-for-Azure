@description('Region.')
param location string

@description('Workload short name.')
param workloadName string

@description('Environment short code.')
param environment string

@description('Resource tags.')
param tags object

@description('Subnet ID for the Application Gateway.')
param appGwSubnetId string

@description('Subnet ID for the app tier (internal LB frontend).')
param appSubnetId string

@description('Subnet ID for the db tier (internal LB frontend).')
param dbSubnetId string

var agwName = 'agw-${workloadName}-${environment}'
var wafPolicyName = 'wafpol-${workloadName}-${environment}'
var pipAgwName = 'pip-agw-${workloadName}-${environment}'

// ---------- WAF Policy ----------

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-05-01' = {
  name: wafPolicyName
  location: location
  tags: tags
  properties: {
    policySettings: {
      state: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    managedRules: {
      managedRuleSets: [
        { ruleSetType: 'OWASP', ruleSetVersion: '3.2' }
        { ruleSetType: 'Microsoft_BotManagerRuleSet', ruleSetVersion: '1.0' }
      ]
    }
  }
}

// ---------- Public IP for AppGw ----------

resource pipAgw 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: pipAgwName
  location: location
  tags: tags
  sku: { name: 'Standard', tier: 'Regional' }
  zones: [ '1', '2', '3' ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// ---------- Application Gateway WAF v2 ----------

resource agw 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: agwName
  location: location
  tags: tags
  zones: [ '1', '2', '3' ]
  properties: {
    sku: { name: 'WAF_v2', tier: 'WAF_v2' }
    autoscaleConfiguration: { minCapacity: 2, maxCapacity: 10 }
    firewallPolicy: { id: wafPolicy.id }
    gatewayIPConfigurations: [
      { name: 'gwipcfg', properties: { subnet: { id: appGwSubnetId } } }
    ]
    frontendIPConfigurations: [
      { name: 'feip-public', properties: { publicIPAddress: { id: pipAgw.id } } }
    ]
    frontendPorts: [
      { name: 'fep-http', properties: { port: 80 } }
    ]
    backendAddressPools: [
      { name: 'bep-web' }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'beh-http'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'lst-http'
        properties: {
          frontendIPConfiguration: { id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', agwName, 'feip-public') }
          frontendPort: { id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', agwName, 'fep-http') }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'rr-http'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: { id: resourceId('Microsoft.Network/applicationGateways/httpListeners', agwName, 'lst-http') }
          backendAddressPool: { id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agwName, 'bep-web') }
          backendHttpSettings: { id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', agwName, 'beh-http') }
        }
      }
    ]
  }
}

// ---------- Internal Load Balancer (app tier) ----------

resource lbiApp 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: 'lbi-app'
  location: location
  tags: tags
  sku: { name: 'Standard', tier: 'Regional' }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'feip-app'
        zones: [ '1', '2', '3' ]
        properties: {
          subnet: { id: appSubnetId }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    backendAddressPools: [
      { name: 'bep-app' }
    ]
    probes: [
      {
        name: 'probe-app-8080'
        properties: { protocol: 'Tcp', port: 8080, intervalInSeconds: 5, numberOfProbes: 2 }
      }
    ]
    loadBalancingRules: [
      {
        name: 'rule-app-8080'
        properties: {
          frontendIPConfiguration: { id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lbi-app', 'feip-app') }
          backendAddressPool: { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lbi-app', 'bep-app') }
          probe: { id: resourceId('Microsoft.Network/loadBalancers/probes', 'lbi-app', 'probe-app-8080') }
          protocol: 'Tcp'
          frontendPort: 8080
          backendPort: 8080
          enableFloatingIP: false
          enableTcpReset: true
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
          disableOutboundSnat: true
        }
      }
    ]
  }
}

// ---------- Internal Load Balancer (db tier) ----------

resource lbiDb 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: 'lbi-db'
  location: location
  tags: tags
  sku: { name: 'Standard', tier: 'Regional' }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'feip-db'
        zones: [ '1', '2', '3' ]
        properties: {
          subnet: { id: dbSubnetId }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    backendAddressPools: [
      { name: 'bep-db' }
    ]
    probes: [
      {
        name: 'probe-db-5432'
        properties: { protocol: 'Tcp', port: 5432, intervalInSeconds: 5, numberOfProbes: 2 }
      }
    ]
    loadBalancingRules: [
      {
        name: 'rule-db-5432'
        properties: {
          frontendIPConfiguration: { id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lbi-db', 'feip-db') }
          backendAddressPool: { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lbi-db', 'bep-db') }
          probe: { id: resourceId('Microsoft.Network/loadBalancers/probes', 'lbi-db', 'probe-db-5432') }
          protocol: 'Tcp'
          frontendPort: 5432
          backendPort: 5432
          enableFloatingIP: false
          enableTcpReset: true
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
          disableOutboundSnat: true
        }
      }
    ]
  }
}

output appGwId string = agw.id
output appGwBackendPoolId string = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agwName, 'bep-web')
output appGwPublicIp string = pipAgw.properties.ipAddress
output lbiAppBackendPoolId string = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lbi-app', 'bep-app')
output lbiDbBackendPoolId string = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lbi-db', 'bep-db')

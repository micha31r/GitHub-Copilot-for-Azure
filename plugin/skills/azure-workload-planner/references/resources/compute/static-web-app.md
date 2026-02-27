# Static Web App

## Identity

| Field | Value |
|-------|-------|

| ARM Type | `Microsoft.Web/staticSites` |
| Bicep API Version | `2024-04-01` |
| CAF Prefix | `stapp` |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions.

> Verify at plan time: `microsoft_docs_fetch` → `https://learn.microsoft.com/azure/reliability/availability-service-by-category`

## Subtypes (kind)

Static Web App does not use `kind` in standard deployments.

## SKU Names

| SKU Name | SKU Tier | Description |
|----------|----------|-------------|

| `Free` | `Free` | Free tier — hobby/personal projects, 2 custom domains, 0.5 GB storage |
| `Standard` | `Standard` | Standard tier — production workloads, 5 custom domains, 2 GB storage, SLA, private endpoints |

## Naming

| Constraint | Value |
|------------|-------|

| Min Length | 1 |
| Max Length | 40 |
| Allowed Characters | Alphanumerics, hyphens. Cannot start or end with hyphen. |
| Scope | Resource group |
| Pattern | `stapp-{workload}-{env}-{instance}` |
| Example | `stapp-datapipeline-prod-001` |

## Required Properties (Bicep)

```bicep
resource staticWebApp 'Microsoft.Web/staticSites@2024-04-01' = {
  name: 'string'       // required
  location: 'string'   // required
  sku: {
    name: 'string'     // recommended — 'Free' or 'Standard'
    tier: 'string'     // recommended — matches sku.name
  }
  properties: {
    repositoryUrl: 'string'     // optional — GitHub/Azure DevOps repo URL
    branch: 'string'            // optional — branch to deploy from
    repositoryToken: 'string'   // optional — GitHub PAT or Azure DevOps token
    buildProperties: {
      appLocation: 'string'     // optional — app source code path (default: '/')
      apiLocation: 'string'     // optional — API source code path
      outputLocation: 'string'  // optional — build output path
    }
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|

| `sku.name` | Pricing tier | `Free`, `Standard` |
| `sku.tier` | Tier (matches name) | `Free`, `Standard` |
| `properties.repositoryUrl` | Source repo URL | GitHub or Azure DevOps URL |
| `properties.branch` | Deployment branch | String (e.g., `main`) |
| `properties.repositoryToken` | Repo access token | String (secure — GitHub PAT) |
| `properties.buildProperties.appLocation` | App source path | String (e.g., `/`, `src/app`) |
| `properties.buildProperties.apiLocation` | API source path | String (e.g., `api`) |
| `properties.buildProperties.outputLocation` | Build output path | String (e.g., `dist`, `build`) |
| `properties.provider` | CI/CD provider | `GitHub`, `DevOps`, `Custom` |
| `properties.stagingEnvironmentPolicy` | Staging env policy | `Enabled`, `Disabled` |
| `properties.allowConfigFileUpdates` | Config file updates | `true`, `false` |
| `properties.enterpriseGradeCdnStatus` | Enterprise CDN | `Enabled`, `Disabled` |

### Read-Only Properties

| Property | Description |
|----------|-------------|

| `properties.defaultHostname` | Default hostname (e.g., `{name}.azurestaticapps.net`) |
| `properties.customDomains` | Configured custom domains |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|

| **GitHub Repository** | Provide `repositoryUrl`, `branch`, and `repositoryToken`. A GitHub Actions workflow is auto-created in the repo. |
| **Azure DevOps** | Set `provider: 'DevOps'`. Provide `repositoryUrl` and `branch`. Pipeline is configured separately. |
| **Azure Functions (managed)** | API location in `buildProperties.apiLocation` deploys a managed Functions backend. Limited to HTTP triggers, C#, JavaScript, Python, Java. |
| **Linked Backend** | Use `linkedBackends` child resource to connect an existing Function App, Container App, or App Service as the API backend. Standard SKU required. |
| **Private Endpoint** | Only available with `Standard` SKU. Set up a Private Endpoint to restrict access to the static web app. |
| **Custom Domain** | Custom domains are child resources. Require DNS CNAME or TXT validation. Free SSL certificates are auto-provisioned. |
| **Enterprise-Grade CDN** | `Standard` SKU only. Enables Azure Front Door integration for advanced caching and edge capabilities. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|

| Custom Domains | `Microsoft.Web/staticSites/customDomains` | Custom domain bindings |
| Config | `Microsoft.Web/staticSites/config` | App settings, function app settings |
| Linked Backends | `Microsoft.Web/staticSites/linkedBackends` | External API backend connections |
| Database Connections | `Microsoft.Web/staticSites/databaseConnections` | Database connection strings |
| User Provided Functions | `Microsoft.Web/staticSites/userProvidedFunctionApps` | Bring-your-own Function App |

## References

- [Bicep resource reference (2024-04-01)](https://learn.microsoft.com/azure/templates/microsoft.web/staticsites?pivots=deployment-language-bicep)
- [Static Web Apps overview](https://learn.microsoft.com/azure/static-web-apps/overview)
- [Azure naming rules — Web](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftweb)
- [Static Web Apps hosting plans](https://learn.microsoft.com/azure/static-web-apps/plans)

# Cognitive Services Account

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.CognitiveServices/accounts` |
| Bicep API Version | `2025-06-01` |
| CAF Prefix | Varies by kind — see Subtypes table |

## Region Availability

**Category:** Mainstream — available in all recommended regions; demand-driven in alternate regions. Specific kinds vary by region — always verify for OpenAI, Speech, and Vision services.

## Subtypes (kind)

The `kind` property is a required string that determines the specific Cognitive Service. Verified values from CAF resource abbreviations:

| Kind | Service Name | CAF Prefix |
|------|--------------|------------|
| `AIServices` | Azure AI Foundry (multi-service) | `aif` |
| `CognitiveServices` | Foundry Tools multi-service account | `ais` |
| `OpenAI` | Azure OpenAI Service | `oai` |
| `ComputerVision` | Computer Vision | `cv` |
| `ContentModerator` | Content Moderator | `cm` |
| `ContentSafety` | Content Safety | `cs` |
| `CustomVision.Prediction` | Custom Vision — Prediction | `cstv` |
| `CustomVision.Training` | Custom Vision — Training | `cstvt` |
| `FormRecognizer` | Document Intelligence | `di` |
| `Face` | Face API | `face` |
| `HealthInsights` | Health Insights | `hi` |
| `ImmersiveReader` | Immersive Reader | `ir` |
| `TextAnalytics` | Language Service | `lang` |
| `SpeechServices` | Speech Service | `spch` |
| `TextTranslation` | Translator | `trsl` |

> **Note:** The `kind` value is set at creation and **cannot be changed**. The `kind` determines which SKUs, endpoints, and features are available.

## SKU Names

Exact `sku.name` values for Bicep (string). Available SKUs depend on `kind`. The `sku.tier` enum values are: `Basic`, `Enterprise`, `Free`, `Premium`, `Standard`.

| SKU Name | Common Usage | Notes |
|----------|--------------|-------|
| `F0` | Free tier | Available for most kinds; single instance per subscription per kind per region |
| `S0` | Standard paid tier | Most common paid SKU; available for most kinds |
| `S1` | Standard tier (higher) | Available for select kinds (e.g., SpeechServices) |
| `DC0` | Data Center tier | Connected container scenarios |

> **Guidance:** Use `F0` for development/testing, `S0` for production. Not all kinds support all SKUs — consult the specific service documentation.

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 2 |
| Max Length | 64 |
| Allowed Characters | Alphanumerics and hyphens |
| Pattern (regex) | `^[a-zA-Z0-9][a-zA-Z0-9-]*$` |
| Scope | Resource group |
| Example | `oai-chatbot-prod-001` |

> Must start with an alphanumeric. Name also forms part of the default endpoint subdomain. For Microsoft Entra ID authentication, set a `customSubDomainName` (required, globally unique, 2-64 lowercase alphanumeric/hyphen characters).

## Required Properties (Bicep)

```bicep
resource cognitiveAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: 'string'        // required, 2-64 chars
  location: 'string'    // required
  kind: 'string'        // required — see Subtypes table
  sku: {
    name: 'string'      // required — see SKU Names table
  }
  properties: {
    customSubDomainName: 'string'  // required for Entra ID auth, globally unique
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `kind` | Cognitive service type (set at creation) | See Subtypes table |
| `properties.customSubDomainName` | Custom subdomain for endpoint | Globally unique, lowercase alphanumeric + hyphens |
| `properties.publicNetworkAccess` | Public network access | `Enabled`, `Disabled` |
| `properties.disableLocalAuth` | Disable API key authentication | `true`, `false` |
| `properties.networkAcls.defaultAction` | Default network action | `Allow`, `Deny` |
| `properties.networkAcls.bypass` | Bypass trusted services | `AzureServices`, `None` |
| `properties.encryption.keySource` | Encryption key source | `Microsoft.CognitiveServices`, `Microsoft.KeyVault` |
| `properties.userOwnedStorage` | Customer-managed storage | Array of storage resource references |
| `properties.allowProjectManagement` | AI Foundry project management | `true`, `false` |
| `properties.networkInjections.scenario` | Network injection scenario | `agent`, `none` |

## Pairing Constraints

| Paired With | Constraint |
|-------------|------------|
| **Azure OpenAI Deployments** | When `kind: 'OpenAI'` or `kind: 'AIServices'`, create model deployments as child resource `accounts/deployments`. |
| **Microsoft Entra ID Auth** | Requires `customSubDomainName` to be set. Without it, only API key auth works. |
| **Private Endpoint** | Requires `customSubDomainName`. Set `publicNetworkAccess: 'Disabled'` and configure private DNS zone. |
| **Key Vault (CMK)** | When using customer-managed keys, Key Vault must have soft-delete and purge protection enabled. Set `encryption.keySource: 'Microsoft.KeyVault'`. |
| **Storage Account** | When using `userOwnedStorage`, the storage account must be in the same region. Required for certain features (e.g., batch translation). |
| **AI Foundry Hub** | When `kind: 'AIServices'` with `allowProjectManagement: true`, can manage Foundry projects as child resources (`accounts/projects`). |
| **VNet Integration** | Configure `networkAcls` with `defaultAction: 'Deny'` and add virtual network rules. Set `bypass: 'AzureServices'` to allow trusted Azure services. |

## Child Resources

| Child Type | ARM Type | Purpose |
|------------|----------|---------|
| Deployments | `Microsoft.CognitiveServices/accounts/deployments` | Model deployments (OpenAI, etc.) |
| Commitment Plans | `Microsoft.CognitiveServices/accounts/commitmentPlans` | Reserved capacity plans |
| RAI Blocklists | `Microsoft.CognitiveServices/accounts/raiBlocklists` | Responsible AI content blocklists |
| RAI Policies | `Microsoft.CognitiveServices/accounts/raiPolicies` | Responsible AI content filtering policies |
| Defender Settings | `Microsoft.CognitiveServices/accounts/defenderForAISettings` | Defender for AI threat protection |
| Encryption Scopes | `Microsoft.CognitiveServices/accounts/encryptionScopes` | Customer-managed key scopes |
| Connections | `Microsoft.CognitiveServices/accounts/connections` | Service connections |
| Projects | `Microsoft.CognitiveServices/accounts/projects` | AI Foundry projects (kind=AIServices) |
| Private Endpoint Connections | `Microsoft.CognitiveServices/accounts/privateEndpointConnections` | Private networking |

## References

- [Bicep resource reference (2025-06-01)](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/accounts?pivots=deployment-language-bicep)
- [All API versions](https://learn.microsoft.com/azure/templates/microsoft.cognitiveservices/allversions)
- [Azure naming rules — Cognitive Services](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftcognitiveservices)
- [Custom subdomain names](https://learn.microsoft.com/azure/ai-services/cognitive-services-custom-subdomains)
- [CAF abbreviations](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)

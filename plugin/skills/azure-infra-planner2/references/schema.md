# Infrastructure Plan Schema

Output path: `<project-root>/.azure/infrastructure-plan.json`

```jsonc
{
  "meta": {
    "planId": "string", // unique plan identifier
    "generatedAt": "string", // ISO 8601 timestamp
    "version": "string", // schema version
    "status": "string" // draft | reviewed | approved | rejected
  },

  "inputs": {
    "userGoal": "string", // user's stated objective, verbatim from query
    "subGoals": ["string"] // 0-3 inferred constraints (cost, security, complexity)
  },

  "plan": {
    "resources": [
      {
        "name": "string", // CAF-compliant resource name
        "type": "string", // ARM resource type (e.g. Microsoft.Storage/storageAccounts)
        "subtype": "string?", // friendly label (e.g. Blob Storage, Azure Function)
        "location": "string", // Azure region
        "sku": "string", // pricing tier or "N/A" for typeless resources

        "properties": {}, // optional, ARM-aligned resource configuration

        "reasoning": {
          "whyChosen": "string",
          "alternativesConsidered": ["string"],
          "tradeoffs": "string"
        },

        "dependencies": ["string"], // resource names that must exist first, [] if none
        "dependencyReasoning": "string?", // why the dependencies are needed

        "references": [
          { "title": "string", "url": "string" }
        ]
      }
    ],

    "assumptions": ["string"], // documented assumptions when user query is vague

    "overallReasoning": {
      "summary": "string", // architecture rationale
      "tradeoffs": "string" // top-level tradeoffs and gaps
    },

    "validation": "string", // deployment coherence statement
    "architecturePrinciples": ["string"], // guiding principles
    "references": [
      { "title": "string", "url": "string" }
    ]
  }
}
```

Required on every resource: `name`, `type`, `location`, `sku`, `reasoning`, `dependencies`, `references`.

The `resources` array must include supporting resources — not just top-level services:

```
Microsoft.Authorization/roleAssignments    — one per identity/service/role triple
Microsoft.Insights/diagnosticSettings      — one per resource emitting platform logs
Microsoft.Web/serverfarms                  — required for any Function App or App Service
Microsoft.CognitiveServices/accounts/deployments — one per model deployment
```

Array order reflects a valid deployment sequence.
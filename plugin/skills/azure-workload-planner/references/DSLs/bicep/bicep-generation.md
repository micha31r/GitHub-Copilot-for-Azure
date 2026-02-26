# Bicep Generation

Generate Bicep IaC files from the approved infrastructure plan.

## MCP Tools

- Use `mcp_azure_mcp_bicepschema` to retrieve accurate resource schemas and property definitions
- Use `mcp_azure_mcp_deploy` with `iac rules get` to apply IaC best practices

## File Structure

Generate files under `./infra/`:

```
infra/
├── main.bicep              # Orchestrator — deploys all modules
├── main.bicepparam         # Parameter values
└── modules/
    ├── storage.bicep        # One module per resource or logical group
    ├── compute.bicep
    ├── networking.bicep
    └── monitoring.bicep
```

## Generation Steps

1. **Read plan** — Load `.azure/infrastructure-plan.json`, verify `meta.status === "approved"`
2. **Look up schemas** — For each resource `type`, call `mcp_azure_mcp_bicepschema` to get the correct API version and required properties
3. **Generate modules** — Group resources by category; one `.bicep` file per group
4. **Generate main.bicep** — Import all modules, pass parameters
5. **Generate parameters** — Create `main.bicepparam` with environment-specific values
6. **Apply best practices** — Call `mcp_azure_mcp_deploy` `iac rules get` and verify compliance

## Bicep Conventions

- Use `@description()` decorators on all parameters
- Use `@secure()` for secrets and connection strings
- Declare `targetScope = 'resourceGroup'` at top of `main.bicep`
- Use `existing` keyword for referencing pre-existing resources
- Output resource IDs and endpoints needed by other resources
- Use `dependsOn` only when implicit dependencies are insufficient

## Parameter File Format

```bicep
using './main.bicep'

param location = 'eastus'
param environmentName = 'prod'
param workloadName = 'datapipeline'
```

## Multi-Environment

For multi-environment plans, generate one parameter file per environment:

```txt
infra/
├── main.bicep
├── main.dev.bicepparam
├── main.staging.bicepparam
└── main.prod.bicepparam
```

## Validation Before Deployment

Run `az bicep build --file infra/main.bicep` to validate syntax before deploying.

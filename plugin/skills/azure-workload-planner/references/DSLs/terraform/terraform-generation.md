# Terraform Generation

Generate Terraform IaC files from the approved infrastructure plan.

## File Structure

Generate files under `./infra/`:

```
infra/
├── main.tf                 # Root module — calls child modules
├── variables.tf            # Input variable declarations
├── outputs.tf              # Output values
├── terraform.tfvars        # Default variable values
├── providers.tf            # Provider configuration
├── backend.tf              # State backend configuration
└── modules/
    ├── storage/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── compute/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── networking/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Generation Steps

1. **Read plan** — Load `.azure/infrastructure-plan.json`, verify `meta.status === "approved"`
2. **Generate providers.tf** — Configure `azurerm` provider with required features
3. **Generate modules** — Group resources by category; one module per group
4. **Generate root main.tf** — Call all modules, wire outputs to inputs
5. **Generate variables.tf** — Declare all configurable parameters with descriptions and types
6. **Generate terraform.tfvars** — Default values from the plan
7. **Generate backend.tf** — Azure Storage backend for remote state

## Terraform Conventions

- Use `azurerm` provider (latest stable version)
- Set `features {}` block in provider configuration
- Use `variable` blocks with `description`, `type`, and `default` where appropriate
- Use `locals` for computed values and naming patterns
- Use `depends_on` only when implicit dependencies are insufficient
- Tag all resources with `environment`, `workload`, and `managed-by = "terraform"`

## Provider Configuration

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
```

## Multi-Environment

For multi-environment plans, generate one `.tfvars` file per environment:

```
infra/
├── main.tf
├── variables.tf
├── dev.tfvars
├── staging.tfvars
└── prod.tfvars
```

Deploy with: `terraform apply -var-file=prod.tfvars`

## Validation Before Deployment

Run `terraform validate` and `terraform plan` to verify before applying.

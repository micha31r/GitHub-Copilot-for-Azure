# Availability Set

## Identity

| Field | Value |
|-------|-------|
| ARM Type | `Microsoft.Compute/availabilitySets` |
| Bicep API Version | `2025-04-01` |
| CAF Prefix | `avail` |

## Region Availability

**Category:** Foundational — available in all recommended and alternate Azure regions.

## Subtypes (kind)

Availability Set does not use `kind`.

## SKU Names

| SKU Name | Description |
|----------|-------------|
| `Aligned` | For managed disks — **required for modern deployments** |
| `Classic` | For unmanaged disks (legacy) — avoid for new deployments |

## Naming

| Constraint | Value |
|------------|-------|
| Min Length | 1 |
| Max Length | 80 |
| Allowed Characters | Alphanumerics, underscores, periods, and hyphens. Must start with alphanumeric. Must end with alphanumeric or underscore. |
| Scope | Resource group |
| Pattern | `avail-{workload}-{env}-{instance}` |
| Example | `avail-webserver-prod-001` |

## Required Properties (Bicep)

```bicep
resource availSet 'Microsoft.Compute/availabilitySets@2025-04-01' = {
  name: 'string'       // required
  location: 'string'   // required
  sku: {
    name: 'Aligned'    // required for managed disks
  }
  properties: {
    platformFaultDomainCount: 2   // recommended, max 3 (region-dependent)
    platformUpdateDomainCount: 5  // recommended, max 20
  }
}
```

## Key Properties

| Property | Description | Values |
|----------|-------------|--------|
| `sku.name` | Disk alignment | `Aligned` (managed disks), `Classic` (unmanaged) |
| `properties.platformFaultDomainCount` | Fault domains | Integer, max `3` (region-dependent) |
| `properties.platformUpdateDomainCount` | Update domains | Integer, default `5`, max `20` |
| `properties.proximityPlacementGroup` | Proximity group | Resource ID of proximity placement group |

## Pairing Constraints

When connected to other resources, enforce these rules:

| Paired With | Constraint |
|-------------|------------|
| **Virtual Machine** | VMs must be in the same resource group. Set `vm.properties.availabilitySet.id`. |
| **Availability Zones** | Cannot combine with zones — availability zones supersede availability sets for zone-redundant architectures. |
| **Managed Disks** | `sku.name` must be `Aligned` when VMs use managed disks. |
| **VM Scale Set** | A VM cannot be in both an availability set and a VMSS. |

## Child Resources

Availability Set has no Bicep child resource types.

## References

- [Bicep resource reference (2025-04-01)](https://learn.microsoft.com/azure/templates/microsoft.compute/availabilitysets?pivots=deployment-language-bicep)
- [Availability sets overview](https://learn.microsoft.com/azure/virtual-machines/availability-set-overview)
- [Azure naming rules — Compute](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules#microsoftcompute)

# Azure Resource Pairing Constraints

Property-specific configuration incompatibilities between Azure resources when paired together. Use this reference to avoid generating infrastructure plans with conflicting resource configurations.

## SKU Matching Rules

### Public IP + Load Balancer + VM

| Constraint | Detail |
|------------|--------|
| Public IP SKU must match Load Balancer SKU | Cannot mix Basic and Standard SKU resources |
| Standard Public IP = static allocation only | Dynamic allocation not available with Standard SKU |
| Standard LB blocks outbound by default | Requires outbound rules, NAT gateway, or instance-level public IPs |
| Standard LB requires NSG | Secure by default; inbound traffic blocked without NSG |
| Basic LB backend = single availability set or VMSS | Cannot mix VMs and VMSS; cannot span availability sets |
| Basic LB does not support availability zones | Must use Standard LB for zone-redundant deployments |
| Basic Public IP retiring Sep 2025 | All new gateways/LBs must use Standard SKU Public IP |

### Application Gateway v1 vs v2

| Constraint | Detail |
|------------|--------|
| Cannot mix v1 and v2 on same subnet | Separate subnets required for each SKU |
| Requires dedicated subnet | No other resources allowed in the App Gateway subnet |
| v1 does not support: autoscaling, zone redundancy, Key Vault integration, mTLS, Private Link, WAF custom rules, header rewrite | Must use v2 for these features |
| Private-only deployment (no public IP) requires feature registration | `EnableApplicationGatewayNetworkIsolation`; only Standard_v2/WAF_v2 |
| NSG port ranges differ by version | v1: 65503-65534, v2: 65200-65535 |
| Backend via private endpoint across global VNet peering | Traffic dropped; results in unhealthy status |
| WAF v2 cannot disable request buffering | Chunked file transfer requires path-rule workaround |

### VPN Gateway / ExpressRoute Gateway

| Constraint | Detail |
|------------|--------|
| Basic VPN Gateway SKU: no BGP, no IPv6, no RADIUS, no IKEv2 P2S, no ExpressRoute coexistence | Max 10 S2S tunnels; 1 tunnel for policy-based |
| ExpressRoute/VPN coexistence not supported with Basic SKU | Must use Generation1+ or AZ SKUs |
| GatewaySubnet must be /27 or larger | /26+ for 16 ExpressRoute circuits; /27+ for coexistence |
| NSGs on GatewaySubnet not supported | Associate an NSG → gateway stops functioning |
| UDR with 0.0.0.0/0 on GatewaySubnet not supported | ExpressRoute gateways require management controller access |
| BGP route propagation must be enabled on GatewaySubnet | Disabling → gateway non-functional |
| AZ SKU cannot be downgraded to non-AZ | One-way migration only |
| DNS Private Resolver in VNet with ExpressRoute gateway + wildcard rules | Causes management connectivity problems |

## Subnet Delegation & Isolation Conflicts

Different services require contradictory subnet configurations. A single subnet cannot serve multiple services with different delegation requirements.

| Service | Subnet Delegation | Min Size | Exclusive? | Notes |
|---------|-------------------|----------|------------|-------|
| App Service (VNet Integration) | `Microsoft.Web/serverFarms` | /28 (MPSJ: /26) | Yes | Cannot share subnet with private endpoints |
| App Service (Private Endpoint) | None | — | No | Must be a different subnet than VNet integration |
| Container Apps (Workload Profiles) | `Microsoft.App/environments` | /27 | Yes | Subnet MUST be delegated |
| Container Apps (Consumption-only) | MUST NOT delegate | /23 | Yes | Subnet must NOT be delegated to any service |
| AKS Node Pool | Cannot be delegated | Varies by CNI | Yes | Delegated subnets not allowed |
| Application Gateway | None | /26 recommended | Yes | Dedicated subnet; no other resources |
| VPN/ExpressRoute Gateway | None | /27 | Yes | Named `GatewaySubnet`; no NSGs |
| Azure Firewall | None | /26 | Yes | Named `AzureFirewallSubnet` |
| Azure Bastion | None | /26 | Yes | Named `AzureBastionSubnet` |

**Key conflict**: Container Apps Workload Profiles (requires delegation to `Microsoft.App/environments`) vs Container Apps Consumption-only (requires NO delegation) use opposite delegation rules.

**Key conflict**: App Service VNet Integration subnet ≠ App Service Private Endpoint subnet. These must be separate subnets.

## Storage Account + Consuming Service Restrictions

| Constraint | Detail |
|------------|--------|
| Azure Functions requires StorageV2 or Storage kind | BlobStorage, BlockBlobStorage, FileStorage kinds NOT supported (missing Queue/Table) |
| Functions Consumption plan cannot use network-secured storage | VNet-restricted storage only works with Premium/Dedicated plans |
| Functions with AZ enabled require zone-redundant storage (ZRS) | LRS/GRS not sufficient |
| Boot diagnostics cannot use Premium storage or ZRS | Causes `StorageAccountTypeNotSupported` on VM start |
| Storage SKU cannot change to Standard_ZRS, Premium_LRS, or Premium_ZRS after creation | Must be set at creation time |
| Geo-redundant failover blocked with conflicting features | Certain features prevent GRS/GZRS failover |
| CMK for storage requires Key Vault with soft-delete AND purge protection | Deployment fails without both enabled |
| CMK at storage account creation requires user-assigned managed identity | System-assigned identity only works for existing accounts |

## VM + Disk Type Pairing

| Constraint | Detail |
|------------|--------|
| Premium SSD requires compatible VM series | Not all VM sizes support Premium storage; check size docs |
| Ultra Disk requires `--ultra-ssd-enabled` flag on VM | Only available in specific regions/zones |
| Ultra Disk requires VM stop/deallocate to enable after creation | Cannot enable on running VM |
| Premium SSD v2 cannot be used as OS disk | Data disks only |
| Premium SSD v2 does not support host caching | ReadOnly/ReadWrite caching unavailable |
| Premium SSD v2 requires zonal VM deployment | Must specify availability zone |
| Cannot mix Premium SSD v2 with other storage types on SQL Server VMs | Must use uniform disk types |
| Azure CNI Overlay: no DCsv2-series VMs | Use DCasv5/DCadsv5 for confidential computing |

## Cosmos DB Configuration Incompatibilities

| Constraint | Detail |
|------------|--------|
| Multi-region writes + Strong consistency = NOT supported | System auto-defaults to single-region writes with Strong |
| Strong consistency with regions >5000 miles apart blocked by default | Requires support ticket to enable |
| Strong/Bounded Staleness reads cost 2× RU/s | Compared to Session/Consistent Prefix/Eventual |
| Serverless = single region only | Cannot add regions; cannot use multi-region writes |
| Serverless: no shared throughput databases | Error returned if attempted |
| Serverless: cannot provision throughput | Throughput auto-managed; settings return error |
| Merge partitions: not available for serverless or multi-region write accounts | Single-region provisioned throughput only |
| Private DNS zones: one record per DNS name | Multiple private endpoints in different regions need separate Private DNS Zones |

## SQL Database Tier vs Feature Matrix

| Constraint | Detail |
|------------|--------|
| Basic/Standard DTU tiers: no zone redundancy | Must use Premium, Business Critical, General Purpose (vCore), or Hyperscale |
| General Purpose zone redundancy: only in selected regions | Not all AZ regions support GP zone redundancy |
| Hyperscale zone redundancy: can only be set at creation | Cannot modify after provisioning; must recreate via copy/restore/geo-replica |
| Hyperscale elastic pool cannot be created from non-Hyperscale pool | Must add databases individually |
| Hyperscale elastic pool cannot be converted to non-Hyperscale | One-way only |
| Zone-redundant Hyperscale elastic pool requires databases with ZRS/GZRS backup storage | Cannot add LRS-backed databases |
| Named replicas cannot be added to Hyperscale elastic pools | Results in `UnsupportedReplicationOperation` |
| Failover group: zone-redundant → non-zone-redundant Hyperscale elastic pool | Fails silently; geo-secondary shows "Seeding 0%" |

## Redis Cache SKU Restrictions

| Constraint | Detail |
|------------|--------|
| VNet injection: Premium tier only | Must be set at creation; cannot inject existing cache into VNet |
| VNet injection + private endpoint = mutually exclusive | Cannot use both on same cache |
| Premium with clustering: max 1 private link | Non-clustered: up to 100 private links |
| Cannot scale down tiers | Enterprise → lower, Premium → Standard/Basic, Standard → Basic all blocked |
| Cannot scale between Enterprise and Enterprise Flash | Must create new |
| Cannot scale from Basic/Standard/Premium to Enterprise/Flash | Must create new |
| Passive geo-replication + private endpoint | Must unlink geo-replication first, add private link, then re-link |
| Firewall rules not available on Enterprise/Enterprise Flash | publicNetworkAccess flag also unsupported |
| Azure Lighthouse + VNet injection = not supported | Must use private links instead |
| Scale-out clustering: Premium/Enterprise only | Basic/Standard do not support it |

## AKS Networking Plugin Conflicts

| Constraint | Detail |
|------------|--------|
| Reserved CIDR ranges cannot be used | 169.254.0.0/16, 172.30.0.0/16, 172.31.0.0/16, 192.0.2.0/24 |
| AKS subnet cannot be a delegated subnet | Unlike App Service which requires delegation |
| CNI Overlay: no VM availability sets | Must use VMSS-based node pools |
| CNI Overlay: no virtual nodes | Use standard CNI for virtual node support |
| CNI Overlay: no DCsv2-series VMs | Use DCasv5/DCadsv5 instead |
| Kubenet retiring March 2028 | Must migrate to CNI Overlay |
| Kubenet not supported by Application Gateway for Containers | Must use CNI or CNI Overlay |
| Dual-stack CNI Overlay: no Azure/Calico network policies, no NAT gateway, no virtual nodes | IPv4+IPv6 disables these features |
| Pod CIDR must not overlap with cluster subnet, peered VNets, ExpressRoute, VPN | Overlapping causes SNAT/routing issues |

## Key Vault + CMK Pairing Rules

When any Azure service uses customer-managed keys (CMK) from Key Vault:

| Constraint | Detail |
|------------|--------|
| Key Vault must have soft-delete AND purge protection enabled | Required by: Storage, SQL, Cosmos DB, Backup, DICOM, and more |
| Key Vault firewall: must enable "Allow trusted Microsoft services" | Unless using private endpoints to Key Vault |
| Key must be RSA or RSA-HSM, 2048/3072/4096-bit | Other key types not supported for CMK |
| Key Vault and consuming service must be in same tenant | Cross-tenant CMK requires separate configuration |
| SQL TDE protector setup fails if KV soft-delete/purge-protection not enabled | Must enable both before configuring TDE |

## App Service Plan Feature Gates

| Feature | Minimum SKU Required |
|---------|----------------------|
| Private Endpoints | Basic |
| VNet Integration | Basic |
| Deployment Slots | Standard |
| Auto-scale | Standard |
| Custom Domains with SSL | Basic |
| Always On | Basic |
| Managed Identity | Free (but limited) |
| Isolated Compute | IsolatedV2 |

**Key conflict**: Free/Shared tiers use shared compute with no VNet integration, no private endpoints, no deployment slots.

## Container Apps Environment Type Conflicts

| Feature | Workload Profiles | Consumption-only |
|---------|-------------------|------------------|
| Subnet delegation | Required (`Microsoft.App/environments`) | Must NOT delegate |
| Min subnet size | /27 | /23 |
| UDR support | Yes | No |
| NAT Gateway egress | Yes | No |
| Private endpoints | Yes | No |
| Remote gateway peering | Yes | No |
| Network type change | Immutable after creation | Immutable after creation |
| IPv6 | Not supported | Not supported |
| VNet move (resource group/subscription) | Blocked while in use | Blocked while in use |

# Phase 1 — Connection Rule Research Checklist

> Each Resource Provider (RP) namespace is one batch. A sub-agent owns
> the batch end-to-end: it enumerates every resource type in the
> namespace from Microsoft Learn (`learn.microsoft.com/en-us/azure/templates/<namespace>`)
> + the ARM REST API specs at the latest stable API version, classifies
> every reference property (ownership vs connection), and writes
> `rules/per_provider/<Namespace>.json`. Tick the namespace below when
> the file is committed.
>
> **Privacy:** sub-agents see only resource type names, Microsoft docs,
> and ARM schemas. Never paste customer ARG data into a sub-agent prompt
> — `secrets_filter.assert_safe()` should be called on any string before
> handing it to a sub-agent.
>
> **Output schema:** see `TOPOLOGY_GRAPH_PROMPT.md` §4.3.

## Tier 1 — Core compute, networking, storage, identity (highest priority)

These cover the vast majority of resources in a typical tenant.

- [ ] `Microsoft.Compute` — VMs, VMSS, disks, images, galleries, snapshots, availability sets, proximity placement groups, restore points
- [ ] `Microsoft.Network` — VNets, subnets, NSGs, route tables, public IPs, NICs, load balancers, application gateways, firewalls, VPN/ExpressRoute, private endpoints, private DNS zones, Front Door, CDN, Bastion, NAT gateways, virtual WAN
- [ ] `Microsoft.Storage` — storage accounts, blob/file/queue/table services, containers, shares, lifecycle policies, encryption scopes, object replication
- [ ] `Microsoft.KeyVault` — vaults, managed HSMs, keys, secrets, certificates (control-plane refs only)
- [ ] `Microsoft.ManagedIdentity` — user-assigned identities, federated credentials
- [ ] `Microsoft.Authorization` — role assignments, role definitions, policy assignments, policy definitions, locks
- [ ] `Microsoft.Resources` — resource groups, deployments, tags, links

## Tier 2 — Application platforms

- [ ] `Microsoft.Web` — App Service plans, web apps, function apps, slots, custom domains, certificates, hybrid connections
- [ ] `Microsoft.App` — Container Apps, environments, jobs, managed environments certificates
- [ ] `Microsoft.ContainerService` — AKS managed clusters, agent pools, fleet, snapshots
- [ ] `Microsoft.ContainerRegistry` — registries, replications, webhooks, tasks, scope maps, tokens, pipelines
- [ ] `Microsoft.ContainerInstance` — container groups
- [ ] `Microsoft.ServiceFabric` — clusters, applications, services
- [ ] `Microsoft.ServiceFabricMesh` — applications, networks, gateways, secrets, volumes
- [ ] `Microsoft.Batch` — accounts, pools, applications

## Tier 3 — Data + databases

- [ ] `Microsoft.Sql` — servers, databases, elastic pools, managed instances, failover groups, virtual network rules, firewall rules
- [ ] `Microsoft.DBforPostgreSQL` — flexible servers, single servers, databases, configurations, firewall rules
- [ ] `Microsoft.DBforMySQL` — flexible servers, single servers, databases, configurations, firewall rules
- [ ] `Microsoft.DBforMariaDB` — servers, databases, configurations, firewall rules
- [ ] `Microsoft.DocumentDB` — Cosmos DB accounts, databases, containers, throughput
- [ ] `Microsoft.Cache` — Redis caches, firewall rules, linked servers, patch schedules
- [ ] `Microsoft.RedisEnterprise` — clusters, databases
- [ ] `Microsoft.DataFactory` — factories, pipelines, datasets, linked services, integration runtimes, triggers
- [ ] `Microsoft.Synapse` — workspaces, SQL pools, Spark pools, integration runtimes, kustoPools
- [ ] `Microsoft.Databricks` — workspaces, accessConnectors
- [ ] `Microsoft.Kusto` — clusters, databases, data connections
- [ ] `Microsoft.HDInsight` — clusters, applications
- [ ] `Microsoft.StreamAnalytics` — streamingjobs, clusters, inputs, outputs, transformations
- [ ] `Microsoft.AnalysisServices` — servers
- [ ] `Microsoft.PowerBIDedicated` — capacities

## Tier 4 — Messaging + integration

- [ ] `Microsoft.ServiceBus` — namespaces, queues, topics, subscriptions, rules, network rule sets, authorization rules, disaster recovery configs
- [ ] `Microsoft.EventHub` — namespaces, event hubs, consumer groups, network rule sets, authorization rules, disaster recovery configs, schema registries
- [ ] `Microsoft.EventGrid` — topics, system topics, domains, event subscriptions, partner topics, partner registrations
- [ ] `Microsoft.NotificationHubs` — namespaces, hubs
- [ ] `Microsoft.Relay` — namespaces, hybrid connections, WCF relays
- [ ] `Microsoft.Logic` — workflows, integration accounts, integration service environments
- [ ] `Microsoft.ApiManagement` — services, APIs, products, subscriptions, backends, named values, certificates, gateways

## Tier 5 — Observability + management

- [ ] `Microsoft.Insights` — components (App Insights), action groups, alert rules, autoscale settings, diagnostic settings, metric alerts, scheduled query rules, web tests, workbooks
- [ ] `Microsoft.OperationalInsights` — Log Analytics workspaces, saved searches, data sources, linked services, queries, query packs
- [ ] `Microsoft.OperationsManagement` — solutions, management associations, management configurations
- [ ] `Microsoft.AlertsManagement` — smart detector alert rules, action rules, prometheusRuleGroups
- [ ] `Microsoft.Monitor` — accounts, action groups
- [ ] `Microsoft.Dashboard` — Grafana managed instances
- [ ] `Microsoft.Automation` — automation accounts, runbooks, schedules, modules, variables, credentials, connections
- [ ] `Microsoft.RecoveryServices` — vaults, backup policies, protected items, replication
- [ ] `Microsoft.DataProtection` — backup vaults, backup instances, backup policies
- [ ] `Microsoft.DesktopVirtualization` — host pools, application groups, workspaces, scaling plans, session hosts

## Tier 6 — Security + governance

- [ ] `Microsoft.Security` — assessments, secure scores, alerts, automations, policies, workspace settings, defender plans
- [ ] `Microsoft.PolicyInsights` — remediations, attestations
- [ ] `Microsoft.Management` — management groups, subscriptions
- [ ] `Microsoft.Subscription` — aliases, billing
- [ ] `Microsoft.Billing` — billing accounts, billing profiles, invoice sections
- [ ] `Microsoft.CostManagement` — budgets, exports, views, alerts
- [ ] `Microsoft.Consumption` — budgets, marketplaces, usages

## Tier 7 — AI / ML / cognitive

- [ ] `Microsoft.CognitiveServices` — accounts (OpenAI, Vision, Speech, Language, Translator, etc.), deployments, commitments
- [ ] `Microsoft.MachineLearningServices` — workspaces, computes, datastores, datasets, models, endpoints, deployments, environments, codes, jobs, schedules, registries
- [ ] `Microsoft.Search` — search services, shared private link resources, private endpoint connections
- [ ] `Microsoft.Bot` — bot services, channels, connections
- [ ] `Microsoft.HealthcareApis` — workspaces, FHIR services, DICOM services, IoT Connectors

## Tier 8 — IoT + edge

- [ ] `Microsoft.Devices` — IoT Hub, provisioning services, certificates
- [ ] `Microsoft.IoTCentral` — apps
- [ ] `Microsoft.DigitalTwins` — instances, endpoints, time series database connections
- [ ] `Microsoft.IoTOperations` — instances, brokers, dataflows
- [ ] `Microsoft.DeviceUpdate` — accounts, instances
- [ ] `Microsoft.AzureSphere` — catalogs, products, device groups
- [ ] `Microsoft.AzureStackHCI` — clusters, arc settings, extensions
- [ ] `Microsoft.HybridCompute` — Arc-enabled servers, machine extensions, private link scopes, gateways
- [ ] `Microsoft.HybridContainerService` — provisioned clusters, agent pools, virtual networks
- [ ] `Microsoft.Kubernetes` — connected clusters
- [ ] `Microsoft.KubernetesConfiguration` — extensions, flux configurations, source controls

## Tier 9 — Migration + DR

- [ ] `Microsoft.Migrate` — assessment projects, migration projects, master sites
- [ ] `Microsoft.OffAzure` — VMware sites, Hyper-V sites, server sites, import sites
- [ ] `Microsoft.DataMigration` — services, projects, tasks
- [ ] `Microsoft.DataBox` — jobs
- [ ] `Microsoft.DataBoxEdge` — devices, orders, roles, shares, storage account credentials, triggers, users
- [ ] `Microsoft.StorageSync` — storage sync services, sync groups, cloud endpoints, server endpoints, registered servers
- [ ] `Microsoft.ImportExport` — jobs

## Tier 10 — Specialised + long tail

- [ ] `Microsoft.Maps` — accounts, creators
- [ ] `Microsoft.Media` — media services, assets, streaming endpoints, streaming policies, content key policies, jobs, transforms, live events, live outputs
- [ ] `Microsoft.SignalRService` — SignalR, WebPubSub
- [ ] `Microsoft.Communication` — communication services, email services, domains, phone numbers
- [ ] `Microsoft.Confluent` — organizations
- [ ] `Microsoft.Datadog` — monitors, tag rules, single sign-on configurations
- [ ] `Microsoft.Dynatrace` — monitors, tag rules, single sign-on configurations
- [ ] `Microsoft.Elastic` — monitors, tag rules
- [ ] `Microsoft.NewRelicObservability` — monitors
- [ ] `Microsoft.Logz` — monitors, single sign-on configurations
- [ ] `Microsoft.Workloads` — SAP virtual instances, monitors, providers
- [ ] `Microsoft.AVS` — Azure VMware Solution private clouds, clusters, datastores
- [ ] `Microsoft.Quantum` — workspaces
- [ ] `Microsoft.Blockchain` — blockchain members, watchers
- [ ] `Microsoft.Solutions` — managed applications, application definitions
- [ ] `Microsoft.CustomProviders` — resource providers, custom resources
- [ ] `Microsoft.Portal` — dashboards, tenant configurations (usually filtered out by `fetch_arg_raw.py`)
- [ ] `Microsoft.AAD` — domain services
- [ ] `Microsoft.GuestConfiguration` — guest configuration assignments
- [ ] `Microsoft.Maintenance` — maintenance configurations, configuration assignments, apply updates
- [ ] `Microsoft.ChangeAnalysis` — profile
- [ ] `Microsoft.Advisor` — recommendations, suppressions, configurations
- [ ] `Microsoft.Capacity` — reservation orders, reservations, savings plans
- [ ] `Microsoft.Compute/disks-extensions` — encryption sets (already covered under `Microsoft.Compute`; flag duplicates)

## Per-namespace sub-agent prompt template

```
You are researching Azure ARM resource references for one Resource
Provider namespace: <NAMESPACE>.

Inputs you may consult (no customer data):
- https://learn.microsoft.com/en-us/azure/templates/<lowercased-namespace>
- https://github.com/Azure/azure-rest-api-specs/tree/main/specification
- The bicepschema_get MCP tool (if available)

For every resource type in <NAMESPACE>:
  1. Use the latest stable API version.
  2. Walk every property (including nested objects and arrays) and find
     references to other resources. A "reference" is a property whose
     value is an ARM resource ID, an object {"id": "<arm-id>"}, an array
     of either, or an explicit ARM sub-resource path.
  3. For each reference, classify as:
       - ownership   — parent–child relationship via the ARM ID
                       hierarchy (e.g. servers/databases). Usually only
                       needed for cross-RG ownership or extension resources.
       - connection  — any other cross-resource link (e.g. disk →
                       managedBy → VM, NIC → ipConfigurations[].subnet).
  4. Choose a short human-readable label (≤ 24 chars, lowercase, no
     punctuation) that describes the relationship from source's POV.
  5. Record the rule in the schema below.

Output: rules/per_provider/<Namespace>.json (UTF-8, indent=2, sorted keys)

Schema (matches TOPOLOGY_GRAPH_PROMPT.md §4.3):
{
  "schemaVersion": 1,
  "rules": [
    {
      "sourceType": "Microsoft.Compute/disks",
      "propertyPath": "properties.managedBy",
      "valueShape": "resourceId",   // resourceId | array<resourceId> | object{id:resourceId} | armSubResource
      "cardinality": "0..1",        // 0..1 | 1..1 | 0..* | 1..*
      "targetType": "Microsoft.Compute/virtualMachines",
      "relationshipKind": "connection",
      "label": "managed by",
      "docsRef": "https://learn.microsoft.com/...",
      "notes": ""
    }
  ]
}

Rules:
- Compare resource types case-insensitively in the script, but write
  them in the canonical Microsoft casing here.
- Strip API versions from sourceType / targetType.
- For sub-types (e.g. Microsoft.Network/virtualNetworks/subnets), record
  the most specific type the property actually targets.
- Ownership via ID hierarchy is computed by the script — only record
  edge-case ownerships (extension resources, scoped resources, references
  that cross RG/sub boundaries).
- Don't record references to schema-only types like Microsoft.Resources/tags.
- If unsure, omit the rule. The registry should be high-precision.
```

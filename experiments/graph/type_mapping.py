"""ARM resource type → (human label, kebab icon key) mapping.

Used by `build_topology.py` to turn raw ARM types like
``Microsoft.Compute/virtualMachines`` into the (``type``, ``icon``) pair
that the graph-vis library expects on each node.

Decisions:
- Comparison is case-insensitive — ARG sometimes returns mixed casing.
- Unknown ARM types fall back to ``(<TitleCased last segment>, "resource")``
  so consumers can supply a generic icon under that key.
- Synthetic node types (``tenant``, ``resource-group``, ``subscription``)
  get explicit entries so the script doesn't need special-casing logic
  outside this table.

Add new entries freely — the table is intentionally append-only and
should grow over time as new resource types appear in customer ARG
dumps. Icon keys are kebab-case to match the graph-vis demo
(`virtual-machine`, not `virtualMachine`). Consumers supply their own
SVGs under those keys.
"""

from __future__ import annotations

# ARM type → (human label, icon key)
_MAP: dict[str, tuple[str, str]] = {
    # Synthetic / container nodes ---------------------------------------
    "tenant": ("Tenant", "tenant"),
    "subscription": ("Subscription", "subscription"),
    "resourcegroup": ("Resource Group", "resource-group"),

    # Microsoft.Compute --------------------------------------------------
    "microsoft.compute/virtualmachines": ("Virtual Machine", "virtual-machine"),
    "microsoft.compute/virtualmachinescalesets": ("Virtual Machine Scale Set", "vmss"),
    "microsoft.compute/virtualmachinescalesets/virtualmachines": ("VMSS Instance", "virtual-machine"),
    "microsoft.compute/disks": ("Managed Disk", "disk"),
    "microsoft.compute/snapshots": ("Disk Snapshot", "disk-snapshot"),
    "microsoft.compute/images": ("VM Image", "image"),
    "microsoft.compute/galleries": ("Compute Gallery", "compute-gallery"),
    "microsoft.compute/availabilitysets": ("Availability Set", "availability-set"),
    "microsoft.compute/diskencryptionsets": ("Disk Encryption Set", "disk-encryption-set"),
    "microsoft.compute/proximityplacementgroups": ("Proximity Placement Group", "ppg"),
    "microsoft.compute/sshpublickeys": ("SSH Public Key", "ssh-key"),
    "microsoft.compute/restorepointcollections": ("Restore Point Collection", "restore-point"),
    "microsoft.compute/capacityreservationgroups": ("Capacity Reservation Group", "capacity-reservation"),

    # Microsoft.Network --------------------------------------------------
    "microsoft.network/virtualnetworks": ("Virtual Network", "vnet"),
    "microsoft.network/virtualnetworks/subnets": ("Subnet", "subnet"),
    "microsoft.network/networkinterfaces": ("Network Interface", "nic"),
    "microsoft.network/networksecuritygroups": ("Network Security Group", "nsg"),
    "microsoft.network/publicipaddresses": ("Public IP", "public-ip"),
    "microsoft.network/publicipprefixes": ("Public IP Prefix", "public-ip-prefix"),
    "microsoft.network/loadbalancers": ("Load Balancer", "load-balancer"),
    "microsoft.network/applicationgateways": ("Application Gateway", "application-gateway"),
    "microsoft.network/applicationsecuritygroups": ("Application Security Group", "asg"),
    "microsoft.network/azurefirewalls": ("Azure Firewall", "firewall"),
    "microsoft.network/firewallpolicies": ("Firewall Policy", "firewall-policy"),
    "microsoft.network/routetables": ("Route Table", "route-table"),
    "microsoft.network/natgateways": ("NAT Gateway", "nat-gateway"),
    "microsoft.network/bastionhosts": ("Bastion Host", "bastion"),
    "microsoft.network/privateendpoints": ("Private Endpoint", "private-endpoint"),
    "microsoft.network/privatednszones": ("Private DNS Zone", "private-dns-zone"),
    "microsoft.network/dnszones": ("DNS Zone", "dns-zone"),
    "microsoft.network/virtualnetworkgateways": ("VNet Gateway", "vnet-gateway"),
    "microsoft.network/localnetworkgateways": ("Local Network Gateway", "local-network-gateway"),
    "microsoft.network/connections": ("VPN Connection", "vpn-connection"),
    "microsoft.network/virtualwans": ("Virtual WAN", "virtual-wan"),
    "microsoft.network/virtualhubs": ("Virtual Hub", "virtual-hub"),
    "microsoft.network/expressroutecircuits": ("ExpressRoute Circuit", "expressroute"),
    "microsoft.network/frontdoors": ("Front Door (classic)", "front-door"),
    "microsoft.network/profiles": ("Traffic Manager / CDN Profile", "profile"),
    "microsoft.network/trafficmanagerprofiles": ("Traffic Manager", "traffic-manager"),
    "microsoft.network/networkwatchers": ("Network Watcher", "network-watcher"),
    "microsoft.network/ddosprotectionplans": ("DDoS Protection Plan", "ddos-plan"),

    # Microsoft.Storage --------------------------------------------------
    "microsoft.storage/storageaccounts": ("Storage Account", "storage-account"),
    "microsoft.storage/storageaccounts/blobservices": ("Blob Service", "storage-account"),
    "microsoft.storage/storageaccounts/fileservices": ("File Service", "storage-account"),
    "microsoft.storage/storageaccounts/queueservices": ("Queue Service", "storage-account"),
    "microsoft.storage/storageaccounts/tableservices": ("Table Service", "storage-account"),

    # Microsoft.KeyVault -------------------------------------------------
    "microsoft.keyvault/vaults": ("Key Vault", "key-vault"),
    "microsoft.keyvault/managedhsms": ("Managed HSM", "managed-hsm"),

    # Microsoft.ManagedIdentity ------------------------------------------
    "microsoft.managedidentity/userassignedidentities": ("Managed Identity", "managed-identity"),

    # Microsoft.Web ------------------------------------------------------
    "microsoft.web/sites": ("App Service / Function App", "app-service"),
    "microsoft.web/sites/slots": ("App Service Slot", "app-service-slot"),
    "microsoft.web/serverfarms": ("App Service Plan", "app-service-plan"),
    "microsoft.web/staticsites": ("Static Web App", "static-web-app"),
    "microsoft.web/certificates": ("App Service Certificate", "certificate"),
    "microsoft.web/connections": ("API Connection", "api-connection"),

    # Microsoft.App (Container Apps) ------------------------------------
    "microsoft.app/containerapps": ("Container App", "container-app"),
    "microsoft.app/managedenvironments": ("Container Apps Environment", "container-apps-env"),
    "microsoft.app/jobs": ("Container Apps Job", "container-app-job"),

    # Containers ---------------------------------------------------------
    "microsoft.containerservice/managedclusters": ("AKS Cluster", "aks"),
    "microsoft.containerservice/managedclusters/agentpools": ("AKS Agent Pool", "aks"),
    "microsoft.containerservice/fleets": ("AKS Fleet", "aks"),
    "microsoft.containerregistry/registries": ("Container Registry", "container-registry"),
    "microsoft.containerinstance/containergroups": ("Container Group", "container-instance"),

    # Databases ----------------------------------------------------------
    "microsoft.sql/servers": ("SQL Server", "sql-server"),
    "microsoft.sql/servers/databases": ("SQL Database", "sql-database"),
    "microsoft.sql/servers/elasticpools": ("SQL Elastic Pool", "sql-elastic-pool"),
    "microsoft.sql/managedinstances": ("SQL Managed Instance", "sql-managed-instance"),
    "microsoft.sql/managedinstances/databases": ("Managed Instance DB", "sql-database"),
    "microsoft.dbforpostgresql/flexibleservers": ("PostgreSQL Flexible Server", "postgres"),
    "microsoft.dbforpostgresql/servers": ("PostgreSQL Server", "postgres"),
    "microsoft.dbformysql/flexibleservers": ("MySQL Flexible Server", "mysql"),
    "microsoft.dbformysql/servers": ("MySQL Server", "mysql"),
    "microsoft.dbformariadb/servers": ("MariaDB Server", "mariadb"),
    "microsoft.documentdb/databaseaccounts": ("Cosmos DB Account", "cosmos-db"),
    "microsoft.cache/redis": ("Redis Cache", "redis"),
    "microsoft.cache/redisenterprise": ("Redis Enterprise", "redis"),

    # Messaging ----------------------------------------------------------
    "microsoft.servicebus/namespaces": ("Service Bus Namespace", "service-bus"),
    "microsoft.servicebus/namespaces/queues": ("Service Bus Queue", "service-bus"),
    "microsoft.servicebus/namespaces/topics": ("Service Bus Topic", "service-bus"),
    "microsoft.eventhub/namespaces": ("Event Hubs Namespace", "event-hubs"),
    "microsoft.eventhub/namespaces/eventhubs": ("Event Hub", "event-hubs"),
    "microsoft.eventgrid/topics": ("Event Grid Topic", "event-grid"),
    "microsoft.eventgrid/systemtopics": ("Event Grid System Topic", "event-grid"),
    "microsoft.eventgrid/domains": ("Event Grid Domain", "event-grid"),
    "microsoft.signalrservice/signalr": ("SignalR Service", "signalr"),
    "microsoft.signalrservice/webpubsub": ("Web PubSub", "web-pubsub"),
    "microsoft.notificationhubs/namespaces": ("Notification Hubs Namespace", "notification-hubs"),
    "microsoft.relay/namespaces": ("Relay Namespace", "relay"),

    # Integration --------------------------------------------------------
    "microsoft.logic/workflows": ("Logic App", "logic-app"),
    "microsoft.apimanagement/service": ("API Management", "api-management"),
    "microsoft.datafactory/factories": ("Data Factory", "data-factory"),

    # AI / ML ------------------------------------------------------------
    "microsoft.cognitiveservices/accounts": ("Cognitive Services / OpenAI", "ai-services"),
    "microsoft.cognitiveservices/accounts/deployments": ("Model Deployment", "ai-services"),
    "microsoft.machinelearningservices/workspaces": ("ML Workspace", "ml-workspace"),
    "microsoft.search/searchservices": ("AI Search", "ai-search"),
    "microsoft.bot/botservices": ("Bot Service", "bot-service"),

    # Observability ------------------------------------------------------
    "microsoft.insights/components": ("Application Insights", "app-insights"),
    "microsoft.insights/actiongroups": ("Action Group", "action-group"),
    "microsoft.insights/metricalerts": ("Metric Alert", "alert"),
    "microsoft.insights/scheduledqueryrules": ("Scheduled Query Alert", "alert"),
    "microsoft.insights/autoscalesettings": ("Autoscale Setting", "autoscale"),
    "microsoft.insights/webtests": ("Availability Test", "availability-test"),
    "microsoft.operationalinsights/workspaces": ("Log Analytics Workspace", "log-analytics"),
    "microsoft.dashboard/grafana": ("Managed Grafana", "grafana"),
    "microsoft.monitor/accounts": ("Azure Monitor Workspace", "monitor-workspace"),

    # Recovery / Backup --------------------------------------------------
    "microsoft.recoveryservices/vaults": ("Recovery Services Vault", "recovery-vault"),
    "microsoft.dataprotection/backupvaults": ("Backup Vault", "backup-vault"),

    # Automation / Mgmt --------------------------------------------------
    "microsoft.automation/automationaccounts": ("Automation Account", "automation"),
    "microsoft.maintenance/maintenanceconfigurations": ("Maintenance Config", "maintenance"),

    # IoT / Hybrid -------------------------------------------------------
    "microsoft.devices/iothubs": ("IoT Hub", "iot-hub"),
    "microsoft.devices/provisioningservices": ("DPS", "iot-dps"),
    "microsoft.iotcentral/iotapps": ("IoT Central", "iot-central"),
    "microsoft.digitaltwins/digitaltwinsinstances": ("Digital Twins", "digital-twins"),
    "microsoft.hybridcompute/machines": ("Arc-enabled Server", "arc-server"),
    "microsoft.kubernetes/connectedclusters": ("Arc-enabled Kubernetes", "arc-k8s"),

    # Communication ------------------------------------------------------
    "microsoft.communication/communicationservices": ("Communication Service", "communication"),
}


def map_type(arm_type: str) -> tuple[str, str]:
    """Return ``(human_label, icon_key)`` for an ARM type.

    ``arm_type`` is matched case-insensitively. Unknown types fall back
    to ``(TitleCased last segment, "resource")``.
    """
    if not arm_type:
        return ("Unknown", "resource")
    key = arm_type.lower()
    if key in _MAP:
        return _MAP[key]

    # Fallback: title-case the last `/`-segment, with light camelCase split.
    last = arm_type.split("/")[-1] or arm_type
    # Split camelCase: "virtualMachines" → "virtual Machines"
    out_chars: list[str] = []
    for i, ch in enumerate(last):
        if i > 0 and ch.isupper() and last[i - 1].islower():
            out_chars.append(" ")
        out_chars.append(ch)
    label = "".join(out_chars).strip().title()
    return (label, "resource")

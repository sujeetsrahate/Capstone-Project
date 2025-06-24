provider "azurerm" {
  subscription_id = "1674f375-e996-4423-bd25-e0e8f6e76d13"
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.regions["centralus"].location
}

resource "azurerm_virtual_network" "vnet" {
  for_each            = var.regions
  name                = "vnet-${replace(each.key, " ", "")}"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = each.value.vnet_address_space
}

resource "azurerm_subnet" "public" {
  for_each             = var.regions
  name                 = "subnet-public-${replace(each.key, " ", "")}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = each.value.public_subnet_cidr
}

resource "azurerm_subnet" "private" {
  for_each             = var.regions
  name                 = "subnet-private-${replace(each.key, " ", "")}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = each.value.private_subnet_cidr
}

resource "azurerm_network_security_group" "public_subnet_nsg" {
  for_each            = var.regions
  name                = "nsg-${replace(each.key, " ", "")}-public"
  location            = each.value.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow_HTTP_Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_HTTPS_Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_8080_Inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_8081_Inbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "8081"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "dev"
    purpose     = "public-subnet-traffic-control"
  }
}

resource "azurerm_subnet_network_security_group_association" "public_subnet_nsg_association" {
  for_each                  = var.regions
  subnet_id                 = azurerm_subnet.public[each.key].id
  network_security_group_id = azurerm_network_security_group.public_subnet_nsg[each.key].id
}

resource "azurerm_kubernetes_cluster" "aks" {
  for_each            = var.regions
  name                = each.value.aks_cluster_name
  location            = each.value.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = each.value.dns_prefix
  kubernetes_version  = var.aks_kubernetes_version

  default_node_pool {
    name                         = "default"
    node_count                   = var.aks_node_count
    vm_size                      = each.value.vm_size
    vnet_subnet_id               = azurerm_subnet.private[each.key].id
    max_pods                     = 30
    temporary_name_for_rotation = "temp${random_string.suffix.result}"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin  = "azure"
    dns_service_ip  = cidrhost(cidrsubnet(each.value.vnet_address_space[0], 8, 200), 10)
    service_cidr    = cidrsubnet(each.value.vnet_address_space[0], 8, 200)
  }
}

resource "azurerm_public_ip" "aks_frontend_ip" {
  for_each            = var.regions
  name                = "${each.value.aks_cluster_name}-frontend-ip"
  resource_group_name = azurerm_kubernetes_cluster.aks[each.key].node_resource_group
  location            = each.value.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    purpose = "TrafficManagerEndpoint"
    region  = each.key
  }
}

resource "azurerm_traffic_manager_profile" "main" {
  name                   = "yogesh-ctm"
  resource_group_name    = azurerm_resource_group.main.name
  traffic_routing_method = "Performance"

  dns_config {
    relative_name = "yogesh-ctm"
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 8080
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }

  tags = {
    environment = "dev"
    project     = "MultiRegionAKS"
  }
}

resource "azurerm_traffic_manager_external_endpoint" "aks_endpoint" {
  for_each             = var.regions
  name                 = "${each.value.aks_cluster_name}-endpoint"
  profile_id           = azurerm_traffic_manager_profile.main.id
  weight               = 100
  target               = azurerm_public_ip.aks_frontend_ip[each.key].ip_address
  always_serve_enabled = true
  endpoint_location    = each.value.location
}

resource "azurerm_container_registry" "main_acr" {
  name                = "yogcregistry"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    environment = "dev"
    project     = "MultiRegionAKS"
  }
}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main_keyvault" {
  name                        = "yogeh-kvc-${random_string.suffix.result}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled    = false

  tags = {
    environment = "dev"
    purpose     = "application-secrets"
  }
}

resource "azurerm_key_vault_access_policy" "aks_keyvault_policy" {
  key_vault_id = azurerm_key_vault.main_keyvault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.aks["centralus"].identity[0].principal_id

  secret_permissions = [
    "Get"
  ]
}

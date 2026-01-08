# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  resource_suffix = random_string.suffix.result
  common_tags = merge(var.tags, {
    Environment = var.environment
  })
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# VM resources temporarily disabled
# resource "azurerm_public_ip" "vm_public_ip" {
#   name                = "${var.project_name}-vm-pip-${local.resource_suffix}"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
#   tags                = local.common_tags
# }

# resource "azurerm_network_interface" "vm_nic" {
#   name                = "${var.project_name}-vm-nic-${local.resource_suffix}"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   tags                = local.common_tags

#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.vm_subnet.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.vm_public_ip.id
#   }
# }

resource "azurerm_virtual_network" "vm_vnet" {
  name                = "${var.project_name}-vnet-${local.resource_suffix}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vm_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vm_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# resource "azurerm_linux_virtual_machine" "vm" {
#   name                  = "${var.project_name}-vm-${local.resource_suffix}"
#   resource_group_name   = azurerm_resource_group.main.name
#   location              = azurerm_resource_group.main.location
#   size                  = "Standard_D2s_v3"
#   admin_username        = var.vm_admin_username
#   admin_password        = var.vm_admin_password
#   disable_password_authentication = false
#   network_interface_ids = [azurerm_network_interface.vm_nic.id]
#   tags                  = local.common_tags
  
#   os_disk {
#     name                 = "${var.project_name}-vm-osdisk-${local.resource_suffix}"
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }
  
#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "0001-com-ubuntu-server-jammy"
#     sku       = "22_04-lts-gen2"
#     version   = "latest"
#   }
# }

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.project_name}-aks-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.aks_dns_prefix}-${local.resource_suffix}"
  tags                = local.common_tags

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_D2s_v6"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    service_cidr      = "10.1.0.0/16"
    dns_service_ip    = "10.1.0.10"
  }
}

# Grant AKS access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

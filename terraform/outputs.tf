output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

# VM outputs disabled - resources not provisioned
# output "vm_public_ip" {
#   description = "Public IP of the VM"
#   value       = azurerm_public_ip.vm_public_ip.ip_address
# }

# output "vm_name" {
#   description = "Name of the Linux VM"
#   value       = azurerm_linux_virtual_machine.vm.name
# }

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_fqdn" {
  description = "AKS cluster FQDN"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "aks_kubeconfig_command" {
  description = "Command to get AKS credentials"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}

output "acr_name" {
  description = "ACR name"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "ACR login server"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "ACR admin password"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}

output "acr_login_command" {
  description = "Command to login to ACR"
  value       = "az acr login --name ${azurerm_container_registry.acr.name}"
}

# PostgreSQL outputs disabled - resources not provisioned
# output "postgresql_server_name" {
#   description = "PostgreSQL server name"
#   value       = azurerm_postgresql_flexible_server.db.name
# }

# output "postgresql_fqdn" {
#   description = "PostgreSQL server FQDN"
#   value       = azurerm_postgresql_flexible_server.db.fqdn
# }

# output "postgresql_database_name" {
#   description = "PostgreSQL database name"
#   value       = azurerm_postgresql_flexible_server_database.db.name
# }

# output "postgresql_connection_string" {
#   description = "PostgreSQL connection string"
#   value       = "Server=${azurerm_postgresql_flexible_server.db.fqdn};Database=${azurerm_postgresql_flexible_server_database.db.name};Port=5432;User Id=${var.postgresql_admin_username};Password=${var.postgresql_admin_password};Ssl Mode=Require;"
#   sensitive   = true
# }

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.vm_vnet.name
}

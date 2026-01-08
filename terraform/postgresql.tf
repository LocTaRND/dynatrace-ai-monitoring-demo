# PostgreSQL resources temporarily disabled due to region restrictions
# Uncomment and adjust region/SKU as needed when restrictions are lifted

# # Generate random suffix for PostgreSQL server name
# resource "random_string" "postgresql_suffix" {
#   length  = 8
#   special = false
#   upper   = false
# }

# locals {
#   postgresql_server_name = var.postgresql_server_name != "" ? var.postgresql_server_name : "psql-${var.project_name}-${random_string.postgresql_suffix.result}"
# }

# resource "azurerm_postgresql_flexible_server" "db" {
#   name                   = local.postgresql_server_name
#   resource_group_name    = azurerm_resource_group.main.name
#   location               = azurerm_resource_group.main.location
#   administrator_login    = var.postgresql_admin_username
#   administrator_password = var.postgresql_admin_password
#   sku_name               = "B_Standard_B1ms"
#   storage_mb             = 32768
#   version                = "14"
#   zone                   = "1"
#   
#   # Simplified configuration for automatic provisioning
#   # High availability disabled for dev/demo environments
#   
#   backup_retention_days        = 7
#   geo_redundant_backup_enabled = false
#   
#   tags = merge(var.tags, {
#     Name = "PostgreSQL Flexible Server"
#   })
# }

# # Firewall rule to allow Azure services
# resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
#   name             = "AllowAzureServices"
#   server_id        = azurerm_postgresql_flexible_server.db.id
#   start_ip_address = "0.0.0.0"
#   end_ip_address   = "0.0.0.0"
# }

# # Optional: Allow all IPs for demo purposes (remove in production)
# resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
#   name             = "AllowAll"
#   server_id        = azurerm_postgresql_flexible_server.db.id
#   start_ip_address = "0.0.0.0"
#   end_ip_address   = "255.255.255.255"
# }

# resource "azurerm_postgresql_flexible_server_database" "db" {
#   name      = var.postgresql_db_name
#   server_id = azurerm_postgresql_flexible_server.db.id
#   charset   = "UTF8"
#   collation = "en_US.utf8"
# }

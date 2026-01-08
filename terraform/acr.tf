resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

resource "azurerm_container_registry" "acr" {
  name                = "${replace(var.project_name, "-", "")}acr${random_integer.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = true
  
  tags = merge(var.tags, {
    Name = "Container Registry"
  })
}

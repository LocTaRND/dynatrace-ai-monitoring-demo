# Terraform Azure Infrastructure for Dynatrace AI Monitoring Demo

This Terraform configuration automatically provisions Azure infrastructure including:
- Windows Virtual Machine
- Azure Kubernetes Service (AKS)
- Azure Container Registry (ACR) with AKS integration
- PostgreSQL Flexible Server with database
- Virtual Network with subnets

## Features

✅ **Automatic Resource Provisioning** - Default values for all variables
✅ **Unique Naming** - Auto-generated suffixes to avoid naming conflicts
✅ **Security** - Password validation and sensitive value protection
✅ **ACR-AKS Integration** - Automatic role assignment for container pulls
✅ **Network Isolation** - Separate subnets for VM and AKS
✅ **Tags Support** - Consistent tagging across all resources
✅ **Flexible Configuration** - Override defaults via terraform.tfvars

## Structure

- [provider.tf](provider.tf) - Provider and backend configuration
- [variables.tf](variables.tf) - Input variables with defaults
- [main.tf](main.tf) - VM, AKS, and networking resources
- [acr.tf](acr.tf) - Container Registry
- [postgresql.tf](postgresql.tf) - PostgreSQL Flexible Server
- [outputs.tf](outputs.tf) - Output values and helper commands
- [terraform.tfvars.example](terraform.tfvars.example) - Example variable values

## Quick Start

### Prerequisites
- Terraform >= 1.6.0
- Azure CLI installed and configured
- Azure subscription with appropriate permissions

### Steps

1. **Login to Azure**
   ```bash
   az login
   az account set --subscription <your-subscription-id>
   ```

2. **Create terraform.tfvars** (Optional - has defaults)
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your preferred values
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Review the Plan**
   ```bash
   terraform plan
   ```

5. **Apply Configuration**
   ```bash
   terraform apply
   ```

6. **Get Outputs**
   ```bash
   terraform output
   terraform output -json > outputs.json
   ```

## Minimum Required Configuration

If you prefer manual configuration, you only need to set passwords:

```hcl
# terraform.tfvars
vm_admin_password         = "YourSecurePassword123!"
postgresql_admin_password = "YourSecureDbPassword123!"
```

All other variables have sensible defaults!

## Key Outputs

After successful deployment, you'll get:

- **AKS Credentials Command**: Use to configure kubectl
- **ACR Login Command**: Use to push container images
- **VM Public IP**: For remote access
- **PostgreSQL Connection String**: For database connections

## Post-Deployment Commands

### Connect to AKS
```bash
az aks get-credentials --resource-group <rg-name> --name <aks-name>
kubectl get nodes
```

### Login to ACR
```bash
az acr login --name <acr-name>
```

### Access PostgreSQL
```bash
psql "Server=<fqdn>;Database=<db-name>;Port=5432;User Id=<username>;Password=<password>;Ssl Mode=Require;"
```

## Customization

### Change Location
```hcl
location = "westus2"
```

### Modify Tags
```hcl
tags = {
  Project     = "My Project"
  Environment = "production"
  Team        = "Platform"
}
```

### Adjust Resource Sizes
Edit the resource blocks in [main.tf](main.tf) to change VM or AKS node sizes.

## Security Notes

⚠️ **Important**: The PostgreSQL firewall is configured to allow all IPs for demo purposes. 
For production:
1. Remove or restrict the `azurerm_postgresql_flexible_server_firewall_rule.allow_all` resource
2. Configure VNet integration
3. Use private endpoints
4. Store secrets in Azure Key Vault

## Clean Up

To destroy all resources:
```bash
terraform destroy
```

## Troubleshooting

### Resource Naming Conflicts
- Resources use random suffixes to avoid conflicts
- If issues persist, run `terraform destroy` and `terraform apply` again

### AKS Network Plugin
- Uses Azure CNI for better integration
- Ensure your VNet has sufficient IP space

### PostgreSQL Connection Issues
- Check firewall rules
- Verify SSL mode is set to "Require"
- Ensure you're using the FQDN, not just the server name

## Notes

- **VM OS**: Ubuntu 22.04 LTS
- **AKS**: Single node with Standard_DS2_v2
- **PostgreSQL**: Version 14 with Basic SKU
- **ACR**: Standard SKU with admin access enabled

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = "51e4dde5-a3cf-4369-b57f-137b90f633f0"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "southcentralus"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "dynatrace-demo-rg"
}

variable "vm_admin_username" {
  description = "Admin username for VM"
  type        = string
  default     = "azureadmin"
}

variable "vm_admin_password" {
  description = "Admin password for VM"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.vm_admin_password) >= 12
    error_message = "VM admin password must be at least 12 characters long."
  }
}

variable "aks_dns_prefix" {
  description = "DNS prefix for AKS"
  type        = string
  default     = "dynatrace-demo"
}

variable "postgresql_server_name" {
  description = "PostgreSQL server name"
  type        = string
  default     = ""  # Will be auto-generated if empty
}

variable "postgresql_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "psqladmin"
}

variable "postgresql_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.postgresql_admin_password) >= 8
    error_message = "PostgreSQL admin password must be at least 8 characters long."
  }
}

variable "postgresql_db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "demoappdb"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "dynatrace-demo"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Dynatrace AI Monitoring"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

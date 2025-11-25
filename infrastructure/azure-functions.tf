terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-ai-functions-demo"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "brazilsouth"
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "acraifunctions"
}

variable "function_app_name" {
  description = "Name of the Function App"
  type        = string
  default     = "ai-functions-app"
}

variable "storage_account_name" {
  description = "Name of the Storage Account"
  type        = string
  default     = "staifunctions"
}

variable "azure_openai_endpoint" {
  description = "Azure OpenAI endpoint URL"
  type        = string
}

variable "azure_openai_deployment" {
  description = "Azure OpenAI deployment name"
  type        = string
  default     = "gpt-4"
}

variable "azure_openai_resource_group" {
  description = "Resource group containing Azure OpenAI resource"
  type        = string
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Storage Account for Function App
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# App Service Plan (Consumption/Elastic Premium)
resource "azurerm_service_plan" "main" {
  name                = "asp-${var.function_app_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan
}

# Linux Function App with Container
resource "azurerm_linux_function_app" "main" {
  name                = var.function_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false

    application_stack {
      docker {
        registry_url = "https://${azurerm_container_registry.acr.login_server}"
        image_name   = "ai-functions-app"
        image_tag    = "latest"
      }
    }

    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    "AZURE_OPENAI_ENDPOINT"    = var.azure_openai_endpoint
    "AZURE_OPENAI_DEPLOYMENT"  = var.azure_openai_deployment
    "DOCKER_REGISTRY_SERVER_URL"      = "https://${azurerm_container_registry.acr.login_server}"
    "DOCKER_REGISTRY_SERVER_USERNAME" = azurerm_container_registry.acr.admin_username
    "DOCKER_REGISTRY_SERVER_PASSWORD" = azurerm_container_registry.acr.admin_password
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "ai-${var.function_app_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  application_type    = "web"
}

# Get Azure OpenAI Resource
data "azurerm_cognitive_account" "openai" {
  name                = split("/", var.azure_openai_endpoint)[2]
  resource_group_name = var.azure_openai_resource_group
}

# Role Assignment - Cognitive Services OpenAI User
resource "azurerm_role_assignment" "openai_user" {
  scope                = data.azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Outputs
output "function_app_url" {
  value       = "https://${azurerm_linux_function_app.main.default_hostname}"
  description = "Function App URL"
}

output "function_app_identity_principal_id" {
  value       = azurerm_linux_function_app.main.identity[0].principal_id
  description = "Function App Managed Identity Principal ID"
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "ACR login server"
}

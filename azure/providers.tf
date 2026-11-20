terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Authenticate first with:  az login   (Azure CLI)
  # subscription_id is picked up from the CLI, or set ARM_SUBSCRIPTION_ID.
}

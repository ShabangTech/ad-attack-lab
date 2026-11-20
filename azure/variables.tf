variable "prefix" {
  description = "Name prefix for all resources."
  type        = string
  default     = "adlab"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "vm_size" {
  description = "VM size. B2s (2 vCPU / 4 GB) keeps credit use low."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Local admin on every VM."
  type        = string
  default     = "labadmin"
}

variable "admin_password" {
  description = "Admin password (12+ chars, complexity required by Azure). Set in terraform.tfvars."
  type        = string
  sensitive   = true
}

variable "my_ip" {
  description = "YOUR public IP in CIDR so only you can RDP/SSH in, e.g. 203.0.113.5/32. Find it: curl ifconfig.me"
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget alert threshold in USD."
  type        = number
  default     = 20
}

variable "budget_start" {
  description = "First day of the current month, RFC3339, e.g. 2026-11-01T00:00:00Z (Azure budgets require a month start)."
  type        = string
}

variable "budget_contact_email" {
  description = "Where the budget alert emails go."
  type        = string
}

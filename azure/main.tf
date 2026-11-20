# ---------------------------------------------------------------------------
# Resource group + a budget alert so you never blow through the student credit.
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "lab" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags = {
    project = "ad-attack-lab"
    note    = "intentionally-vulnerable-do-not-expose"
  }
}

# Emails you at 80% and 100% of the monthly budget (same idea as the AWS budget alarm).
resource "azurerm_consumption_budget_resource_group" "lab" {
  name              = "${var.prefix}-budget"
  resource_group_id = azurerm_resource_group.lab.id
  amount            = var.budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = var.budget_start # must be the first of a month
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = [var.budget_contact_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    contact_emails = [var.budget_contact_email]
  }
}

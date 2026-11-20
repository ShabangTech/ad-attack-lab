# ---------------------------------------------------------------------------
# Three VMs: a DC (10.10.10.10), a domain member (10.10.10.20), and an Ubuntu
# attacker (10.10.10.50). Public IPs are restricted by the NSG to your IP only.
#
# Terraform builds the INFRASTRUCTURE. The AD config (promote the DC, join the
# member, seed vulnerabilities) is done by hand after apply — see README.md.
# (Automating it with VM custom-script extensions is a good phase-2 upgrade.)
# ---------------------------------------------------------------------------

locals {
  hosts = {
    dc     = { private_ip = "10.10.10.10", os = "windows", computer = "DC01" }
    member = { private_ip = "10.10.10.20", os = "windows", computer = "MEMBER01" }
  }
}

# ---- Public IPs ----
resource "azurerm_public_ip" "host" {
  for_each            = local.hosts
  name                = "${var.prefix}-${each.key}-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "attacker" {
  name                = "${var.prefix}-attacker-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ---- NICs ----
resource "azurerm_network_interface" "host" {
  for_each            = local.hosts
  name                = "${var.prefix}-${each.key}-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  ip_configuration {
    name                          = "ipcfg"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip
    public_ip_address_id          = azurerm_public_ip.host[each.key].id
  }
}

resource "azurerm_network_interface" "attacker" {
  name                = "${var.prefix}-attacker-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  ip_configuration {
    name                          = "ipcfg"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.10.10.50"
    public_ip_address_id          = azurerm_public_ip.attacker.id
  }
}

# ---- Windows VMs: DC + member ----
resource "azurerm_windows_virtual_machine" "host" {
  for_each              = local.hosts
  name                  = "${var.prefix}-${each.key}"
  computer_name         = each.value.computer
  resource_group_name   = azurerm_resource_group.lab.name
  location              = azurerm_resource_group.lab.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.host[each.key].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# ---- Ubuntu attacker (install impacket/netexec after first boot; see README) ----
# Want a real Kali image instead? Azure has one on the Marketplace (publisher
# "kali-linux"). It needs a one-time `azurerm_marketplace_agreement` + a `plan`
# block on the VM. Ubuntu keeps this apply frictionless; swap later if you like.
resource "azurerm_linux_virtual_machine" "attacker" {
  name                            = "${var.prefix}-attacker"
  computer_name                   = "attacker"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false # SSH key is better; password keeps setup simple
  network_interface_ids           = [azurerm_network_interface.attacker.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

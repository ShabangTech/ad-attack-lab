# ---------------------------------------------------------------------------
# One isolated VNet. The DC is at 10.10.10.10 and is the DNS server for the
# domain, so the member and attacker resolve lab.local through it.
# The NSG allows RDP/SSH ONLY from your IP, and free traffic inside the VNet.
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "lab" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.10.0.0/16"]
  dns_servers         = ["10.10.10.10", "168.63.129.16"] # DC first, then Azure's resolver
}

resource "azurerm_subnet" "lab" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.10.0/24"]
}

resource "azurerm_network_security_group" "lab" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  # RDP to the Windows boxes — your IP only.
  security_rule {
    name                       = "RDP-from-me"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.my_ip
    destination_address_prefix = "*"
  }

  # SSH to the attacker box — your IP only.
  security_rule {
    name                       = "SSH-from-me"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip
    destination_address_prefix = "*"
  }

  # Everything inside the VNet can talk (AD, SMB, Kerberos, your attacks).
  security_rule {
    name                       = "Allow-intra-vnet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
  # Azure's default rules deny all other inbound from the internet.
}

resource "azurerm_subnet_network_security_group_association" "lab" {
  subnet_id                 = azurerm_subnet.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

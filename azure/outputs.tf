output "dc_public_ip" {
  value = azurerm_public_ip.host["dc"].ip_address
}

output "member_public_ip" {
  value = azurerm_public_ip.host["member"].ip_address
}

output "attacker_public_ip" {
  value = azurerm_public_ip.attacker.ip_address
}

output "private_ips" {
  value = {
    dc       = "10.10.10.10"
    member   = "10.10.10.20"
    attacker = "10.10.10.50"
  }
}

output "next_steps" {
  value = "RDP to dc_public_ip, promote to lab.local (see README), join MEMBER01, run vulnerable-AD. SSH to attacker_public_ip and install netexec + impacket."
}

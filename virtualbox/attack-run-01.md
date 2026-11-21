# Attack Run 01 — lab.local (local VirtualBox)

First full run against the single-DC VirtualBox build. Engagement-style log of
what worked, what didn't, and the lessons. Credentials/hashes are redacted — this
repo is public.

> **Acronyms:** DC = Domain Controller · SPN = Service Principal Name · TGS =
> Ticket-Granting Service ticket · AS-REP = Authentication Service Response ·
> NTLM = NT LAN Manager hash · ACL = Access Control List.

## Lab state

| Host | IP | Role |
|---|---|---|
| DC01 (`WIN-…`) | `10.10.10.10` | Windows Server 2022 DC, `lab.local`, seeded with vulnad |
| Kali | `10.10.10.50` | attacker |

Network: VirtualBox **Internal Network** `adlab`, static IPs, **no DHCP, no
internet** (deliberately isolated). Kali DNS → the DC (`10.10.10.10`).

## 1. Recon

```bash
nxc smb 10.10.10.10
```
Returned: `Windows Server 2022 Build 20348`, `domain: lab.local`, `signing: True`,
**`Null Auth: True`** — the DC allows anonymous SMB sessions (finding #1).

## 2. Anonymous enumeration — blocked

```bash
nxc smb 10.10.10.10 -u '' -p '' --users      # authenticates, returns no users
nxc smb 10.10.10.10 -u '' -p '' --rid-brute  # STATUS_ACCESS_DENIED
```
Server 2022 lets a null session connect but **blocks account enumeration** (SAMR/
LSAD restricted by default). This is correct hardening — in a real engagement it
means you need an **initial foothold credential** to proceed. (OSCP typically
provides one.)

## 3. Authenticated enumeration

With a foothold credential:
```bash
nxc smb 10.10.10.10 -u <user> -p '<pass>' --users
```
Enumerated **53 domain users**.

## 4. Finding: passwords in object descriptions

Two accounts had their **passwords stored in the AD `description` field** —
readable by any authenticated user:
```
<user_a>   Description: "User Password <REDACTED>"
<user_b>   Description: "User Password <REDACTED>"
```
A genuine real-world finding (admins stash passwords in notes). Two free
credentials, no cracking. **MITRE T1552.001 — Unsecured Credentials: Credentials
In Files/Objects.**

## 5. AS-REP roasting

Users with Kerberos **pre-auth disabled** (`UF_DONT_REQUIRE_PREAUTH`) let anyone
request an AS-REP encrypted with their password hash — crackable offline, no
password needed:
```bash
impacket-GetNPUsers lab.local/ -dc-ip 10.10.10.10 -usersfile users.txt -no-pass -format hashcat -outputfile asrep.hash
```
Pulled **2 `$krb5asrep$` hashes**. **MITRE T1558.004.**

## 6. Kerberoasting — no targets

```bash
impacket-GetUserSPNs lab.local/<user>:'<pass>' -dc-ip 10.10.10.10 -request -outputfile kerb.hash
```
Returned nothing — **no SPN accounts** reachable by this user, so nothing to
roast. (Fix for next run: seed an SPN account on the DC, e.g.
`setspn -a HTTP/web01.lab.local <svc-account>`.) **MITRE T1558.003.**

## 7. Cracking — blocked by isolation

`hashcat` not installed, and `apt` can't reach the internet (isolated network),
and the `wordlists` package (rockyou) wasn't present either. Crack deferred.

## Lessons

1. **Stage the attacker box before isolating it.** Install `hashcat`, `john`,
   `wordlists`, `seclists`, impacket, netexec *while Kali still has internet*,
   then move it to the isolated network. Added to the purplerain setup script.
2. **Server 2022 blocks anonymous enumeration** — plan for a provided/looted
   foothold cred, don't rely on null-session user lists.
3. **Check `description` fields first** — cheapest possible win.
4. **Snapshot the DC after seeding vulns** so the domain resets to a known state.

## Next run

- Add SPN + weak-password service account → Kerberoast → crack
- Stand up MEMBER01 → lateral movement (PtH / PsExec) — see `two-host-lab.md`
- DCSync with a privileged account
- Ship DC Security log to the SOC and build detections — see `../detections/`

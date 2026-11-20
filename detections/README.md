# Detections (purple team)

Every attack in this lab leaves a signal. Shipping the DC's Security log to a SOC
(your CloudWatch pipeline, or Azure's **Microsoft Sentinel**) lets you build the
detection *and* the attack — the standout half most people skip.

| Attack | Signal | Windows Event | MITRE |
|---|---|---|---|
| Kerberoasting | Service ticket (TGS) requested with **RC4** encryption (type `0x17`) | **4769** | T1558.003 |
| AS-REP roasting | TGT requested for an account with **pre-auth not required** | **4768** | T1558.004 |
| DCSync | Directory replication (`DS-Replication-Get-Changes`) from a **non-DC** account | **4662** | T1003.006 |
| Pass-the-Hash / lateral | NTLM logon (type 3) from an unexpected host | **4624 / 4776** | T1550.002, T1021 |

## Notes

- **4769 + RC4** is the classic Kerberoasting flag: modern tickets use AES, so a
  burst of RC4 TGS requests for SPN accounts stands out. Watch for false positives
  from legacy apps.
- **DCSync** is high-fidelity: replication rights belong to DCs, so `4662` with the
  replication GUID from a user account is almost always malicious.
- To wire this into your existing AWS SOC, ship the DC Security log to
  `/hsoc/windows/security` (same CloudWatch agent config as your laptop) and add
  metric-filter alarms, mirroring your H01/P-series detections.

*(Rules/queries to be added as you validate each one against the attacks.)*

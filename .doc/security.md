# macOS Security (`modules/macos/security/`)

Bevat netwerk- en security-tooling:
- `networkmaster` (`NETWORK/`): Netwerkscans, `nmap`-formatting, geotrace, port-scans.
- `cybermaster` (`CYBER/`): Recon, mail-analyse, risk-scoring en rapportage.
- `intelmaster` (`INTEL/`): Threat-intelligence analyse en lijstenbeheer.

### Vereiste Dependencies
`nmap`, `python3`, `requests`, `beautifulsoup4`

### Gebruik
```bash
./master security networkmaster
./master security cybermaster
./master security intelmaster
```

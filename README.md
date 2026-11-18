# Scripter Hub

Centrale, platformbewuste TUI- en CLI-hub voor **Universal**, **macOS** en **QNAP / Linux** tooling.

## Architectuur

```text
.
├── scripter                # Centrale hub (TUI-menu, +module routing, --persist)
├── .core/
│   ├── os_detect.sh        # OS-, architectuur- en package-managerdetectie
│   ├── ui.sh               # Centrale TUI-bibliotheek (kleuren, headers, badges)
│   ├── deps.sh             # Dependency & Update Center (binaries + Python libs)
│   └── persist.sh          # OS-specifieke shell-persistentie
├── modules/
│   ├── common/             # [UNIVERSAL] Cross-platform modules
│   ├── macos/              # [macOS] macsystem, security, media
│   └── qnap/               # [QNAP / Linux] Container Station, shares, Entware
└── .doc/                   # Gedetailleerde per-module naslagwerken
```

## Platform-secties

1. **CORE / UNIVERSAL `[UNIVERSAL]`**: `gitmaster`, `containermaster`, `dbmaster`, `datamaster`, `textmaster`, `filemaster`, `webmaster`
2. **macOS WORKSTATION `[macOS]`**: `macmaster`, `networkmaster`, `cybermaster`, `intelmaster`, `audiomaster`, `videomaster`, `imagemaster`, `karaokemaster`, `rename_ebooks`
3. **QNAP NAS & LINUX SERVER `[QNAP / Linux]`**: `qnapmaster` (Container Station, `@Recycle` cleanup, Entware `opkg` updates)

## CLI Gebruik & `+`-Switches

```bash
./scripter                        # Interactief TUI-hoofdmenu
./scripter -h | --help            # Toon alle beschikbare +switches
./scripter --persist              # Configureer OS-specifieke shell-persistentie

# Directe module-aanroep (+modulenaam of --modulenaam)
./scripter +gitmaster             # Open Git Master menu
./scripter +git status            # Geef subcommando door aan module
./scripter +deps status           # Controleer binaries & Python packages
./scripter +deps install          # Installeer ontbrekende dependencies
./scripter +macmaster             # Open macOS systeembeheer
./scripter +networkmaster         # Start networkmaster
./scripter +qnap containers       # Toon QNAP Container Station status
```

## OS-Specifieke Persistentie (`--persist`)

Via menu-optie **`P) Make Persistent`** of `./scripter --persist`:
- **macOS**: Voegt een idempotent `# >>> scripter-hub >>>` blok toe aan `~/.zshrc` (en `~/.bash_profile` indien aanwezig).
- **QNAP NAS**: Schrijft naar Entware `/opt/etc/profile` (indien beschrijfbaar), `~/.profile`, en maakt een symlink `/opt/bin/scripter`.
- **Linux**: Schrijft naar `~/.bashrc` / `~/.profile` en maakt indien mogelijk een symlink `/usr/local/bin/scripter`.

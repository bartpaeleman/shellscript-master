# Shellscripts Master Hub

Centrale, platformbewuste CLI- en menu-hub voor macOS- en QNAP-beheer, media-automatisering en security-tooling.

## Architectuur

```text
.
├── master                  # Centrale hub (interactief menu + CLI-routing)
├── .core/
│   ├── os_detect.sh        # OS-, architectuur- en package-managerdetectie
│   └── deps.sh             # Dependency & Update Center (binaries + Python libs)
├── modules/
│   ├── macos/
│   │   ├── macsystem/      # crontab_manager, zshrc_editor, auto_cleanup, clear_cache, uninstall
│   │   ├── security/       # networkmaster, cybermaster, intelmaster
│   │   └── media/          # audiomaster, videomaster, imagemaster, karaokemaster, rename_ebooks
│   └── qnap/
│       └── qnapmaster.sh   # Container Station status, share-cleanup, Entware updates
└── .doc/                   # Gedetailleerde per-module naslagwerken
```

## OS-Detectie Mechanisme

`.core/os_detect.sh` detecteert automatisch:
- `OS_TYPE`: `macOS` (`Darwin`), `QNAP` (`/etc/config/uLinux.conf`, `/share/CACHEDEV1_DATA` of `/sbin/getcfg`), `Linux` of `Unknown`.
- `ARCH`: Systeemarchitectuur (`arm64`, `x86_64`, etc.).
- `PKG_MGR`: Beschikbare package manager (`brew`, `opkg`, `apt`, `dnf`, `apk`).

Standaard toont `./master` **alleen de modules die relevant zijn voor het gedetecteerde OS**. Gebruik `--all` om alle platformmodules weer te geven.

## Installatie & Activatie

```bash
chmod +x master .core/*.sh modules/qnap/qnapmaster.sh
./master deps status    # Controleer ontbrekende tools
./master deps install   # Installeer ontbrekende binaries & Python packages
```

## CLI Gebruik & Flags

```bash
./master                  # Interactief hoofdmenu (OS-gefilterd)
./master --all            # Interactief hoofdmenu met alle platformen
./master -h | --help      # Toon CLI-hulp

# Directe routing
./master deps status
./master deps install
./master deps update
./master macsystem
./master security networkmaster
./master media audiomaster
./master qnap containers
```

## Documentatie per Module

- [Core & Dependency Center](.doc/core.md)
- [macOS System (`macsystem`)](.doc/macsystem.md)
- [macOS Security (`security`)](.doc/security.md)
- [macOS Media (`media`)](.doc/media.md)
- [QNAP Hooks (`qnap`)](.doc/qnap.md)

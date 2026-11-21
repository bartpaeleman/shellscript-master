# Changelog

## [1.2.0] - 2026-11-21

### Added
- **`gitmaster` (`Apply .patch` / `patch` / `apply-patch`)**: Cross-platform Antigravity Cloud `.patch` selector met 3-way apply fallback, branch-kiezer, push naar `origin` en automatische patch-cleanup (QNAP BusyBox + macOS BSD compatibel).

## [1.1.0] - 2026-11-18

### Added & Changed
- **Hub (`./scripter`)**: Hernoemd van `master` naar `scripter` met `+modulenaam`/`--modulenaam` routing, stille `_startup_precheck()`, en platform-secties (`CORE / UNIVERSAL`, `macOS WORKSTATION`, `QNAP NAS & LINUX SERVER`).
- **Core (`.core/`)**: Centrale TUI-bibliotheek (`ui.sh`), OS-specifieke shell-persistentie (`persist.sh` / `--persist`), en portable OS-wrappers (`os_sed_inplace`, `os_readlink_f`).
- **Universal Modules (`modules/common/`)**: 7 cross-platform modules toegevoegd (`gitmaster`, `containermaster`, `dbmaster`, `datamaster`, `textmaster`, `filemaster`, `webmaster`).

## [1.0.0] - 2026-11-18

### Added
- **Centrale Hub (`./master`)**: Platformbewust interactief menu en directe CLI-routing (`./master deps`, `./master macsystem`, `./master security`, `./master media`, `./master qnap`), inclusief `--all` flag.
- **Core (`.core/`)**:
  - `os_detect.sh`: Automatische detectie van `OS_TYPE` (`macOS`, `QNAP`, `Linux`, `Unknown`), `ARCH`, `PKG_MGR` en `IS_ROOT`.
  - `deps.sh`: Dependency & Update Center voor CLI-binaries (`git`, `curl`, `jq`, `python3`, `ffmpeg`, `nmap`, `exiftool`, `magick`, `yt-dlp`) en Python-packages (`mutagen`, `pillow`, `pypdf`, `requests`, `beautifulsoup4`).
- **macOS Modules (`modules/macos/`)**: Gemigreerd vanuit `macscripts/`:
  - `macsystem/`: `macmanager.sh`, `crontab_manager.sh`, `zshrc_editor.sh`, `auto_cleanup.sh`, `clear_cache.sh`, `uninstall.sh`.
  - `security/`: `networkmaster`, `cybermaster`, `intelmaster`.
  - `media/`: `audiomaster`, `videomaster`, `imagemaster`, `karaokemaster`, `rename_ebooks`.
- **QNAP Hooks (`modules/qnap/qnapmaster.sh`)**: Container Station status, `@Recycle`/`.@__thumb` share-cleanup en Entware (`opkg`) updates.
- **Documentatie**: `README.md` en per-module naslagwerken in `.doc/`.

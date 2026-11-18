# Core & Dependency Center (`.core/`)

## `.core/os_detect.sh`
Exporteert:
- `OS_TYPE`: `macOS`, `QNAP`, `Linux`, `Unknown`
- `ARCH`: `uname -m`
- `PKG_MGR`: `brew`, `opkg`, `apt`, `dnf`, `apk`, `none`
- `IS_ROOT`: `true` of `false`

## `.core/deps.sh`
Beheert alle vereiste CLI-binaries (`git`, `curl`, `jq`, `python3`, `ffmpeg`, `nmap`, `exiftool`, `magick`, `yt-dlp`) en Python-packages (`mutagen`, `pillow`, `pypdf`, `requests`, `beautifulsoup4`).

### CLI
```bash
./master deps status
./master deps install
./master deps update
./master deps menu
```

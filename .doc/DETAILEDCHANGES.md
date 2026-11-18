# Detailed Changes

## Unreleased (`shellscripts` branch)

### Core & Standards
- **AGENTS.md**: Added Git sync policy, layered documentation (`CHANGELOG.md` vs `.doc/DETAILEDCHANGES.md`), release-locking, silent startup pre-check, OS-parity/anti-regression rules, and mandatory pre-commit verification.
- **`.core/os_detect.sh`**: Added portable OS-abstraction wrappers (`os_sed_inplace`, `os_readlink_f`, `os_is_macos`, `os_is_qnap`, `os_is_linux`).
- **`scripter`**: Added `_startup_precheck()` for automatic `chmod +x` recovery, `.config/.env` initialization from `.config/.env.example`, and `.dep/.venv` directory/venv check.

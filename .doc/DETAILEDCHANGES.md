# Detailed Changes

## Unreleased (`shellscripts` branch)

### Core & Standards
- **AGENTS.md**: Added Git sync policy, layered documentation (`CHANGELOG.md` vs `.doc/DETAILEDCHANGES.md`), release-locking, silent startup pre-check, OS-parity/anti-regression rules, and mandatory pre-commit verification.
- **`.core/os_detect.sh`**: Added portable OS-abstraction wrappers (`os_sed_inplace`, `os_readlink_f`, `os_is_macos`, `os_is_qnap`, `os_is_linux`).
- **`scripter`**: Added `_startup_precheck()` for automatic `chmod +x` recovery, `.config/.env` initialization from `.config/.env.example`, and `.dep/.venv` directory/venv check.

### Universal Core Modules (`modules/common/`)
- Added unified, portable (Bash 3.2+ & GNU/Linux/QNAP) entrypoints using `.core/ui.sh` and `.core/os_detect.sh`:
  - `git/gitmaster.sh` (`+gitmaster` / `+git`)
  - `container/containermaster.sh` (`+containermaster` / `+container`)
  - `db/dbmaster.sh` (`+dbmaster` / `+db`)
  - `data/datamaster.sh` (`+datamaster` / `+data`)
  - `text/textmaster.sh` (`+textmaster` / `+text`)
  - `file/filemaster.sh` (`+filemaster` / `+file`)
  - `web/webmaster.sh` (`+webmaster` / `+web`)

### Persistence Fix (`.core/persist.sh` & `scripter`)
- Added explicit error reporting in `_upsert_rc_block()` when an RC file is not writable, plus clear `Added`/`Updated` status and block preview.
- Added `Press [Enter] to return to menu...` pause in `scripter` after `P) Make Persistent` so the output no longer flashes away.
- Verified `./scripter --persist` on macOS (`~/.zshrc` updated cleanly without duplicates).

### TUI Screen Reset & Full `gitmaster` Parity
- **`.core/ui.sh` & `scripter`**: Added `ui_clear_screen()` (`\033[2J\033[3J\033[H` with `clear` fallback) and `ui_pause()` so every menu transition starts cleanly at the top of the terminal.
- **`modules/common/git/gitmaster.sh`**: Restored all 23 options across Categories A–D (Info & Inspectie, Branching & Development, Cleanup & Maintenance, Fix & Emergency Recovery) with Bash 3.2+ & QNAP Linux compatibility and full CLI subcommand routing.

### Container Master (`modules/common/container/`)
- Restored all 10 functions (`list`, `logs` with `SIGINT` trap, `inspect` via `inspect_viewer.py`, `start`, `stop`, `restart`, `shell` with `/bin/bash` -> `/bin/sh` fallback, `create`/`stack`, `rm` with `--force`, `prune`).
- Added QNAP Container Station PATH support (`/share/CACHEDEV1_DATA/.qpkg/container-station/bin`) and macOS/Linux Docker daemon check.

### Audit & Restoration of `dbmaster`, `filemaster`, `datamaster`, `textmaster`, `webmaster`
- **`dbmaster`**: Added `mysqldump` `.sql.gz` backup and `db_stats.py` analyzer.
- **`filemaster`**: Restored bulk Python regex rename (with preview), `mkdirs` from file, `.zip`/`.tar.gz` archive, `.DS_Store`/empty-dir/MD5-duplicate cleanup, `compare`, `sync`, `csv` export, and `fzf` finder.
- **`datamaster`**: Restored ASCII CSV `table`, `delimiter` converter, `convert` (CSV/JSON/XML/YAML), `normalize`, and `deps` check (`pandas`, `pyyaml`).
- **`textmaster`**: Restored `text_stats.py`, `replace` (with `.bak` + `os_sed_inplace`), `diff`, `merge`, and `case` conversion.
- **`webmaster`**: Restored `scaffold` (assets, includes, config, `index.php`, `.gitignore`) and `generate_readme.py`.

### Strict OS Filtering (`scripter`)
- Filtered `interactive_menu()` and `show_help()` by `OS_TYPE` (`macOS` hides QNAP, `QNAP` hides macOS, `Linux` hides both) with `--all` override.
- Added `--force` guard for OS-mismatched CLI calls (e.g. `./scripter +qnapmaster` on macOS).

### Safe Prompts & Sync/Pull UX (`.core/ui.sh` & `gitmaster`)
- Added `ui_cancel_msg()`, `ui_prompt_input()`, and `ui_confirm_action()` to `.core/ui.sh` with universal `0`/`q`/`cancel` escape.
- Updated `gitmaster` Option 8 (`Sync / Pull`) with clear Standard Pull `[Default]` vs Rebase Pull descriptions and `0) Cancel`.
- Updated `gitmaster` interactive prompts and branch lists with `0) Cancel / Terug` and `[Cancelled] Geen wijzigingen uitgevoerd.`.

### Functional Menu Grouping & Dynamic Numbering (`scripter` & `.core/os_detect.sh`)
- Grouped `scripter` menu and `--help` functionally (`DEVELOPMENT & OPS`, `SYSTEEMBEHEER`, `BESTANDS- & DATABEHEER`, `NETWERK & CYBERSECURITY`, `MEDIA & MULTIMEDIA`, `UTILITIES & ONDERHOUD`) with `[UNI]`, `[MAC]`, `[QNAP]` labels.
- Added dynamic category (`cat_idx`) and sequential item (`item_idx`) numbering so empty categories are omitted without gaps.
- Updated `.core/os_detect.sh` to respect `OS_TYPE` environment overrides for simulation/testing.

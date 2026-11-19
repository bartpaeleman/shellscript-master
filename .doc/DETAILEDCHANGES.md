# Detailed Changes

## Unreleased (`shellscripts` branch)

### `cybermaster` & `intelmaster` Central `.dep/.venv` Migration & `threatctx` Pipeline Fix
- **`.dep/requirements.txt` & `.core/deps.sh`**: Created central `.dep/requirements.txt` combining `CYBER/requirements.txt` and `INTEL`/`core` Python dependencies (`requests`, `beautifulsoup4`, `rich`, `typer`, `httpx`, `scapy`, `mail-parser`, `pydantic`, `pyyaml`, `authheaders`, `dkimpy`, `python-dateutil`, `tldextract`, `cryptography`, `jinja2`, `weasyprint`). Updated `.core/deps.sh` (`MACOS_PYTHON_DEPS` and `deps_install_missing`) to create `.dep/.venv` and install `.dep/requirements.txt` automatically when missing.
- **`modules/macos/security/CYBER/common/run_python.sh` & `modules/macos/security/INTEL/threat-intel.sh`**: Removed per-module `.venv` creation/activation to eliminate parallel `FileExistsError` / `pip` cache race conditions; both now resolve the repo-local `.dep/.venv/bin/python3` with automatic fallback to `.core/deps.sh install`.
- **`modules/macos/security/CYBER/common/aliases.sh` & `modules/macos/security/cybermaster`**: Rewrote `threatctx` to run `enricher.py`, `risk_scorer.py`, and `reporter.py` sequentially via `mktemp` intermediate files with minimal-JSON fallback, and routed options 3 (`md`), 4 (`html`), and 5 (`pdf`) through `threatctx`.
- **`modules/macos/security/CYBER/scoring/risk_scorer.py`**: Added `--target` option and graceful fallback to a valid minimal `UnifiedSchema` JSON on empty or interactive stdin instead of exiting with code `1` (`Empty input received`).

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

### Universal `0` Navigation & `ui_run_safe` Error Handling
- **`.core/ui.sh`**: Added `ui_run_safe "<desc>" <cmd...>` try/catch wrapper and updated `ui_pause()` to `Druk op [Enter] of typ '0' om terug te keren...`.
- **`scripter`, `qnapmaster.sh`, and all 7 `modules/common/*` modules**: Standardized `0) Terug` / `0) Afsluiten (Exit)` and wrapped interactive actions in `ui_run_safe`.
- **`AGENTS.md`**: Added `0` navigation and `ui_run_safe` as permanent coding standards.

### Repository Rename (`shellscript-master`)
- Verified `origin` remote points to `https://github.com/bartpaeleman/shellscript-master.git` and confirmed no stale `unified-master-hub` references remain in tracked docs/scripts.

### OS-Scoped Dependency Filtering (`.core/deps.sh` & `.core/os_detect.sh`)
- Split dependencies into `COMMON_DEPS`, `MACOS_DEPS`, `QNAP_DEPS` (and `COMMON_PYTHON_DEPS` / `MACOS_PYTHON_DEPS`); `QNAP`/`Linux` now skip `MACOS_DEPS` unless `--all` is set.
- Added `/opt/bin:/opt/sbin` to `PATH` on QNAP for Entware (`opkg`) detection, `.dep/.venv/bin/pip` support, and clean `[INFO]` message when `opkg` is absent.

### Shortcodes & Complete `README.md` (`scripter`, `gitmaster`, `containermaster`, `README.md`)
- Added conflict-free shortcodes (`-g`, `-c`, `-b`, `-w`, `-m`, `-q`, `-f`, `-a`, `-t`, `-e`, `-n`, `-y`, `-i`, `-u`, `-v`, `-p`, `-k`) and `+switches` to `scripter` and `show_help()`.
- Added short subcommand aliases in `gitmaster.sh` (`st`, `df`, `sw`, `ci`, `sq`, `pr`, `bak`, `rst`) and `containermaster.sh` (`ls`, `lg`, `in`, `rs`, `sh`, `cleanup`).
- Rewrote `README.md` as a complete user manual for `shellscript-master`.

### QNAP Persistence & Profile Scanner / Editor (`modules/qnap/qnapmaster.sh`)
- Added `qnap_persistence_scan` (`scripter -q persistence`) scanning `[PERSISTENT]` (`/share/homes/*/.profile`, `/opt/etc/profile`, `/opt/bin/scripter`, `/etc/config/autorun.sh`) and `[SESSION]` (`/root/.*`, `/etc/.*`, `/usr/local/bin/scripter`, `/usr/bin/scripter`) locations.
- Added safe per-file actions: timestamped `.bak` backup, `sudo`-aware editing (`nano`/`vim`/`vi`), rule preview, and `# >>> scripter-hub >>>` block removal.

### Cross-Platform Alias Manager (`.core/aliases.sh`, `qnapmaster`, `macmaster`)
- Added `.core/aliases.sh` managing `# >>> scripter-aliases >>>` blocks with `.bak` backups, numbered listing/editing/deletion, and `read -e` Tab path-autocomplete.
- Added Presets Wizard: Webserver `prd`/`dev`/`tst` (`/share/Web` on QNAP, `~/Sites` on macOS), `pyvenv` (`.dep/.venv/bin/activate`), and macOS shortcuts (`flushdns`, `showfiles`, `hidefiles`, `brewup`).
- Integrated via `./scripter -q aliases` and `./scripter -m aliases`.

### Fix `os_is_macos: command not found` on QNAP (`.core/aliases.sh`)
- Changed `.core/aliases.sh` to check `declare -F os_is_macos` before sourcing `.core/os_detect.sh`, ensuring OS helper functions are always loaded even when `OS_TYPE` is already exported.

### Default `Enter` = `0` in Menus & Standalone Cleanup
- Added `ui_read_menu_choice` in `.core/ui.sh` (`Choice [0]: `) so empty `Enter` input defaults to `0` across `scripter`, `.core/aliases.sh`, `qnapmaster.sh`, and all 7 `modules/common/*` modules.
- Audited and removed legacy `macscripts/` and `unixscripts/` reference directories after passing full quarantine smoke-tests (`shellscript-master` runs 100% standalone).

### QNAP Target Profile Selector & Legacy Alias Support (`.core/aliases.sh`)
- Added `alias_select_profile` and `alias_scan_all_qnap` for QNAP (`/share/homes/<user>/.profile`, `/root/.profile`, `/root/.bashrc`, `/etc/profile`, `/opt/etc/profile`).
- Updated `_alias_read_list` to include standalone legacy `alias ` lines and `_alias_write_list` to handle `sudo` + `.bak` backups + `[VOLATILE RAM]` warnings.

### QNAP Persistence Scanner Alignment (`modules/qnap/qnapmaster.sh`)
- Aligned `qnap_persistence_scan` and `_qnap_file_actions` with `Enter = 0` (`ui_read_menu_choice`) and added `scriptmaster` / `# >>> scripter >>>` cleanup support.

### QNAP `/share/Public/.bash_aliases`, Direct Module Aliases & Legacy Migration
- Added `/share/Public/.bash_aliases` `[PERSISTENT — Centraal Alias Bestand]` to `.core/aliases.sh`, `qnapmaster.sh`, and `# >>> scripter-hook >>>` in `.core/persist.sh`.
- Added `Directe Module-Aliassen` preset (`gitmaster`, `dockermaster`, `dbmaster`, etc.) for QNAP and macOS, updated QNAP Webserver defaults to `/share/Web/`, `/share/Web/DEV/`, `/share/Web/TEST/`, and added `alias_migrate_unixscripts` to migrate legacy `/share/Public/unixscripts` aliases while preserving custom Python/Web rules.

### `AGENTS.md` Architecture & QNAP Standards Update
- Documented functional menu grouping, dynamic numbering, shortcodes (`-x`), `Enter = 0` (`ui_read_menu_choice`), `ui_run_safe`, and QNAP/BusyBox compatibility & persistence rules in `AGENTS.md`.

### QNAP Python 3 Auto-Detection & Alias Preset (`.core/os_detect.sh`, `.core/aliases.sh`)
- Added `os_detect_qnap_python()` in `.core/os_detect.sh` to automatically prepend `.samba_python3`, QPKG Python3, or `/opt/bin` to `PATH` on QNAP.
- Updated `Python Venv Preset` and `alias_add_custom` in `.core/aliases.sh` to configure `export PATH` alongside `alias python3` on QNAP.

### `gitmaster` & `ui_run_safe` Cross-Platform Hardening
- Updated `ui_run_safe` in `.core/ui.sh` to capture and display `stderr` details on command failure.
- Fixed trailing conditional one-liners in `modules/common/git/gitmaster.sh` (`opt_config`, `opt_revert_commit`, `opt_untrack`, `opt_delete_branch`) so skipping optional inputs returns `0` cleanly.

### `macmaster` & macOS Alias Manager Parity
- Upgraded `modules/macos/macsystem/macmanager.sh` to `.core/ui.sh` (`ui_clear_screen`, `ui_read_menu_choice` with `Enter = 0`, `ui_run_safe`, `0) Terug` instead of `X) Exit`), plus `7) Alias Manager` and `--help`.
- Added macOS Target Profile Selector (`~/.zshrc`, `~/.zprofile`, `~/.bash_profile`, `~/.bashrc`, scan all) and `alias_cleanup_legacy_macos` in `.core/aliases.sh`, plus `ui_read_path` in `.core/ui.sh`.

### `gitmaster` Local & Remote Branch Checkout (`modules/common/git/gitmaster.sh`)
- Updated `opt_checkout` to run `git fetch --all --prune`, deduplicate local & `origin/*` branches with `[LOKAAL]` / `[REMOTE - origin]` tags, and support `Enter = 0` (`ui_read_menu_choice`).
- Added Option 24 `opt_merge_to_main` (`merge-main`): pre-flight dirty-tree stash check, merge `--no-ff` into `main`/`master` with optional `origin/main` push, conflict abort guard, and safe `git branch -d` / `origin` cleanup.

### System-Wide UI & Navigation Audit (`.core/deps.sh`, `scripter`, `modules/`)
- Upgraded `deps_menu` (`D) Dependency Center`) in `.core/deps.sh` to `.core/ui.sh` (`ui_clear_screen`, `ui_header`, `ui_item`, `ui_read_menu_choice` with `Enter = 0`, `ui_run_safe`, `0) Terug`).
- Verified `bash -n`, `python3 -m py_compile`, `./scripter --all --help`, `OS_TYPE=QNAP ./scripter --help`, and `Enter = 0` across `P`, `D`, `H`, and all hub-managed modules.
- Standardized `0) Terug` and `Enter = 0` across `cybermaster`, `audiomaster`, `videomaster`, `imagemaster`, `karaokemaster`, and `VIDEO/video-master.sh` (zero `X)`/`q)`/`b)` exit options remaining).

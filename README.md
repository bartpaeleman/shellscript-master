# Shellscript Master (`scripter`)

Centrale, cross-platform TUI- en CLI-hub voor **macOS**, **QNAP NAS** en **Linux**.

---

## 1. Overzicht & Architectuur

`scripter` detecteert automatisch het actieve besturingssysteem (`macOS`, `QNAP` of `Linux`) via `.core/os_detect.sh` en past zowel het hoofdmenu als de dependency-checks daarop aan:

- **Functionele categorie-indeling:** Modules zijn gegroepeerd op taak (*Development & Ops*, *Systeembeheer*, *Bestands- & Databeheer*, *Netwerk & Cybersecurity*, *Media & Multimedia*) met compacte platformbadges (`[UNI]`, `[MAC]`, `[QNAP]`).
- **Dynamische nummering:** Lege categorieën voor het actieve OS worden weggelaten; sectie- en itemnummers lopen altijd naadloos door.
- **Universele `0`-navigatie:** In elk menu en elke sub-prompt keert `0` direct terug naar het vorige scherm (of sluit af in het hoofdmenu).
- **Centrale Try/Catch (`ui_run_safe`):** Externe commando's worden opgevangen via `.core/ui.sh` zodat een fout nooit het script afbreekt, maar een duidelijke foutbox met exit-code toont.

---

## 2. Mappenstructuur

```text
.
├── scripter                # Centrale hub (TUI-menu, +switches, shortcodes, --persist)
├── README.md               # Gebruikershandleiding
├── CHANGELOG.md            # Compacte release-historie
├── AGENTS.md               # Project- & ontwikkelstandaarden
├── modules/
│   ├── common/             # [UNI] Cross-platform modules (git, container, db, data, text, file, web)
│   ├── macos/              # [MAC] macsystem, security, media
│   └── qnap/               # [QNAP] Container Station, @Recycle cleanup, Entware
├── .core/                  # os_detect.sh, ui.sh, deps.sh, persist.sh
├── .dep/                   # Geïsoleerde Python virtual environment (.dep/.venv)
├── .config/                # Configuratie (.env.example -> .env)
└── .doc/                   # Per-module naslagwerken & DETAILEDCHANGES.md
```

---

## 3. Installatie, Activatie & Shell Persistentie

```bash
git clone -b shellscripts https://github.com/bartpaeleman/shellscript-master.git
cd shellscript-master
chmod +x scripter .core/*.sh modules/qnap/qnapmaster.sh
```

### Shell Persistentie (`--persist`)
Maak `scripter` overal in de terminal beschikbaar:
```bash
./scripter --persist
```
- **macOS:** Voegt een idempotent `# >>> scripter-hub >>>` blok toe aan `~/.zshrc` (en `~/.bash_profile` indien aanwezig).
- **QNAP NAS:** Schrijft naar Entware `/opt/etc/profile` (indien beschrijfbaar), `~/.profile`, en symlinkt `/opt/bin/scripter`.
- **Linux:** Schrijft naar `~/.bashrc` / `~/.profile` en symlinkt `/usr/local/bin/scripter`.

### Dependency & Update Center
```bash
./scripter +deps status     # Controleer OS-specifieke binaries & Python packages
./scripter +deps install    # Installeer ontbrekende tools (brew / opkg / apt + .dep/.venv)
./scripter +deps update     # Update systeemtools & Python packages
```

---

## 4. CLI & Shortcode Referentietabel

| Module | Platform | `+`-Switches | Shortcode | Voorbeeld |
| :--- | :---: | :--- | :---: | :--- |
| `gitmaster` | `[UNI]` | `+gitmaster`, `+git` | `-g` | `./scripter -g status` |
| `containermaster` | `[UNI]` | `+containermaster`, `+docker`, `+cnt` | `-c` | `./scripter -c ls` |
| `dbmaster` | `[UNI]` | `+dbmaster`, `+db` | `-b` | `./scripter -b check` |
| `webmaster` | `[UNI]` | `+webmaster`, `+web` | `-w` | `./scripter -w serve 8080` |
| `macmaster` | `[MAC]` | `+macmaster`, `+mac` | `-m` | `./scripter -m` |
| `qnapmaster` | `[QNAP]` | `+qnapmaster`, `+qnap` | `-q` | `./scripter -q containers` |
| `filemaster` | `[UNI]` | `+filemaster`, `+file` | `-f` | `./scripter -f rename` |
| `datamaster` | `[UNI]` | `+datamaster`, `+data` | `-a` | `./scripter -a table data.csv` |
| `textmaster` | `[UNI]` | `+textmaster`, `+text` | `-t` | `./scripter -t stats notes.txt` |
| `rename_ebooks` | `[MAC]` | `+rename_ebooks`, `+ebooks` | `-e` | `./scripter -e` |
| `networkmaster` | `[MAC]` | `+networkmaster`, `+net` | `-n` | `./scripter -n` |
| `cybermaster` | `[MAC]` | `+cybermaster`, `+cyber` | `-y` | `./scripter -y` |
| `intelmaster` | `[MAC]` | `+intelmaster`, `+intel` | `-i` | `./scripter -i` |
| `audiomaster` | `[MAC]` | `+audiomaster`, `+audio` | `-u` | `./scripter -u` |
| `videomaster` | `[MAC]` | `+videomaster`, `+video` | `-v` | `./scripter -v` |
| `imagemaster` | `[MAC]` | `+imagemaster`, `+img` | `-p` | `./scripter -p` |
| `karaokemaster` | `[MAC]` | `+karaokemaster`, `+karaoke` | `-k` | `./scripter -k` |

---

## 5. Overzicht per Functionele Categorie

- **Development & Ops:**
  - `gitmaster` (24 functies): `status`/`st`, `diff`/`df`, `history`/`log`, `compare`, `start`, `switch`/`sw`, `commit`/`ci`, `sync`/`pull` (Standard Pull default), `squash`/`sq`, `uat`, `merge-fix`, `merge-main` (merge naar `main` + push + veilige cleanup), `tag`, `prune`/`pr`, `delete-branch`, `backup`/`bak`, `restore`/`rst`, `stash-pull`, `undo`, `revert`, `force-sync`, `recover`, `untrack`, `config`.
  - `containermaster` (10 functies): `list`/`ls`, `logs`/`lg` (Ctrl+C veilig), `inspect`/`in` (`inspect_viewer.py`), `start`, `stop`, `restart`/`rs`, `shell`/`sh` (`/bin/bash` -> `/bin/sh`), `create`, `rm`, `cleanup`/`prune`.
  - `dbmaster`: `backup` (`.sql.gz` via `mysqldump`), `analyze` (`db_stats.py`), `check`.
  - `webmaster`: `scaffold` (`assets/`, `includes/`, `config/`, `index.php`), `readme` (`generate_readme.py`), `serve`.
- **Systeembeheer:** `macmaster` (`crontab_manager`, `zshrc_editor`, `auto_cleanup`, `clear_cache`, `uninstall`, `aliases`) & `qnapmaster` (`containers`, `cleanup`, `entware`, `persistence`, `aliases`).
  - **Alias Manager (`-m aliases` / `-q aliases`):** Beheer aliassen (inclusief losse legacy-aliassen) met Tab pad-autocomplete, automatische `.bak` backup, `pyvenv` preset, Webserver/Project `prd`/`dev`/`tst` presets (`/share/Web/`, `/share/Web/DEV/`, `/share/Web/TEST/` op QNAP; `~/Sites` op macOS), **Directe Module-Aliassen** (`gitmaster`, `dockermaster`, `dbmaster`, etc.) en een **Doelbestand-kiezer** op zowel QNAP (`/share/Public/.bash_aliases`, `/share/homes/<user>/.profile`, `/root/.profile`, `/root/.bashrc`, `/etc/profile`, `/opt/etc/profile`) als macOS (`~/.zshrc`, `~/.zprofile`, `~/.bash_profile`, `~/.bashrc` + legacy `macscripts/`/`scriptmaster` opschoning).
- **Bestands- & Databeheer:** `filemaster` (`rename`, `mkdirs`, `archive`, `cleanup`, `compare`, `sync`, `csv`, `fzf`, `large`), `datamaster` (`table`, `delimiter`, `convert`, `normalize`, `deps`), `textmaster` (`stats`, `replace`, `diff`, `merge`, `case`), `rename_ebooks`.
- **Netwerk & Cybersecurity `[MAC]`:** `networkmaster`, `cybermaster` (`mailtrace`, `mhdr`, `threatctx`, `mailreport`, `geotrace`, `recon`; alle Markdown-rapportacties vragen vooraf de output-modus via `cyber_output_report`: `1` alleen scherm [default], `2` `.md` export, `3` beide, `0` annuleren), `intelmaster`.
- **Media & Multimedia `[MAC]`:** `audiomaster`, `videomaster`, `imagemaster`, `karaokemaster`.

---

## 6. Ontwikkeling & Release-workflow

Zie [AGENTS.md](AGENTS.md) voor alle ontwikkelstandaarden en [.doc/DETAILEDCHANGES.md](.doc/DETAILEDCHANGES.md) voor gedetailleerde technische wijzigingslogs.

# Project Guidelines & Rules

## Autonome uitvoering van plannen
- **Zelfstandige uitvoering**: Zodra een plan door de gebruiker is goedgekeurd, voer alle stappen van het plan volledig zelfstandig en achter elkaar uit.
- **Geen tussentijdse bevestigingen**: Vraag tussentijds geen bevestiging of toestemming voor individuele stappen of routinehandelingen die deel uitmaken van het goedgekeurde plan.
- **Eindresultaat**: Rapporteer pas weer zodra de volledige implementatie en verificatie zijn voltooid en presenteer dan direct het behaalde eindresultaat en de uitgevoerde acties.
- **Uitzonderingen**: Pauzeer en raadpleeg de gebruiker alleen wanneer er sprake is van een onverwachte fatale fout, een ontbrekende essentiële dependency die niet automatisch kan worden opgelost, of een onvoorziene destructieve actie buiten de scope van het plan.

## Git Workflow bij Planuitvoering
- **Nieuwe branch aanmaken**: Maak bij de start van de uitvoering van een goedgekeurd plan altijd eerst een nieuwe branch aan met een duidelijke en beschrijvende naam (bijv. `feature/<onderwerp>` of `fix/<onderwerp>`).
- **Commit & Push**: Commit alle wijzigingen met duidelijke commit-berichten en push de branch naar GitHub (`origin`) zodra het werk voltooid en geverifieerd is.

## Veiligheid & Geheimhouding (Secrets & Gitignore)
- **Geen gevoelige data committen**: Commit of push nooit wachtwoorden, API-sleutels, tokens, private keys (`*.key`, `*.pem`, `id_rsa*`) of andere credentials naar GitHub.
- **Environment variables**: Gebruik altijd environment variabelen of lokale `.env` bestanden voor geheimen. Alleen template/voorbeeld-bestanden zonder werkelijke geheimen (zoals `.env.example`) mogen in Git worden opgenomen.
- **Gitignore handhaven**: Houd [.gitignore](file:///Volumes/Web/DEV/macscripts/.gitignore) up-to-date voor alle secrets, lokale configs (`*.local`, `.env*`), OS-bestanden (`.DS_Store`), caches (`__pycache__`, `*.pyc`), en virtuele omgevingen (`.venv/`, `node_modules/`).
- **Pre-commit verificatie**: Controleer vóór elke commit en push altijd via `git status` en `git diff` dat er geen onbedoelde, gevoelige of overbodige bestanden worden meegenomen.

## Hub & CLI Conventies (`scripter`)
- De centrale entrypoint is `./scripter` (voorheen `master`).
- Directe module-aanroep gebruikt `+modulenaam` of `--modulenaam` (bijv. `./scripter +gitmaster status`, `./scripter +deps status`).
- UI-elementen gebruiken `.core/ui.sh` en shell-persistentie verloopt via `./scripter --persist` (`.core/persist.sh`).
- **Universele `0`-navigatie**: Elk menu gebruikt `0` als primaire terug-/afsluitoptie (`0) Terug` in submenus, `0) Afsluiten (Exit)` in het hoofdmenu), elke menu-prompt gebruikt `ui_read_menu_choice` zodat `Enter` standaard `0` is, en elke invoer-prompt accepteert `0` om te annuleren.
- **Centrale Try/Catch (`ui_run_safe`)**: Externe commando's en kritieke acties in interactieve menu's worden gewikkeld in `ui_run_safe` (`.core/ui.sh`) zodat fouten netjes worden opgevangen zonder dat `scripter` crasht.

## Git Branch & Remote Sync Beleid
- Controleer vóór het starten van nieuwe wijzigingen altijd of `shellscripts` en `origin/shellscripts` synchroon zijn (`git fetch origin && git status -sb`); zo niet, vraag eerst welke versie als bron geldt.
- Commit en push elke afgeronde wijziging methodisch en atomisch naar `origin/shellscripts`.

## Gelaagde Documentatie & Release Beheer
- Houd `CHANGELOG.md` uiterst compact (alleen actieve major releases en hoofdmijlpalen).
- Houd alle gedetailleerde wijzigingslogs en technische release-aantekeningen bij in `.doc/DETAILEDCHANGES.md`.
- **Release-vergrendeling**: Verhoog een versienummer in `CHANGELOG.md` en `.doc/DETAILEDCHANGES.md` nooit zelfstandig na kleine fixes. Vraag bij grote mijlpalen eerst expliciet om bevestiging; pas na goedkeuring squashen, versienummer bijwerken en Git-tag plaatsen.

## Automatische Eerste-Start & Pre-Check
- `scripter` voert bij elke opstart een snelle, stille pre-check uit:
  - Herstelt indien nodig `chmod +x` op `scripter`, `.core/*.sh` en `modules/**/*.sh` / `*.py`.
  - Controleert of `.config/.env` (vanuit `.config/.env.example`) en `.dep/.venv` aanwezig zijn en initialiseert ontbrekende basisstructuren.

## Omgevings-Pariteit & Anti-Regressie Standaarden
- Verbied hardcoded paden (`/Users/...`, `/share/...`) en GNU-only CLI-flags (`sed -i`, `readlink -f`, `grep -P`) in gedeelde code; gebruik de OS-abstractie wrappers uit `.core/os_detect.sh`.
- Houd rekening met macOS Bash 3.2 vs. moderne Bash/Zsh: gebruik portable shell-constructies of expliciete interpreter-selectie.

## Verplichte Pre-Commit Verificatie
- Voer vóór elke commit een geautomatiseerde controle uit op alle gewijzigde bestanden:
  - Syntax-validatie (`bash -n` voor shellscripts, `python3 -m py_compile` voor Python-scripts, en `shellcheck` indien geïnstalleerd).
  - Smoke-test (`./scripter +<module> --help`) om te verifiëren dat de module foutloos opstart.

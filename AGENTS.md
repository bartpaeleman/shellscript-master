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

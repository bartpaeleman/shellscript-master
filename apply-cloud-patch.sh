cript: apply-cloud-patch.sh
# Doel:   Selecteert een Antigravity Cloud .patch bestand op QNAP NAS, waarschuwt
#         bij dubbele diff --git blokken, past wijzigingen toe via 'git apply' +
#         'git apply --3way' (slaat reeds gemergede commits op main over),
#         pusht naar GitHub en verwijdert uitgevoerde patches.
# Gebruik: ./apply-cloud-patch.sh [optioneel/pad/naar.patch] [optionele-branch]
# ==============================================================================

set -eu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 1. Controleer of we in een Git-repository zitten
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf "${RED}[FOUT]${NC} Huidige directory (%s) is geen geldige Git-repository.\n" "$(pwd)"
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Helper voor pad-invoer (BusyBox/QNAP-veilig)
read_patch_path() {
    prompt="$1"
    printf "%s" "$prompt" >&2
    IFS= read -r input
    # Trim spaties en converteer ~/ naar $HOME/
    input="$(printf '%s' "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$input" in
        "~/"*) input="${HOME}/${input#~/}" ;;
    esac
    printf '%s' "$input"
}

# Helper om een bestandsnaam op te schonen tot een geldige Git branch-naam
sanitize_branch_suggestion() {
    raw="$1"
    raw="$(printf '%s' "$raw" | sed -E 's/[[:space:]]*\([0-9]+\)$//; s/[[:space:]]+/-/g')"
    case "$raw" in
        feature-*) raw="feature/${raw#feature-}" ;;
        fix-*)     raw="fix/${raw#fix-}" ;;
    esac
    raw="$(printf '%s' "$raw" | tr -cd '[:alnum:]._/-' | sed -E 's|/+|/|g; s|^/||; s|/$||')"
    printf '%s' "$raw"
}

# 2. Selecteer het patch-bestand
PATCH_FILE="${1:-}"

if [ -z "$PATCH_FILE" ]; then
    printf "${CYAN}=== Antigravity Cloud Patch Selector (QNAP) ===${NC}\n"
    printf "Repository: ${GREEN}%s${NC}\n\n" "$REPO_ROOT"

    TMP_PATCHES="/tmp/qnap_patches_$$.list"
    rm -f "$TMP_PATCHES"
    ls -1t "$REPO_ROOT"/*.patch 2>/dev/null > "$TMP_PATCHES" || true

    PATCH_COUNT=0
    if [ -s "$TMP_PATCHES" ]; then
        printf "${BOLD}Beschikbare .patch bestanden in projectmap:${NC}\n"
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            PATCH_COUNT=$((PATCH_COUNT + 1))
            fname="$(basename "$f")"
            fsize="$(wc -c < "$f" | tr -d ' ')"
            printf "  ${GREEN}%d)${NC} %s ${YELLOW}(%s bytes)${NC}\n" "$PATCH_COUNT" "$fname" "$fsize"
        done < "$TMP_PATCHES"
        printf "\n"
        printf "  ${CYAN}P)${NC} Ander pad of bestand ingeven\n"
        printf "  ${RED}0)${NC} Annuleren / Afsluiten [Default]\n\n"

        printf "Kies nummer, typ bestandsnaam of 'P' [0]: "
        IFS= read -r CHOICE
        CHOICE="${CHOICE:-0}"

        case "$CHOICE" in
            0|q|Q)
                rm -f "$TMP_PATCHES"
                printf "${YELLOW}[INFO]${NC} Geannuleerd door gebruiker.\n"
                exit 0
                ;;
            p|P)
                PATCH_FILE="$(read_patch_path "Pad naar .patch bestand (0 = annuleren): ")"
                ;;
            *)
                if printf '%s' "$CHOICE" | grep -Eq '^[0-9]+$' && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "$PATCH_COUNT" ]; then
                    PATCH_FILE="$(sed -n "${CHOICE}p" "$TMP_PATCHES")"
                elif [ -f "$CHOICE" ]; then
                    PATCH_FILE="$CHOICE"
                elif [ -f "$REPO_ROOT/$CHOICE" ]; then
                    PATCH_FILE="$REPO_ROOT/$CHOICE"
                elif [ -f "$REPO_ROOT/${CHOICE}.patch" ]; then
                    PATCH_FILE="$REPO_ROOT/${CHOICE}.patch"
                else
                    PATCH_FILE="$CHOICE"
                fi
                ;;
        esac
    else
        printf "${YELLOW}[INFO]${NC} Geen .patch bestanden gevonden in %s.\n" "$REPO_ROOT"
        PATCH_FILE="$(read_patch_path "Geef het pad naar het .patch bestand (0 = annuleren): ")"
    fi
    rm -f "$TMP_PATCHES"
fi

if [ -z "$PATCH_FILE" ] || [ "$PATCH_FILE" = "0" ]; then
    printf "${YELLOW}[INFO]${NC} Geannuleerd door gebruiker.\n"
    exit 0
fi

if [ ! -f "$PATCH_FILE" ] && [ -f "$REPO_ROOT/$PATCH_FILE" ]; then
    PATCH_FILE="$REPO_ROOT/$PATCH_FILE"
fi

if [ ! -f "$PATCH_FILE" ]; then
    printf "${RED}[FOUT]${NC} Patch-bestand niet gevonden: '%s'\n" "$PATCH_FILE"
    exit 1
fi

if [ ! -s "$PATCH_FILE" ]; then
    printf "${RED}[FOUT]${NC} Patch-bestand '%s' is leeg (0 bytes).\n" "$PATCH_FILE"
    exit 1
fi

# 3. Haal remote branches op
printf "\n${CYAN}[1/4]${NC} Ophalen van actuele branches van GitHub (origin)...\n"
git fetch origin --prune >/dev/null 2>&1 || true

# 4. Doel-branch kiezen
TARGET_BRANCH="${2:-}"

if [ -z "$TARGET_BRANCH" ]; then
    RAW_NAME="$(basename "$PATCH_FILE" .patch)"
    SUGGESTED_BRANCH="$(sanitize_branch_suggestion "$RAW_NAME")"
    if [ -z "$SUGGESTED_BRANCH" ]; then
        CURRENT_BR="$(git rev-parse --abbrev-ref HEAD)"
        if [ "$CURRENT_BR" = "main" ]; then
            SUGGESTED_BRANCH="feature/cloud-patch"
        else
            SUGGESTED_BRANCH="$CURRENT_BR"
        fi
    fi

    TMP_BRANCHES="/tmp/qnap_branches_$$.list"
    {
        git branch --format='%(refname:short)'
        git branch -r --format='%(refname:short)' | grep -v 'HEAD' | sed 's|^origin/||'
    } | sort -u > "$TMP_BRANCHES"

    BR_COUNT="$(wc -l < "$TMP_BRANCHES" | tr -d ' ')"

    printf "\n${BOLD}Kies doel-branch voor '%s':${NC}\n" "$(basename "$PATCH_FILE")"
    printf "  ${GREEN}N)${NC} Nieuwe branch aanmaken met voorgestelde naam: ${CYAN}%s${NC} [Default bij Enter]\n" "$SUGGESTED_BRANCH"
    printf "  ${CYAN}M)${NC} Handmatig een nieuwe branch-naam intypen\n"

    if [ "$BR_COUNT" -gt 0 ]; then
        printf "\n${BOLD}Of voeg toe aan een bestaande branch:${NC}\n"
        idx=0
        while IFS= read -r br; do
            [ -n "$br" ] || continue
            idx=$((idx + 1))
            loc_tag=""
            rem_tag=""
            git show-ref --verify --quiet "refs/heads/$br" && loc_tag="LOKAAL"
            git show-ref --verify --quiet "refs/remotes/origin/$br" && rem_tag="ORIGIN"
            if [ -n "$loc_tag" ] && [ -n "$rem_tag" ]; then
                tag="[LOKAAL + ORIGIN]"
            elif [ -n "$loc_tag" ]; then
                tag="[LOKAAL]"
            else
                tag="[ORIGIN]"
            fi
            printf "  ${GREEN}%d)${NC} %s ${YELLOW}%s${NC}\n" "$idx" "$br" "$tag"
        done < "$TMP_BRANCHES"
    fi
    printf "\n  ${RED}0)${NC} Annuleren\n\n"

    while true; do
        printf "Keuze (nummer, N, M of typ direct een branch-naam) [N]: "
        IFS= read -r BR_CHOICE
        BR_CHOICE="${BR_CHOICE:-N}"

        case "$BR_CHOICE" in
            0|q|Q)
                rm -f "$TMP_BRANCHES"
                printf "${YELLOW}[INFO]${NC} Geannuleerd door gebruiker.\n"
                exit 0
                ;;
            n|N)
                TARGET_BRANCH="$SUGGESTED_BRANCH"
                ;;
            m|M)
                printf "Typ de gewenste branch-naam (0 = annuleren): "
                IFS= read -r MANUAL_BR
                if [ "$MANUAL_BR" = "0" ] || [ -z "$MANUAL_BR" ]; then
                    rm -f "$TMP_BRANCHES"
                    printf "${YELLOW}[INFO]${NC} Geannuleerd door gebruiker.\n"
                    exit 0
                fi
                TARGET_BRANCH="$MANUAL_BR"
                ;;
            *)
                if printf '%s' "$BR_CHOICE" | grep -Eq '^[0-9]+$' && [ "$BR_CHOICE" -ge 1 ] && [ "$BR_CHOICE" -le "$BR_COUNT" ]; then
                    TARGET_BRANCH="$(sed -n "${BR_CHOICE}p" "$TMP_BRANCHES")"
                else
                    TARGET_BRANCH="$BR_CHOICE"
                fi
                ;;
        esac

        if git check-ref-format --branch "$TARGET_BRANCH" >/dev/null 2>&1; then
            rm -f "$TMP_BRANCHES"
            break
        else
            printf "${RED}[FOUT]${NC} '%s' is geen geldige Git branch-naam.\n" "$TARGET_BRANCH"
        fi
    done
fi

printf "\n${CYAN}=== Uitvoering ===${NC}\n"
printf "Patch file : ${GREEN}%s${NC} (%s bytes)\n" "$(basename "$PATCH_FILE")" "$(wc -c < "$PATCH_FILE" | tr -d ' ')"
printf "Doelbranch : ${GREEN}%s${NC}\n\n" "$TARGET_BRANCH"

# 5. Controleer of er geen onbedoelde lokale wijzigingen of UU-conflictresten openstaan
DIRTY_FILES="$(git status --porcelain | grep -v '\.patch$' || true)"
if [ -n "$DIRTY_FILES" ]; then
    printf "${YELLOW}[WAARSCHUWING]${NC} De repository bevat niet-gecommitte wijzigingen of conflict-resten:\n"
    printf "%s\n\n" "$DIRTY_FILES"
    printf "Deze lokale wijzigingen wissen (git reset --hard HEAD) om door te gaan? [j/N]: "
    IFS= read -r RESET_CHOICE
    case "$RESET_CHOICE" in
        j|J|y|Y)
            git am --abort 2>/dev/null || true
            git merge --abort 2>/dev/null || true
            git reset --hard HEAD
            git clean -fd -e "*.patch" -e "apply-cloud-patch.sh"
            printf "${GREEN}[OK]${NC} Werkdirectory schoongemaakt.\n"
            ;;
        *)
            printf "${RED}[FOUT]${NC} Afgebroken. Commit of stash deze wijzigingen eerst.\n"
            exit 1
            ;;
    esac
fi

# 6. Ruim eventuele vastgelopen eerdere git am / merge sessies op
[ -d "$REPO_ROOT/.git/rebase-apply" ] && git am --abort 2>/dev/null || true
[ -f "$REPO_ROOT/.git/MERGE_HEAD" ] && git merge --abort 2>/dev/null || true

# 7. Schakel naar de gekozen branch
if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    printf "${CYAN}[2/4]${NC} Overschakelen naar bestaande lokale branch '%s'...\n" "$TARGET_BRANCH"
    git checkout "$TARGET_BRANCH"
    if git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
        git pull --ff-only origin "$TARGET_BRANCH" || true
    fi
elif git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
    printf "${CYAN}[2/4]${NC} Bestaande remote branch 'origin/%s' uitchecken...\n" "$TARGET_BRANCH"
    git checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH"
else
    printf "${CYAN}[2/4]${NC} Nieuwe branch '%s' aanmaken vanaf 'origin/main'...\n" "$TARGET_BRANCH"
    git checkout -b "$TARGET_BRANCH" origin/main
fi

# 8. Controleer op dubbele diff --git-regels en pas de patch toe
printf "${CYAN}[3/4]${NC} Patch toepassen op '%s'...\n" "$TARGET_BRANCH"
PATCH_APPLIED=0

if [ "$(grep '^diff --git' "$PATCH_FILE" | sort | uniq -d | wc -l)" -gt 0 ]; then
    printf "${YELLOW}[WAARSCHUWING]${NC} Dit patchbestand bevat meerdere opeenvolgende diffs voor hetzelfde bestand (bijv. via git log -p). Gebruik 'git diff HEAD~1..HEAD' i.p.v. meerdere commits.\n"
fi

# Probeer eerst schoon, daarna 3-way (slaat reeds gemergede commits automatisch over)
if git apply --check --whitespace=nowarn "$PATCH_FILE" 2>/dev/null; then
    git apply --whitespace=nowarn "$PATCH_FILE"
    printf "${GREEN}[OK]${NC} Patch schoon toegepast.\n"
    PATCH_APPLIED=1
elif git apply --3way --whitespace=nowarn "$PATCH_FILE"; then
    printf "${GREEN}[OK]${NC} Patch toegepast via 3-way merge (reeds aanwezige wijzigingen overgeslagen).\n"
    PATCH_APPLIED=1
else
    printf "${RED}[CONFLICT]${NC} Handmatige conflictresolutie nodig (zoek op '<<<<<<<').\n"
    printf "Los de conflicten op in de onderstaande bestanden, voer 'git add -A && git commit' uit, en push daarna:\n"
    git status -s | grep -v '\.patch$' || true
    printf "\n  git push -u origin %s\n" "$TARGET_BRANCH"
    exit 1
fi

# 9. Commit de toegepaste wijzigingen (indien er netto nog nieuwe wijzigingen overbleven)
if [ "$PATCH_APPLIED" -eq 1 ]; then
    git add -A
    git reset -- "$PATCH_FILE" 2>/dev/null || true

    if [ -n "$(git status --porcelain | grep -v '\.patch$' || true)" ]; then
        PATCH_SUBJECT="$(grep -m 1 '^Subject:' "$PATCH_FILE" | sed -E 's/^Subject:[[:space:]]*(\[PATCH[^]]*\][[:space:]]*)?//' || true)"
        if [ -z "$PATCH_SUBJECT" ]; then
            PATCH_SUBJECT="feat: apply cloud patch $(basename "$PATCH_FILE" .patch)"
        fi
        git commit -m "$PATCH_SUBJECT"
    else
        printf "${YELLOW}[INFO]${NC} Alle wijzigingen uit deze patch zaten al in '%s' (geen nieuwe commit nodig).\n" "$TARGET_BRANCH"
    fi

    # 10. Push de branch naar GitHub
    printf "${CYAN}[4/4]${NC} Pushen van '%s' naar GitHub (origin)...\n" "$TARGET_BRANCH"
    git push -u origin "$TARGET_BRANCH"

    # 11. Verwijder het uitgevoerde patch-bestand automatisch na succesvolle push
    printf "\n"
    rm -f "$PATCH_FILE"
    printf "${GREEN}[OPGERUIMD]${NC} Uitgevoerd patch-bestand '%s' automatisch verwijderd.\n" "$(basename "$PATCH_FILE")"

    CLEAN_PREFIX="$(sanitize_branch_suggestion "$(basename "$PATCH_FILE" .patch)" | tr '/' '-')"
    TMP_OLD="/tmp/qnap_oldpatches_$$.list"
    ls -1 "$REPO_ROOT"/"${CLEAN_PREFIX}"*.patch 2>/dev/null > "$TMP_OLD" || true

    if [ -s "$TMP_OLD" ]; then
        printf "${YELLOW}[INFO]${NC} Er staan nog oudere kopieën van deze patch in de map:\n"
        while IFS= read -r op; do
            [ -n "$op" ] && printf "  - %s\n" "$(basename "$op")"
        done < "$TMP_OLD"
        printf "Deze oudere kopieën ook direct verwijderen? [J/n]: "
        IFS= read -r DEL_OLD
        case "${DEL_OLD:-J}" in
            j|J|y|Y)
                while IFS= read -r op; do
                    [ -n "$op" ] && rm -f "$op"
                done < "$TMP_OLD"
                printf "${GREEN}[OK]${NC} Oudere patch-kopieën verwijderd.\n"
                ;;
        esac
    fi
    rm -f "$TMP_OLD"

    printf "\n${GREEN}=== Klaar! ===${NC}\n"
    printf "Branch ${GREEN}%s${NC} is bijgewerkt en gepusht naar GitHub.\n" "$TARGET_BRANCH"
    git log -n 3 --oneline
fi

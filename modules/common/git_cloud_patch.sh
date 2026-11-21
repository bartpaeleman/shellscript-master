#!/usr/bin/env bash
# modules/common/git_cloud_patch.sh - Cross-platform Antigravity Cloud .patch selector & 3-way applier

# Helper om een bestandsnaam op te schonen tot een geldige Git branch-naam
_gcp_sanitize_branch_suggestion() {
    local raw="$1"
    raw="$(printf '%s' "$raw" | sed 's/[[:space:]]*([0-9][0-9]*)$//; s/[[:space:]][[:space:]]*/-/g')"
    if [[ "$raw" == feature-* ]]; then
        raw="feature/${raw#feature-}"
    elif [[ "$raw" == fix-* ]]; then
        raw="fix/${raw#fix-}"
    fi
    raw="$(printf '%s' "$raw" | tr -cd '[:alnum:]._/-' | sed 's|//*|/|g; s|^/||; s|/$||')"
    printf '%s' "$raw"
}

git_apply_cloud_patch() {
    local PATCH_FILE="${1:-}"
    local TARGET_BRANCH="${2:-}"

    # 1. Controleer of we in een Git-repository zitten
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${RED}[FOUT]${NC} Huidige directory ($(pwd)) is geen geldige Git-repository."
        return 1
    fi

    local REPO_ROOT
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    cd "$REPO_ROOT" || return 1

    # 2. Selecteer het patch-bestand
    if [[ -z "$PATCH_FILE" ]]; then
        echo -e "${CYAN}=== Antigravity Cloud Patch Selector (Cross-Platform) ===${NC}"
        echo -e "Repository: ${GREEN}$REPO_ROOT${NC}\n"

        local -a PATCH_LIST=()
        local f=""
        while IFS= read -r f; do
            [[ -n "$f" ]] && PATCH_LIST+=("$f")
        done < <(ls -t "$REPO_ROOT"/*.patch 2>/dev/null || true)

        if [[ ${#PATCH_LIST[@]} -gt 0 ]]; then
            echo -e "${BOLD}Beschikbare .patch bestanden in projectmap:${NC}"
            local i idx fname fsize fdate
            for i in "${!PATCH_LIST[@]}"; do
                idx=$((i + 1))
                fname="$(basename "${PATCH_LIST[$i]}")"
                fsize="$(wc -c < "${PATCH_LIST[$i]}" | tr -d ' ')"
                fdate="$(date -r "${PATCH_LIST[$i]}" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "")"
                echo -e "  ${GREEN}${idx})${NC} ${fname} ${YELLOW}(${fsize} bytes${fdate:+, $fdate})${NC}"
            done
            echo ""
            echo -e "  ${CYAN}P)${NC} Ander pad of bestand ingeven (met Tab-autocomplete)"
            echo -e "  ${RED}0)${NC} Annuleren / Afsluiten [Default]"
            echo ""

            local CHOICE=""
            read -r -p "Kies nummer, typ bestandsnaam of 'P' [0]: " CHOICE
            CHOICE="${CHOICE:-0}"

            if [[ "$CHOICE" == "0" || "$CHOICE" == "q" || "$CHOICE" == "Q" ]]; then
                echo -e "${YELLOW}[INFO]${NC} Geannuleerd door gebruiker."
                return 0
            elif [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= ${#PATCH_LIST[@]} )); then
                PATCH_FILE="${PATCH_LIST[$((CHOICE - 1))]}"
            elif [[ "$CHOICE" == "p" || "$CHOICE" == "P" ]]; then
                ui_read_path PATCH_FILE "Pad naar .patch bestand (0 = annuleren)"
            else
                if [[ -f "$CHOICE" ]]; then
                    PATCH_FILE="$CHOICE"
                elif [[ -f "$REPO_ROOT/$CHOICE" ]]; then
                    PATCH_FILE="$REPO_ROOT/$CHOICE"
                elif [[ -f "$REPO_ROOT/${CHOICE}.patch" ]]; then
                    PATCH_FILE="$REPO_ROOT/${CHOICE}.patch"
                else
                    PATCH_FILE="$CHOICE"
                fi
            fi
        else
            echo -e "${YELLOW}[INFO]${NC} Geen .patch bestanden gevonden in $REPO_ROOT."
            ui_read_path PATCH_FILE "Geef het pad naar het .patch bestand (0 = annuleren)"
        fi
    fi

    if [[ -z "$PATCH_FILE" || "$PATCH_FILE" == "0" ]]; then
        echo -e "${YELLOW}[INFO]${NC} Geannuleerd door gebruiker."
        return 0
    fi

    if [[ ! -f "$PATCH_FILE" && -f "$REPO_ROOT/$PATCH_FILE" ]]; then
        PATCH_FILE="$REPO_ROOT/$PATCH_FILE"
    fi

    if [[ ! -f "$PATCH_FILE" ]]; then
        echo -e "${RED}[FOUT]${NC} Patch-bestand niet gevonden: '$PATCH_FILE'"
        return 1
    fi

    if [[ ! -s "$PATCH_FILE" ]]; then
        echo -e "${RED}[FOUT]${NC} Patch-bestand '$PATCH_FILE' is leeg (0 bytes)."
        return 1
    fi

    # 3. Haal remote branches op
    echo -e "\n${CYAN}[1/4]${NC} Ophalen van actuele branches van GitHub (origin)..."
    git fetch origin --prune >/dev/null 2>&1 || true

    # 4. Doel-branch kiezen
    if [[ -z "$TARGET_BRANCH" ]]; then
        local RAW_NAME SUGGESTED_BRANCH CURRENT_BR
        RAW_NAME="$(basename "$PATCH_FILE" .patch)"
        SUGGESTED_BRANCH="$(_gcp_sanitize_branch_suggestion "$RAW_NAME")"
        if [[ -z "$SUGGESTED_BRANCH" ]]; then
            CURRENT_BR="$(git rev-parse --abbrev-ref HEAD)"
            SUGGESTED_BRANCH="$([ "$CURRENT_BR" = "main" ] && echo "feature/cloud-patch" || echo "$CURRENT_BR")"
        fi

        local -a EXISTING_BRANCHES=()
        local br=""
        while IFS= read -r br; do
            [[ -n "$br" ]] && EXISTING_BRANCHES+=("$br")
        done < <(
            {
                git branch --format='%(refname:short)'
                git branch -r --format='%(refname:short)' | grep -v 'HEAD' | sed 's|^origin/||'
            } | sort -u
        )

        echo ""
        echo -e "${BOLD}Kies doel-branch voor '$(basename "$PATCH_FILE")':${NC}"
        echo -e "  ${GREEN}N)${NC} Nieuwe branch aanmaken met voorgestelde naam: ${CYAN}${SUGGESTED_BRANCH}${NC} [Default bij Enter]"
        echo -e "  ${CYAN}M)${NC} Handmatig een nieuwe branch-naam intypen"

        if [[ ${#EXISTING_BRANCHES[@]} -gt 0 ]]; then
            echo -e "\n${BOLD}Of voeg toe aan een bestaande branch:${NC}"
            local idx loc_tag rem_tag tag
            for i in "${!EXISTING_BRANCHES[@]}"; do
                idx=$((i + 1))
                br="${EXISTING_BRANCHES[$i]}"
                loc_tag=""
                rem_tag=""
                git show-ref --verify --quiet "refs/heads/$br" && loc_tag="LOKAAL"
                git show-ref --verify --quiet "refs/remotes/origin/$br" && rem_tag="ORIGIN"
                if [[ -n "$loc_tag" && -n "$rem_tag" ]]; then
                    tag="[LOKAAL + ORIGIN]"
                elif [[ -n "$loc_tag" ]]; then
                    tag="[LOKAAL]"
                else
                    tag="[ORIGIN]"
                fi
                echo -e "  ${GREEN}${idx})${NC} ${br} ${YELLOW}${tag}${NC}"
            done
        fi
        echo -e "\n  ${RED}0)${NC} Annuleren"
        echo ""

        local BR_CHOICE="" MANUAL_BR=""
        while true; do
            read -r -p "Keuze (nummer, N, M of typ direct een branch-naam) [N]: " BR_CHOICE
            BR_CHOICE="${BR_CHOICE:-N}"

            if [[ "$BR_CHOICE" == "0" || "$BR_CHOICE" == "q" || "$BR_CHOICE" == "Q" ]]; then
                echo -e "${YELLOW}[INFO]${NC} Geannuleerd door gebruiker."
                return 0
            elif [[ "$BR_CHOICE" == "n" || "$BR_CHOICE" == "N" ]]; then
                TARGET_BRANCH="$SUGGESTED_BRANCH"
            elif [[ "$BR_CHOICE" == "m" || "$BR_CHOICE" == "M" ]]; then
                read -r -p "Typ de gewenste branch-naam (0 = annuleren): " MANUAL_BR
                if [[ "$MANUAL_BR" == "0" || -z "$MANUAL_BR" ]]; then
                    echo -e "${YELLOW}[INFO]${NC} Geannuleerd door gebruiker."
                    return 0
                fi
                TARGET_BRANCH="$MANUAL_BR"
            elif [[ "$BR_CHOICE" =~ ^[0-9]+$ ]] && (( BR_CHOICE >= 1 && BR_CHOICE <= ${#EXISTING_BRANCHES[@]} )); then
                TARGET_BRANCH="${EXISTING_BRANCHES[$((BR_CHOICE - 1))]}"
            else
                TARGET_BRANCH="$BR_CHOICE"
            fi

            if git check-ref-format --branch "$TARGET_BRANCH" >/dev/null 2>&1; then
                break
            else
                echo -e "${RED}[FOUT]${NC} '$TARGET_BRANCH' is geen geldige Git branch-naam."
            fi
        done
    fi

    echo ""
    echo -e "${CYAN}=== Uitvoering ===${NC}"
    echo -e "Patch file : ${GREEN}$(basename "$PATCH_FILE")${NC} ($(wc -c < "$PATCH_FILE" | tr -d ' ') bytes)"
    echo -e "Doelbranch : ${GREEN}$TARGET_BRANCH${NC}"
    echo ""

    # 5. Controleer of er geen onbedoelde lokale wijzigingen of UU-conflictresten openstaan
    local DIRTY_FILES RESET_CHOICE
    DIRTY_FILES="$(git status --porcelain | grep -v '\.patch$' || true)"
    if [[ -n "$DIRTY_FILES" ]]; then
        echo -e "${YELLOW}[WAARSCHUWING]${NC} De repository bevat niet-gecommitte wijzigingen of conflict-resten:"
        echo "$DIRTY_FILES"
        echo ""
        read -r -p "Deze lokale wijzigingen wissen (git reset --hard HEAD) om door te gaan? [j/N]: " RESET_CHOICE
        if [[ "$RESET_CHOICE" =~ ^[jJyY]$ ]]; then
            git am --abort 2>/dev/null || true
            git merge --abort 2>/dev/null || true
            git reset --hard HEAD
            git clean -fd -e "*.patch"
            echo -e "${GREEN}[OK]${NC} Werkdirectory schoongemaakt."
        else
            echo -e "${RED}[FOUT]${NC} Afgebroken. Commit of stash deze wijzigingen eerst."
            return 1
        fi
    fi

    # 6. Ruim eventuele vastgelopen eerdere git am / merge sessies op
    if [[ -d "$REPO_ROOT/.git/rebase-apply" ]]; then
        git am --abort 2>/dev/null || true
    fi
    if [[ -f "$REPO_ROOT/.git/MERGE_HEAD" ]]; then
        git merge --abort 2>/dev/null || true
    fi

    # 7. Schakel naar de gekozen branch en synchroniseer met laatste origin/main
    if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
        echo -e "${CYAN}[2/4]${NC} Overschakelen naar bestaande lokale branch '$TARGET_BRANCH'..."
        git checkout "$TARGET_BRANCH" || return 1
        if git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
            git pull --ff-only origin "$TARGET_BRANCH" || true
        fi
    elif git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
        echo -e "${CYAN}[2/4]${NC} Bestaande remote branch 'origin/$TARGET_BRANCH' uitchecken..."
        git checkout -b "$TARGET_BRANCH" "origin/$TARGET_BRANCH" || return 1
    else
        echo -e "${CYAN}[2/4]${NC} Nieuwe branch '$TARGET_BRANCH' aanmaken vanaf 'origin/main'..."
        git checkout -b "$TARGET_BRANCH" origin/main || return 1
    fi

    # 8. Controleer op dubbele diff --git-regels en pas de patch toe
    echo -e "${CYAN}[3/4]${NC} Patch toepassen op '$TARGET_BRANCH'..."
    local PATCH_APPLIED=false

    if [ "$(grep '^diff --git' "$PATCH_FILE" | sort | uniq -d | wc -l)" -gt 0 ]; then
        echo -e "${YELLOW}[WAARSCHUWING]${NC} Dit patchbestand bevat meerdere opeenvolgende diffs voor hetzelfde bestand (bijv. via git log -p). Gebruik 'git diff HEAD~1..HEAD' i.p.v. meerdere commits."
    fi

    # Probeer eerst schoon, daarna 3-way (slaat reeds gemergede commits automatisch over)
    if git apply --check --whitespace=nowarn "$PATCH_FILE" 2>/dev/null; then
        git apply --whitespace=nowarn "$PATCH_FILE" || return 1
        echo -e "${GREEN}[OK]${NC} Patch schoon toegepast."
        PATCH_APPLIED=true
    elif git apply --3way --whitespace=nowarn "$PATCH_FILE"; then
        echo -e "${GREEN}[OK]${NC} Patch toegepast via 3-way merge (reeds aanwezige wijzigingen overgeslagen)."
        PATCH_APPLIED=true
    else
        echo -e "${RED}[CONFLICT]${NC} Handmatige conflictresolutie nodig (zoek op '<<<<<<<')."
        echo "Los de conflicten op in de onderstaande bestanden, voer 'git add -A && git commit' uit, en push daarna:"
        git status -s | grep -v '\.patch$' || true
        echo ""
        echo "  git push -u origin $TARGET_BRANCH"
        return 1
    fi

    # 9. Commit de toegepaste wijzigingen (indien er netto nog nieuwe wijzigingen overbleven)
    if [[ "$PATCH_APPLIED" == "true" ]]; then
        git add -A
        git reset -- "$PATCH_FILE" 2>/dev/null || true

        if [[ -n "$(git status --porcelain | grep -v '\.patch$' || true)" ]]; then
            local PATCH_SUBJECT
            PATCH_SUBJECT="$(grep -m 1 '^Subject:' "$PATCH_FILE" | sed 's/^Subject:[[:space:]]*//; s/^\[PATCH[^]]*\][[:space:]]*//' || true)"
            if [[ -z "$PATCH_SUBJECT" ]]; then
                PATCH_SUBJECT="feat: apply cloud patch $(basename "$PATCH_FILE" .patch)"
            fi
            git commit -m "$PATCH_SUBJECT" || return 1
        else
            echo -e "${YELLOW}[INFO]${NC} Alle wijzigingen uit deze patch zaten al in '$TARGET_BRANCH' (geen nieuwe commit nodig)."
        fi

        # 10. Push de branch naar GitHub
        echo -e "${CYAN}[4/4]${NC} Pushen van '$TARGET_BRANCH' naar GitHub (origin)..."
        git push -u origin "$TARGET_BRANCH" || return 1

        # 11. Verwijder het uitgevoerde patch-bestand automatisch na succesvolle push
        echo ""
        rm -f "$PATCH_FILE"
        echo -e "${GREEN}[OPGERUIMD]${NC} Uitgevoerd patch-bestand '$(basename "$PATCH_FILE")' automatisch verwijderd."

        local CLEAN_PREFIX old_p DEL_OLD
        CLEAN_PREFIX="$(_gcp_sanitize_branch_suggestion "$(basename "$PATCH_FILE" .patch)" | tr '/' '-')"
        local -a LEFTOVER_PATCHES=()
        while IFS= read -r old_p; do
            [[ -n "$old_p" && -f "$old_p" ]] && LEFTOVER_PATCHES+=("$old_p")
        done < <(ls "$REPO_ROOT"/"${CLEAN_PREFIX}"*.patch 2>/dev/null || true)

        if [[ ${#LEFTOVER_PATCHES[@]} -gt 0 ]]; then
            echo -e "${YELLOW}[INFO]${NC} Er staan nog oudere kopieën van deze patch in de map:"
            for old_p in "${LEFTOVER_PATCHES[@]}"; do
                echo "  - $(basename "$old_p")"
            done
            read -r -p "Deze oudere kopieën ook direct verwijderen? [J/n]: " DEL_OLD
            if [[ -z "$DEL_OLD" || "$DEL_OLD" =~ ^[jJyY]$ ]]; then
                rm -f "${LEFTOVER_PATCHES[@]}"
                echo -e "${GREEN}[OK]${NC} Oudere patch-kopieën verwijderd."
            fi
        fi

        echo ""
        echo -e "${GREEN}=== Klaar! ===${NC}"
        echo -e "Branch ${GREEN}$TARGET_BRANCH${NC} is bijgewerkt en gepusht naar GitHub."
        git log -n 3 --oneline
    fi
}

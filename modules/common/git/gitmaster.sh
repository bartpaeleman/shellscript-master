#!/usr/bin/env bash
# modules/common/git/gitmaster.sh - Universal Git Control Panel (macOS + QNAP/Linux)

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"
source "$MOD_DIR/../git_cloud_patch.sh"

_require_repo() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        ui_err "Not inside a Git repository: $(pwd)"
        return 1
    fi
}

_current_branch() {
    git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "none"
}

show_help() {
    ui_header "GIT MASTER CONTROL PANEL - CLI" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +gitmaster [subcommand]\n\n"
    printf "INFO & INSPECTIE:\n"
    printf "  status          1) Status, branch & last 5 commits\n"
    printf "  diff            2) Pending changes (unstaged + staged)\n"
    printf "  log|tree        3) Commit history (graph tree)\n"
    printf "  compare         4) Compare with origin/<branch> & origin/main\n\n"
    printf "BRANCHING & DEVELOPMENT:\n"
    printf "  start           5) Start feature/fix/ai/refactor branch\n"
    printf "  checkout|co     6) Switch / checkout branch (fzf or list)\n"
    printf "  commit|push     7) Quick commit & push\n"
    printf "  sync|pull       8) Safe pull (--rebase or merge)\n"
    printf "  squash          9) Squash & clean feature branch\n"
    printf "  uat            10) Prepare UAT / merge to staging\n"
    printf "  merge-fix      11) Merge fix/* branch & cleanup\n"
    printf "  tag            12) Create annotated release tag & push\n"
    printf "  merge-main     13) Merge active branch into main (+ Push & Cleanup)\n"
    printf "  patch|apply-patch  Apply Antigravity Cloud .patch (3-way + push)\n\n"
    printf "CLEANUP & MAINTENANCE:\n"
    printf "  prune          14) Prune remote-tracking & [gone] branches\n"
    printf "  delete-branch  15) Delete local / remote branch\n"
    printf "  backup         16) Create timestamped backup snapshot\n"
    printf "  restore-backup 17) Restore backup snapshot\n\n"
    printf "FIX & EMERGENCY RECOVERY:\n"
    printf "  stash-pull     18) Stash / pull / pop\n"
    printf "  undo           19) Undo last commit (soft reset)\n"
    printf "  revert         20) Restore / revert older commit\n"
    printf "  force-sync     21) Force sync (Local <-> Remote)\n"
    printf "  recover        22) Emergency recovery (abort, index.lock, reflog)\n"
    printf "  untrack        23) Untrack / forget file (rm --cached + .gitignore)\n"
    printf "  config         24) Config & token setup\n"
}

# --- CATEGORIE A: INFO & INSPECTIE ---
opt_status() {
    _require_repo || return 1
    ui_section "STATUS & BRANCH"
    git status -sb
    ui_section "LAST 5 COMMITS"
    git log -n 5 --oneline --decorate
}

opt_diff() {
    _require_repo || return 1
    ui_section "UNSTAGED CHANGES"
    git diff --color=always
    ui_section "STAGED CHANGES"
    git diff --cached --color=always
}

opt_tree() {
    _require_repo || return 1
    ui_section "COMMIT HISTORY (TREE)"
    git log --graph --oneline --decorate --all -n 25
}

opt_compare() {
    _require_repo || return 1
    local br; br="$(_current_branch)"
    git fetch origin --quiet 2>/dev/null || true
    ui_section "LOCAL vs origin/$br"
    git log --oneline "origin/${br}..HEAD" 2>/dev/null || ui_warn "No origin/$br tracking branch."
    ui_section "REMOTE UPDATES (origin/$br vs HEAD)"
    git log --oneline "HEAD..origin/${br}" 2>/dev/null || true
    ui_section "LOCAL vs origin/main"
    git log --oneline "origin/main..HEAD" 2>/dev/null || true
}

# --- CATEGORIE B: BRANCHING & DEVELOPMENT ---
opt_start_branch() {
    _require_repo || return 1
    ui_section "START FEATURE / AI BRANCH"
    echo "  1) feature/  2) fix/  3) ai/  4) refactor/  0) Cancel / Terug"
    local t=""
    ui_prompt_input t "Select type [1-4]" "1" || return 0
    local prefix="feature/"
    case "$t" in
        2) prefix="fix/" ;;
        3) prefix="ai/" ;;
        4) prefix="refactor/" ;;
    esac
    local bname=""
    ui_prompt_input bname "Branch name (without prefix)" || return 0
    [[ -z "$bname" ]] && { ui_cancel_msg; return 0; }
    if ui_confirm_action "Sync main first?"; then
        git checkout main 2>/dev/null && git pull --rebase origin main 2>/dev/null || true
    fi
    git checkout -b "${prefix}${bname}"
}

_collect_branches() {
    git fetch --all --prune >/dev/null 2>&1 || true
    local local_branches remote_branches
    local_branches="$(git branch --format='%(refname:short)' 2>/dev/null)"
    remote_branches="$(git branch -r --format='%(refname:short)' 2>/dev/null | grep -v 'HEAD' | sed 's|^origin/||')"

    BRANCH_LIST=()
    BRANCH_HAS_LOCAL=()
    BRANCH_HAS_REMOTE=()
    BRANCH_TAGS=()

    local b
    while IFS= read -r b; do
        [[ -z "$b" ]] && continue
        BRANCH_LIST+=("$b")
        BRANCH_HAS_LOCAL+=("1")
        BRANCH_HAS_REMOTE+=("0")
        BRANCH_TAGS+=("LOKAAL")
    done <<< "$local_branches"

    while IFS= read -r b; do
        [[ -z "$b" ]] && continue
        local i found=0
        for ((i=0; i<${#BRANCH_LIST[@]}; i++)); do
            if [[ "${BRANCH_LIST[$i]}" == "$b" ]]; then
                BRANCH_HAS_REMOTE[$i]="1"
                BRANCH_TAGS[$i]="LOKAAL + REMOTE"
                found=1
                break
            fi
        done
        if [[ "$found" -eq 0 ]]; then
            BRANCH_LIST+=("$b")
            BRANCH_HAS_LOCAL+=("0")
            BRANCH_HAS_REMOTE+=("1")
            BRANCH_TAGS+=("REMOTE - origin")
        fi
    done <<< "$remote_branches"
}

opt_checkout() {
    _require_repo || return 1
    _collect_branches

    if [[ ${#BRANCH_LIST[@]} -eq 0 ]]; then
        ui_warn "Geen branches gevonden."
        return 0
    fi

    local cur; cur="$(_current_branch)"
    ui_section "SWITCH / CHECKOUT BRANCH"
    local i
    for ((i=0; i<${#BRANCH_LIST[@]}; i++)); do
        local marker=" "
        [[ "${BRANCH_LIST[$i]}" == "$cur" ]] && marker="*"
        if [[ "${BRANCH_TAGS[$i]}" == "LOKAAL" ]]; then
            printf "  %b%2d)%b %s %-33s %b[%s]%b\n" "${CYAN}${BOLD}" "$((i+1))" "${NC}" "$marker" "${BRANCH_LIST[$i]}" "${GREEN}" "${BRANCH_TAGS[$i]}" "${NC}"
        elif [[ "${BRANCH_TAGS[$i]}" == "LOKAAL + REMOTE" ]]; then
            printf "  %b%2d)%b %s %-33s %b[%s]%b\n" "${CYAN}${BOLD}" "$((i+1))" "${NC}" "$marker" "${BRANCH_LIST[$i]}" "${CYAN}" "${BRANCH_TAGS[$i]}" "${NC}"
        else
            printf "  %b%2d)%b %s %-33s %b[%s]%b\n" "${CYAN}${BOLD}" "$((i+1))" "${NC}" "$marker" "${BRANCH_LIST[$i]}" "${YELLOW}" "${BRANCH_TAGS[$i]}" "${NC}"
        fi
    done
    printf "  %b 0)%b Terug / Annuleren\n\n" "${CYAN}${BOLD}" "${NC}"

    local num=""
    ui_read_menu_choice num "Select branch"
    if [[ "$num" == "0" || "$num" == "q" || "$num" == "Q" ]]; then
        ui_cancel_msg
        return 0
    fi
    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 && "$num" -le ${#BRANCH_LIST[@]} ]]; then
        local idx=$((num-1))
        local target="${BRANCH_LIST[$idx]}"
        if [[ "${BRANCH_TAGS[$idx]}" == "REMOTE - origin" ]]; then
            git checkout -b "$target" "origin/$target" 2>/dev/null || git checkout "$target"
        else
            git checkout "$target"
        fi
    else
        ui_cancel_msg
    fi
}

opt_quick_commit_push() {
    _require_repo || return 1
    ui_section "CHANGED FILES PREVIEW"
    git status -s
    ui_confirm_action "Stage all & commit?" || return 0
    local msg=""
    ui_prompt_input msg "Commit message" || return 0
    [[ -z "$msg" ]] && { ui_cancel_msg; return 0; }
    git add . && git commit -m "$msg" && git push -u origin "$(_current_branch)"
}

opt_sync_pull() {
    _require_repo || return 1
    ui_section "SYNC / PULL"
    echo "  1) Standard Pull (Merge / Fast-Forward — standaard 'git pull' gedrag) [Default]"
    echo "  2) Rebase Pull (Zet jouw lokale commits bovenop de laatste remote wijzigingen — lineaire historie)"
    echo "  0) Cancel / Terug naar menu"
    local mode=""
    read -rp "Choice [1/2/0, Enter=1]: " mode
    case "${mode:-1}" in
        0|q|Q|c|cancel)
            ui_cancel_msg
            return 0
            ;;
        2)
            git pull --rebase origin "$(_current_branch)"
            ;;
        1|"")
            git pull origin "$(_current_branch)"
            ;;
        *)
            ui_warn "Invalid choice."
            ui_cancel_msg
            return 0
            ;;
    esac
}

opt_squash() {
    _require_repo || return 1
    local br; br="$(_current_branch)"
    [[ "$br" == "main" || "$br" == "master" ]] && { ui_err "Cannot squash main/master directly."; return 1; }
    local base=""
    ui_prompt_input base "Base branch to squash against [main]" "main" || return 0
    local merge_base; merge_base="$(git merge-base "$base" HEAD 2>/dev/null || true)"
    [[ -z "$merge_base" ]] && { ui_err "Could not find merge-base with $base."; return 1; }
    local msg=""
    ui_prompt_input msg "Squash commit message" || return 0
    [[ -z "$msg" ]] && { ui_cancel_msg; return 0; }
    git reset --soft "$merge_base" && git commit -m "$msg"
}

opt_prepare_uat() {
    _require_repo || return 1
    local src; src="$(_current_branch)"
    local tgt=""
    ui_prompt_input tgt "Target staging branch [uat]" "uat" || return 0
    ui_confirm_action "Merge '$src' into '$tgt'?" || return 0
    git checkout "$tgt" && git merge "$src"
}

opt_merge_fix() {
    _require_repo || return 1
    local cur; cur="$(_current_branch)"
    local fix_b=""
    ui_prompt_input fix_b "Fix branch to merge into '$cur' (e.g. fix/bug)" || return 0
    [[ -z "$fix_b" ]] && { ui_cancel_msg; return 0; }
    git merge "$fix_b" || return 1
    if ui_confirm_action "Delete '$fix_b' locally and on origin?"; then
        git branch -d "$fix_b" 2>/dev/null || git branch -D "$fix_b"
        git push origin --delete "$fix_b" 2>/dev/null || true
    fi
}

opt_merge_to_main() {
    _require_repo || return 1
    local current_branch; current_branch="$(_current_branch)"
    local main_branch="main"
    if ! git show-ref --verify --quiet refs/heads/main; then
        git show-ref --verify --quiet refs/heads/master && main_branch="master"
    fi

    if [[ "$current_branch" == "$main_branch" ]]; then
        ui_warn "Je zit al op '$main_branch'; kies eerst een feature-branch om te mergen."
        return 0
    fi

    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        ui_warn "Working tree heeft uncommitted wijzigingen."
        if ui_confirm_action "Eerst stashen ('git stash push -u')?"; then
            git stash push -u -m "gitmaster-pre-merge" || return 1
        else
            return 0
        fi
    fi

    ui_section "MERGE '$current_branch' -> '$main_branch'"
    echo "  1) Lokaal mergen naar $main_branch"
    echo "  2) Lokaal mergen naar $main_branch EN direct pushen naar GitHub (origin/$main_branch) [Default]"
    echo "  0) Annuleren"
    local mode=""
    read -rp "Choice [1/2/0, Enter=2]: " mode
    case "${mode:-2}" in
        0|q|Q|c|cancel) ui_cancel_msg; return 0 ;;
        1|2) ;;
        *) ui_cancel_msg; return 0 ;;
    esac

    git fetch origin >/dev/null 2>&1 || true
    git checkout "$main_branch" || return 1
    git pull origin "$main_branch" 2>/dev/null || true

    if ! git merge --no-ff "$current_branch" -m "Merge branch '$current_branch' into $main_branch"; then
        ui_err "Merge-conflict opgetreden tijdens mergen van '$current_branch' in '$main_branch'!"
        if ui_confirm_action "Merge afbreken ('git merge --abort')?"; then
            git merge --abort
            ui_info "Merge afgebroken; repository hersteld."
        fi
        return 1
    fi
    ui_ok "Merged '$current_branch' into '$main_branch'."

    if [[ "${mode:-2}" == "2" ]]; then
        git push origin "$main_branch" || return 1
        ui_ok "Pushed '$main_branch' to origin/$main_branch."
    fi

    ui_section "BRANCH CLEANUP ('$current_branch')"
    echo "  1) Verwijder '$current_branch' alleen LOKAAL (git branch -d)"
    echo "  2) Verwijder '$current_branch' alleen op GITHUB (git push origin --delete)"
    echo "  3) Verwijder '$current_branch' zowel LOKAAL als op GITHUB"
    echo "  0) Behoud '$current_branch' (overslaan)"
    local cl=""
    ui_read_menu_choice cl "Choice"
    case "$cl" in
        1) git branch -d "$current_branch" ;;
        2) git push origin --delete "$current_branch" ;;
        3) git branch -d "$current_branch" && git push origin --delete "$current_branch" ;;
        *) ui_info "Branch '$current_branch' behouden." ;;
    esac
    return 0
}

opt_release_tag() {
    _require_repo || return 1
    local tag=""
    ui_prompt_input tag "Tag version (e.g. v1.2.0)" || return 0
    [[ -z "$tag" ]] && { ui_cancel_msg; return 0; }
    local msg=""
    ui_prompt_input msg "Tag message [Release $tag]" "Release $tag" || return 0
    git tag -a "$tag" -m "$msg" && git push origin --tags
}

# --- CATEGORIE C: CLEANUP & MAINTENANCE ---
opt_prune() {
    _require_repo || return 1
    git fetch --prune
    ui_section "GONE LOCAL BRANCHES"
    local gone
    gone="$(git branch -vv | awk '/: gone]/{print $1}')"
    if [[ -z "$gone" ]]; then
        ui_ok "No [gone] branches found."
        return 0
    fi
    echo "$gone"
    read -rp "Delete these local [gone] branches? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        echo "$gone" | xargs -n 1 git branch -D
    fi
}

_delete_local_branch() {
    local target="$1"
    if ! git branch -d "$target"; then
        local ans=""
        read -rp "Branch '$target' is nog niet volledig gemerged. Force delete met 'git branch -D'? [j/N]: " ans
        if [[ "$ans" =~ ^[jJyY]$ ]]; then
            git branch -D "$target"
        else
            ui_cancel_msg
            return 1
        fi
    fi
    return 0
}

opt_delete_branch() {
    _require_repo || return 1
    _collect_branches

    if [[ ${#BRANCH_LIST[@]} -eq 0 ]]; then
        ui_warn "Geen branches gevonden."
        return 0
    fi

    local cur; cur="$(_current_branch)"
    ui_section "DELETE BRANCH"
    local i
    for ((i=0; i<${#BRANCH_LIST[@]}; i++)); do
        local bname="${BRANCH_LIST[$i]}"
        local tag="${BRANCH_TAGS[$i]}"
        local extra=""
        local marker=" "
        if [[ "$bname" == "$cur" ]]; then
            marker="*"
            extra=" ${RED}[HUIDIG - beschermd]${NC}"
        elif [[ "$bname" == "main" || "$bname" == "master" ]]; then
            extra=" ${RED}[BESCHERMD]${NC}"
        fi

        if [[ "$tag" == "LOKAAL" ]]; then
            printf "  %b%2d)%b %s %-33s %b[%s]%b%b\n" "${CYAN}${BOLD}" "$((i+1))" "${NC}" "$marker" "$bname" "${GREEN}" "$tag" "${NC}" "$extra"
        elif [[ "$tag" == "LOKAAL + REMOTE" ]]; then
            printf "  %b%2d)%b %s %-33s %b[%s]%b%b\n" "${CYAN}${BOLD}" "$((i+1))" "${NC}" "$marker" "$bname" "${CYAN}" "$tag" "${NC}" "$extra"
        else
            printf "  %b%2d)%b %s %-33s %b[%s]%b%b\n" "${CYAN}${BOLD}" "$((i+1))" "${NC}" "$marker" "$bname" "${YELLOW}" "$tag" "${NC}" "$extra"
        fi
    done
    printf "  %b 0)%b Terug (Annuleren)\n\n" "${CYAN}${BOLD}" "${NC}"

    local sel=""
    ui_read_menu_choice sel "Select branch (nummer of naam)"
    if [[ "$sel" == "0" || "$sel" == "q" || "$sel" == "Q" ]]; then
        ui_cancel_msg
        return 0
    fi

    local target="" is_local="0" is_remote="0"
    if [[ "$sel" =~ ^[0-9]+$ ]] && [[ "$sel" -ge 1 && "$sel" -le ${#BRANCH_LIST[@]} ]]; then
        local idx=$((sel-1))
        target="${BRANCH_LIST[$idx]}"
        is_local="${BRANCH_HAS_LOCAL[$idx]}"
        is_remote="${BRANCH_HAS_REMOTE[$idx]}"
    else
        target="$sel"
        for ((i=0; i<${#BRANCH_LIST[@]}; i++)); do
            if [[ "${BRANCH_LIST[$i]}" == "$target" ]]; then
                is_local="${BRANCH_HAS_LOCAL[$i]}"
                is_remote="${BRANCH_HAS_REMOTE[$i]}"
                break
            fi
        done
        if [[ "$is_local" == "0" && "$is_remote" == "0" ]]; then
            git show-ref --verify --quiet "refs/heads/$target" 2>/dev/null && is_local="1"
            git show-ref --verify --quiet "refs/remotes/origin/$target" 2>/dev/null && is_remote="1"
        fi
        if [[ "$is_local" == "0" && "$is_remote" == "0" ]]; then
            ui_err "Branch '$target' niet gevonden."
            return 1
        fi
    fi

    if [[ "$target" == "$cur" || "$target" == "main" || "$target" == "master" ]]; then
        ui_err "De actieve branch of hoofdbranch (main/master) kan niet worden verwijderd."
        return 1
    fi

    ui_section "VERWIJDERACTIE VOOR: $target"
    echo -e "  Locatie: Lokaal=$([[ "$is_local" == "1" ]] && echo "${GREEN}Ja${NC}" || echo "${DIM}Nee${NC}") | GitHub (origin)=$([[ "$is_remote" == "1" ]] && echo "${GREEN}Ja${NC}" || echo "${DIM}Nee${NC}")"
    echo ""
    [[ "$is_local" == "1" ]]  && echo "  1) Alleen LOKAAL verwijderen (veilige check: git branch -d)"
    [[ "$is_remote" == "1" ]] && echo "  2) Alleen op GITHUB verwijderen (git push origin --delete)"
    [[ "$is_local" == "1" && "$is_remote" == "1" ]] && echo "  3) Zowel LOKAAL als op GITHUB verwijderen"
    echo "  0) Annuleren (Enter = 0)"
    echo ""

    local action=""
    ui_read_menu_choice action "Keuze"
    case "$action" in
        0|q|Q)
            ui_cancel_msg
            return 0
            ;;
        1)
            if [[ "$is_local" != "1" ]]; then
                ui_warn "Branch '$target' bestaat niet lokaal."
                return 1
            fi
            _delete_local_branch "$target" && ui_ok "Lokale branch '$target' verwijderd."
            ;;
        2)
            if [[ "$is_remote" != "1" ]]; then
                ui_warn "Branch '$target' bestaat niet op GitHub (origin)."
                return 1
            fi
            git push origin --delete "$target" && ui_ok "Remote branch 'origin/$target' verwijderd."
            ;;
        3)
            if [[ "$is_local" == "1" ]]; then
                _delete_local_branch "$target" || return 1
                ui_ok "Lokale branch '$target' verwijderd."
            fi
            if [[ "$is_remote" == "1" ]]; then
                git push origin --delete "$target" || return 1
                ui_ok "Remote branch 'origin/$target' verwijderd."
            fi
            ;;
        *)
            ui_warn "Ongeldige keuze."
            return 1
            ;;
    esac
    return 0
}

opt_backup() {
    _require_repo || return 1
    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    local br; br="$(_current_branch)"
    local bname="backup/${ts}-${br}"
    git branch "$bname" && ui_ok "Created backup branch: $bname"
}

opt_restore_backup() {
    _require_repo || return 1
    git branch --list 'backup/*'
    read -rp "Backup branch to restore/checkout: " bname
    [[ -z "$bname" ]] && return 0
    git checkout "$bname"
}

# --- CATEGORIE D: FIX & EMERGENCY RECOVERY ---
opt_stash_pull_pop() {
    _require_repo || return 1
    git stash push -u -m "gitmaster-auto" && git pull --rebase origin "$(_current_branch)" && git stash pop
}

opt_undo_last() {
    _require_repo || return 1
    git reset --soft HEAD~1 && ui_ok "Last commit undone (changes kept in staging)."
}

opt_revert_commit() {
    _require_repo || return 1
    git log -n 15 --oneline
    local h=""
    ui_prompt_input h "Commit hash to revert (safe undo commit)" || return 0
    if [[ -n "$h" ]]; then
        git revert "$h"
    else
        ui_info "Geen commit opgegeven; niets gewijzigd."
    fi
    return 0
}

opt_force_sync() {
    _require_repo || return 1
    local br; br="$(_current_branch)"
    printf "%b[WARNING] Destructive operation!%b\n" "${RED}${BOLD}" "${NC}"
    echo "  1) Overwrite LOCAL with origin/$br (git reset --hard)"
    echo "  2) Force push LOCAL to origin/$br (--force-with-lease)"
    echo "  0) Cancel / Terug"
    local c=""
    ui_prompt_input c "Choice [1/2]" || return 0
    case "$c" in
        1) ui_confirm_action "Overwrite local '$br' with origin/$br?" && git fetch origin && git reset --hard "origin/$br" ;;
        2) ui_confirm_action "Force push (--force-with-lease) to origin/$br?" && git push --force-with-lease origin "$br" ;;
        *) ui_cancel_msg ;;
    esac
}

opt_emergency_recovery() {
    _require_repo || return 1
    echo "1) Abort merge/rebase  2) Remove .git/index.lock  3) Show reflog"
    read -rp "Choice [1-3]: " c
    case "$c" in
        1) git merge --abort 2>/dev/null || git rebase --abort 2>/dev/null || ui_info "Nothing to abort." ;;
        2) rm -f .git/index.lock && ui_ok "Removed .git/index.lock" ;;
        3) git reflog -n 20 ;;
    esac
}

opt_untrack() {
    _require_repo || return 1
    local f=""
    ui_prompt_input f "File path to untrack" || return 0
    [[ -z "$f" ]] && { ui_cancel_msg; return 0; }
    git rm --cached "$f" || return 1
    if ui_confirm_action "Add '$f' to .gitignore?"; then
        echo "$f" >> .gitignore && ui_ok "Added to .gitignore"
    fi
    return 0
}

opt_config() {
    ui_section "GIT CONFIG"
    echo "user.name  : $(git config user.name 2>/dev/null || echo unset)"
    echo "user.email : $(git config user.email 2>/dev/null || echo unset)"
    local changed=0 un="" ue=""
    ui_prompt_input un "Update user.name (Enter to skip)" "" || return 0
    if [[ -n "$un" ]]; then
        git config user.name "$un" && changed=1
    fi
    ui_prompt_input ue "Update user.email (Enter to skip)" "" || return 0
    if [[ -n "$ue" ]]; then
        git config user.email "$ue" && changed=1
    fi
    if [[ "$changed" -eq 0 ]]; then
        ui_info "Geen wijzigingen doorgevoerd; huidige configuratie behouden."
    else
        ui_ok "Git configuratie bijgewerkt."
    fi
    return 0
}

_git_compact_header() {
    local subtitle="$1"
    local br="none"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 && br="$(_current_branch)"
    printf "%b=== GIT MASTER: %s ===%b (%b%s%b | Branch: %b%s%b)\n" \
        "${GREEN}${BOLD}" "$subtitle" "${NC}" "${CYAN}" "${OS_TYPE}" "${NC}" "${YELLOW}" "${br}" "${NC}"
    ui_divider
}

git_sub_status() {
    while true; do
        ui_clear_screen
        _git_compact_header "STATUS, DIFF & LOG"
        ui_item "1" "Status & Branch Info"   "Status + last 5 commits"
        ui_item "2" "Pending Changes (Diff)" "Unstaged & staged diff"
        ui_item "3" "Commit History (Tree)"  "Graph log"
        ui_item "4" "Compare with Remote"    "Local vs origin"
        ui_item "0" "Terug"                  ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "Status & Branch Info" opt_status ;;
            2) ui_run_safe "Pending Changes (Diff)" opt_diff ;;
            3) ui_run_safe "Commit History (Tree)" opt_tree ;;
            4) ui_run_safe "Compare with Remote" opt_compare ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

git_sub_workflow() {
    while true; do
        ui_clear_screen
        _git_compact_header "DAGELIJKSE WORKFLOW"
        ui_item "1" "Quick Commit & Push"    "Preview, add, commit, push"
        ui_item "2" "Sync / Pull"            "Safe rebase or merge"
        ui_item "3" "Stash / Pull / Pop"     "Safe update with dirty tree"
        ui_item "0" "Terug"                  ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "Quick Commit & Push" opt_quick_commit_push ;;
            2) ui_run_safe "Sync / Pull" opt_sync_pull ;;
            3) ui_run_safe "Stash / Pull / Pop" opt_stash_pull_pop ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

git_sub_branches() {
    while true; do
        ui_clear_screen
        _git_compact_header "BRANCHES & MERGING"
        ui_item "1" "Start Feature/AI Branch" "feature/, fix/, ai/, refactor/"
        ui_item "2" "Switch / Checkout"       "Local & remote branches"
        ui_item "3" "Squash & Clean Branch"   "Squash feature commits"
        ui_item "4" "Prepare UAT / Staging"   "Merge to uat"
        ui_item "5" "Merge Fix & Cleanup"     "Merge fix/* & delete"
        ui_item "6" "Merge Active -> Main"    "Merge, push & safe branch cleanup"
        ui_item "7" "Delete Branch"           "Local & optional origin"
        ui_item "0" "Terug"                   ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "Start Feature/AI Branch" opt_start_branch ;;
            2) ui_run_safe "Switch / Checkout" opt_checkout ;;
            3) ui_run_safe "Squash & Clean Branch" opt_squash ;;
            4) ui_run_safe "Prepare UAT / Staging" opt_prepare_uat ;;
            5) ui_run_safe "Merge Fix & Cleanup" opt_merge_fix ;;
            6) ui_run_safe "Merge Active -> Main" opt_merge_to_main ;;
            7) ui_run_safe "Delete Branch" opt_delete_branch ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

git_sub_recovery() {
    while true; do
        ui_clear_screen
        _git_compact_header "STASH & HERSTEL"
        ui_item "1" "Undo Last Commit (Soft)" "reset --soft HEAD~1"
        ui_item "2" "Revert Older Commit"     "Safe git revert"
        ui_item "3" "Force Sync"              "reset --hard or --force-with-lease"
        ui_item "4" "Emergency Recovery"      "Abort, index.lock, reflog"
        ui_item "5" "Backup Snapshot Point"   "Create backup/timestamp branch"
        ui_item "6" "Restore Backup Point"    "Checkout backup branch"
        ui_item "7" "Untrack / Forget File"   "rm --cached + .gitignore"
        ui_item "0" "Terug"                   ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "Undo Last Commit" opt_undo_last ;;
            2) ui_run_safe "Revert Older Commit" opt_revert_commit ;;
            3) ui_run_safe "Force Sync" opt_force_sync ;;
            4) ui_run_safe "Emergency Recovery" opt_emergency_recovery ;;
            5) ui_run_safe "Backup Snapshot Point" opt_backup ;;
            6) ui_run_safe "Restore Backup Point" opt_restore_backup ;;
            7) ui_run_safe "Untrack / Forget File" opt_untrack ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

git_sub_remotes() {
    while true; do
        ui_clear_screen
        _git_compact_header "REMOTES, TAGS & ONDERHOUD"
        ui_item "1" "Release Tag & Push"      "Annotated tag + push"
        ui_item "2" "Prune Gone Branches"     "fetch --prune + delete [gone]"
        ui_item "3" "Compare with Remote"     "Local vs origin"
        ui_item "0" "Terug"                   ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "Release Tag & Push" opt_release_tag ;;
            2) ui_run_safe "Prune Gone Branches" opt_prune ;;
            3) ui_run_safe "Compare with Remote" opt_compare ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

git_menu() {
    while true; do
        ui_clear_screen
        _git_compact_header "HOOFDMENU"
        ui_item "1" "Status, Diff & Log"       "Status, Diff, History, Compare"
        ui_item "2" "Dagelijkse Workflow"      "Commit & Push, Sync/Pull, Stash"
        ui_item "3" "Branches & Merging"       "Start, Switch, Merge, Main, Delete"
        ui_item "4" "Stash & Herstel"          "Undo, Revert, Force, Backup, Untrack"
        ui_item "5" "Remotes, Tags & Onderhoud" "Release Tag, Prune, Compare"
        ui_item "6" "Config & Token Setup"     "user.name / user.email / token"
        ui_item "0" "Terug"                    "Naar scripter hoofdmenu"
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) git_sub_status ;;
            2) git_sub_workflow ;;
            3) git_sub_branches ;;
            4) git_sub_recovery ;;
            5) git_sub_remotes ;;
            6) ui_run_safe "Config & Token Setup" opt_config ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help)          show_help ;;
    status|st)               opt_status ;;
    diff|df)                 opt_diff ;;
    history|log|tree)        opt_tree ;;
    compare)                 opt_compare ;;
    start)                   opt_start_branch ;;
    switch|sw|checkout|co)   opt_checkout ;;
    commit|ci|push)          opt_quick_commit_push ;;
    sync|pull)               opt_sync_pull ;;
    squash|sq)               opt_squash ;;
    uat)                     opt_prepare_uat ;;
    merge-fix)               opt_merge_fix ;;
    merge-main)              opt_merge_to_main ;;
    tag)                     opt_release_tag ;;
    prune|pr)                opt_prune ;;
    delete-branch)           opt_delete_branch ;;
    backup|bak)              opt_backup ;;
    restore|rst|restore-backup) opt_restore_backup ;;
    stash-pull)              opt_stash_pull_pop ;;
    undo)                    opt_undo_last ;;
    revert)                  opt_revert_commit ;;
    force-sync)              opt_force_sync ;;
    recover)                 opt_emergency_recovery ;;
    untrack)                 opt_untrack ;;
    config)                  opt_config ;;
    patch|apply-patch)       shift; git_apply_cloud_patch "$@" ;;
    menu)                    git_menu ;;
    *)                       ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

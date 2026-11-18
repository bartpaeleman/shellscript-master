#!/usr/bin/env bash
# modules/common/git/gitmaster.sh - Universal Git Control Panel (macOS + QNAP/Linux)

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

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
    printf "  tag            12) Create annotated release tag & push\n\n"
    printf "CLEANUP & MAINTENANCE:\n"
    printf "  prune          13) Prune remote-tracking & [gone] branches\n"
    printf "  delete-branch  14) Delete local / remote branch\n"
    printf "  backup         15) Create timestamped backup snapshot\n"
    printf "  restore-backup 16) Restore backup snapshot\n\n"
    printf "FIX & EMERGENCY RECOVERY:\n"
    printf "  stash-pull     17) Stash / pull / pop\n"
    printf "  undo           18) Undo last commit (soft reset)\n"
    printf "  revert         19) Restore / revert older commit\n"
    printf "  force-sync     20) Force sync (Local <-> Remote)\n"
    printf "  recover        21) Emergency recovery (abort, index.lock, reflog)\n"
    printf "  untrack        22) Untrack / forget file (rm --cached + .gitignore)\n"
    printf "  config         23) Config & token setup\n"
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
    echo "Types: 1) feature/  2) fix/  3) ai/  4) refactor/"
    read -rp "Select type [1-4]: " t
    local prefix="feature/"
    case "$t" in
        2) prefix="fix/" ;;
        3) prefix="ai/" ;;
        4) prefix="refactor/" ;;
    esac
    read -rp "Branch name (without prefix): " bname
    [[ -z "$bname" ]] && { ui_warn "Aborted."; return 1; }
    read -rp "Sync main first? [y/N]: " sync_m
    if [[ "$sync_m" =~ ^[Yy]$ ]]; then
        git checkout main 2>/dev/null && git pull --rebase origin main 2>/dev/null || true
    fi
    git checkout -b "${prefix}${bname}"
}

opt_checkout() {
    _require_repo || return 1
    git fetch --all --quiet 2>/dev/null || true
    local target=""
    if command -v fzf >/dev/null 2>&1; then
        target="$(git branch -a | sed 's/^[* ]*//' | grep -v 'HEAD' | fzf --prompt="Checkout branch: ")"
    else
        local branches=()
        local i=1
        while IFS= read -r b; do
            b="${b#\* }"; b="${b#  }"
            [[ -z "$b" || "$b" == *"->"* ]] && continue
            branches+=("$b")
            printf "  %2d) %s\n" "$i" "$b"
            ((i++))
        done < <(git branch -a)
        read -rp "Select number: " num
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 && "$num" -le ${#branches[@]} ]]; then
            target="${branches[$((num-1))]}"
        fi
    fi
    [[ -z "$target" ]] && return 0
    if [[ "$target" == remotes/origin/* ]]; then
        local local_b="${target#remotes/origin/}"
        git checkout -b "$local_b" "$target" 2>/dev/null || git checkout "$local_b"
    else
        git checkout "$target"
    fi
}

opt_quick_commit_push() {
    _require_repo || return 1
    ui_section "CHANGED FILES PREVIEW"
    git status -s
    read -rp "Stage all & commit? [y/N]: " ans
    [[ ! "$ans" =~ ^[Yy]$ ]] && return 0
    read -rp "Commit message: " msg
    [[ -z "$msg" ]] && { ui_warn "Empty message, aborted."; return 1; }
    git add . && git commit -m "$msg" && git push -u origin "$(_current_branch)"
}

opt_sync_pull() {
    _require_repo || return 1
    read -rp "Use rebase (r) or merge (m)? [r/m]: " mode
    if [[ "$mode" == "m" || "$mode" == "M" ]]; then
        git pull origin "$(_current_branch)"
    else
        git pull --rebase origin "$(_current_branch)"
    fi
}

opt_squash() {
    _require_repo || return 1
    local br; br="$(_current_branch)"
    [[ "$br" == "main" || "$br" == "master" ]] && { ui_err "Cannot squash main/master directly."; return 1; }
    read -rp "Base branch to squash against [main]: " base
    base="${base:-main}"
    local merge_base; merge_base="$(git merge-base "$base" HEAD 2>/dev/null || true)"
    [[ -z "$merge_base" ]] && { ui_err "Could not find merge-base with $base."; return 1; }
    read -rp "Squash commit message: " msg
    [[ -z "$msg" ]] && { ui_warn "Empty message, aborted."; return 1; }
    git reset --soft "$merge_base" && git commit -m "$msg"
}

opt_prepare_uat() {
    _require_repo || return 1
    local src; src="$(_current_branch)"
    read -rp "Target staging branch [uat]: " tgt
    tgt="${tgt:-uat}"
    read -rp "Merge '$src' into '$tgt'? [y/N]: " ans
    [[ ! "$ans" =~ ^[Yy]$ ]] && return 0
    git checkout "$tgt" && git merge "$src"
}

opt_merge_fix() {
    _require_repo || return 1
    local cur; cur="$(_current_branch)"
    read -rp "Fix branch to merge into '$cur' (e.g. fix/bug): " fix_b
    [[ -z "$fix_b" ]] && return 0
    git merge "$fix_b" || return 1
    read -rp "Delete '$fix_b' locally and on origin? [y/N]: " del
    if [[ "$del" =~ ^[Yy]$ ]]; then
        git branch -d "$fix_b" 2>/dev/null || git branch -D "$fix_b"
        git push origin --delete "$fix_b" 2>/dev/null || true
    fi
}

opt_release_tag() {
    _require_repo || return 1
    read -rp "Tag version (e.g. v1.2.0): " tag
    [[ -z "$tag" ]] && return 0
    read -rp "Tag message [Release $tag]: " msg
    git tag -a "$tag" -m "${msg:-Release $tag}" && git push origin --tags
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

opt_delete_branch() {
    _require_repo || return 1
    local cur; cur="$(_current_branch)"
    git branch
    read -rp "Branch to delete: " b
    [[ -z "$b" ]] && return 0
    if [[ "$b" == "main" || "$b" == "master" || "$b" == "$cur" ]]; then
        ui_err "Refusing to delete protected/active branch '$b' without manual override."
        return 1
    fi
    git branch -d "$b" || { read -rp "Not merged. Force delete (-D)? [y/N]: " f; [[ "$f" =~ ^[Yy]$ ]] && git branch -D "$b"; }
    read -rp "Also delete on origin? [y/N]: " rem
    [[ "$rem" =~ ^[Yy]$ ]] && git push origin --delete "$b" 2>/dev/null || true
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
    read -rp "Commit hash to revert (safe undo commit): " h
    [[ -n "$h" ]] && git revert "$h"
}

opt_force_sync() {
    _require_repo || return 1
    local br; br="$(_current_branch)"
    printf "%b[WARNING] Destructive operation!%b\n" "${RED}${BOLD}" "${NC}"
    echo "1) Overwrite LOCAL with origin/$br (git reset --hard)"
    echo "2) Force push LOCAL to origin/$br (--force-with-lease)"
    read -rp "Choice [1/2]: " c
    case "$c" in
        1) git fetch origin && git reset --hard "origin/$br" ;;
        2) git push --force-with-lease origin "$br" ;;
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
    read -rp "File path to untrack: " f
    [[ -z "$f" ]] && return 0
    git rm --cached "$f"
    read -rp "Add '$f' to .gitignore? [y/N]: " ans
    [[ "$ans" =~ ^[Yy]$ ]] && echo "$f" >> .gitignore && ui_ok "Added to .gitignore"
}

opt_config() {
    ui_section "GIT CONFIG"
    echo "user.name  : $(git config user.name || echo unset)"
    echo "user.email : $(git config user.email || echo unset)"
    read -rp "Update user.name (leave blank to skip): " un
    [[ -n "$un" ]] && git config user.name "$un"
    read -rp "Update user.email (leave blank to skip): " ue
    [[ -n "$ue" ]] && git config user.email "$ue"
}

git_menu() {
    while true; do
        ui_clear_screen
        local br="none"
        git rev-parse --is-inside-work-tree >/dev/null 2>&1 && br="$(_current_branch)"
        ui_header "GIT MASTER CONTROL PANEL" "System : ${CYAN}${OS_TYPE}${NC}" "Branch : ${YELLOW}${br}${NC}"

        ui_section "A. INFO & INSPECTIE"
        ui_item "1" "Status & Branch Info"   "Status + last 5 commits"
        ui_item "2" "Pending Changes (Diff)" "Unstaged & staged diff"
        ui_item "3" "Commit History (Tree)"  "Graph log"
        ui_item "4" "Compare with Remote"    "Local vs origin"

        ui_section "B. BRANCHING & DEVELOPMENT"
        ui_item "5"  "Start Feature/AI Branch" "feature/, fix/, ai/, refactor/"
        ui_item "6"  "Switch / Checkout"       "Local & remote branches"
        ui_item "7"  "Quick Commit & Push"     "Preview, add, commit, push"
        ui_item "8"  "Sync / Pull"             "Safe rebase or merge"
        ui_item "9"  "Squash & Clean Branch"   "Squash feature commits"
        ui_item "10" "Prepare UAT / Staging"   "Merge to uat"
        ui_item "11" "Merge Fix & Cleanup"     "Merge fix/* & delete"
        ui_item "12" "Release Tag & Push"      "Annotated tag + push"

        ui_section "C. CLEANUP & MAINTENANCE"
        ui_item "13" "Prune Gone Branches"     "fetch --prune + delete [gone]"
        ui_item "14" "Delete Branch"           "Local & optional origin"
        ui_item "15" "Backup Snapshot Point"   "Create backup/timestamp branch"
        ui_item "16" "Restore Backup Point"    "Checkout backup branch"

        ui_section "D. FIX & EMERGENCY RECOVERY"
        ui_item "17" "Stash / Pull / Pop"      "Safe update with dirty tree"
        ui_item "18" "Undo Last Commit (Soft)" "reset --soft HEAD~1"
        ui_item "19" "Revert Older Commit"     "Safe git revert"
        ui_item "20" "Force Sync"              "reset --hard or --force-with-lease"
        ui_item "21" "Emergency Recovery"      "Abort, index.lock, reflog"
        ui_item "22" "Untrack / Forget File"   "rm --cached + .gitignore"
        ui_item "23" "Config & Token Setup"    "user.name / user.email"
        ui_item "0"  "Back"                    ""

        printf "\n"
        read -rp "Choice: " c
        case "$c" in
            1)  opt_status; ui_pause ;;
            2)  opt_diff; ui_pause ;;
            3)  opt_tree; ui_pause ;;
            4)  opt_compare; ui_pause ;;
            5)  opt_start_branch; ui_pause ;;
            6)  opt_checkout; ui_pause ;;
            7)  opt_quick_commit_push; ui_pause ;;
            8)  opt_sync_pull; ui_pause ;;
            9)  opt_squash; ui_pause ;;
            10) opt_prepare_uat; ui_pause ;;
            11) opt_merge_fix; ui_pause ;;
            12) opt_release_tag; ui_pause ;;
            13) opt_prune; ui_pause ;;
            14) opt_delete_branch; ui_pause ;;
            15) opt_backup; ui_pause ;;
            16) opt_restore_backup; ui_pause ;;
            17) opt_stash_pull_pop; ui_pause ;;
            18) opt_undo_last; ui_pause ;;
            19) opt_revert_commit; ui_pause ;;
            20) opt_force_sync; ui_pause ;;
            21) opt_emergency_recovery; ui_pause ;;
            22) opt_untrack; ui_pause ;;
            23) opt_config; ui_pause ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    status|st)      opt_status ;;
    diff)           opt_diff ;;
    log|tree)       opt_tree ;;
    compare)        opt_compare ;;
    start)          opt_start_branch ;;
    checkout|co)    opt_checkout ;;
    commit|push)    opt_quick_commit_push ;;
    sync|pull)      opt_sync_pull ;;
    squash)         opt_squash ;;
    uat)            opt_prepare_uat ;;
    merge-fix)      opt_merge_fix ;;
    tag)            opt_release_tag ;;
    prune)          opt_prune ;;
    delete-branch)  opt_delete_branch ;;
    backup)         opt_backup ;;
    restore-backup) opt_restore_backup ;;
    stash-pull)     opt_stash_pull_pop ;;
    undo)           opt_undo_last ;;
    revert)         opt_revert_commit ;;
    force-sync)     opt_force_sync ;;
    recover)        opt_emergency_recovery ;;
    untrack)        opt_untrack ;;
    config)         opt_config ;;
    menu)           git_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

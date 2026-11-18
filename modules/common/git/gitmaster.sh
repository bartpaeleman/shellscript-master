#!/usr/bin/env bash
# modules/common/git/gitmaster.sh - Universal Git Workflow Manager (macOS + QNAP/Linux)

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

show_help() {
    ui_header "GIT MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC} | Repo: ${CYAN}$(basename "$(pwd)")${NC}"
    printf "Usage: scripter +gitmaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  status          Show git status, branch, and recent commits\n"
    printf "  branch          List local & remote branches\n"
    printf "  sync            Fetch & pull --rebase from origin\n"
    printf "  commit [msg]    Stage all & commit\n"
    printf "  --help, -h      Show this help\n"
}

git_status_cmd() {
    ui_section "GIT STATUS"
    git status -sb 2>/dev/null || { ui_err "Not a git repository."; return 1; }
    ui_section "RECENT COMMITS"
    git log -n 5 --oneline --decorate 2>/dev/null || true
}

git_branch_cmd() {
    ui_section "BRANCHES"
    git branch -a 2>/dev/null || ui_err "Not a git repository."
}

git_sync_cmd() {
    ui_section "SYNC WITH ORIGIN"
    git fetch --all --prune && git pull --rebase
}

git_commit_cmd() {
    local msg="${1:-}"
    if [[ -z "$msg" ]]; then
        read -rp "Commit message: " msg
    fi
    [[ -z "$msg" ]] && { ui_warn "Aborted: empty message."; return 1; }
    git add -A && git commit -m "$msg"
}

git_menu() {
    while true; do
        local br="none"
        git rev-parse --is-inside-work-tree >/dev/null 2>&1 && br="$(git branch --show-current 2>/dev/null || echo detached)"
        ui_header "GIT MASTER CONTROL PANEL" "System : ${CYAN}${OS_TYPE}${NC}" "Branch : ${YELLOW}${br}${NC}"
        ui_item "1" "Status & Log"    "git status -sb + last 5 commits"
        ui_item "2" "Branches"        "List local & remote branches"
        ui_item "3" "Sync"            "git fetch --all --prune && pull --rebase"
        ui_item "4" "Quick Commit"    "git add -A && git commit"
        ui_item "0" "Back"            ""
        printf "\n"
        read -rp "Choice: " c
        case "$c" in
            1) git_status_cmd ;;
            2) git_branch_cmd ;;
            3) git_sync_cmd ;;
            4) git_commit_cmd ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice." ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    status|st)      git_status_cmd ;;
    branch|br)      git_branch_cmd ;;
    sync|pull)      git_sync_cmd ;;
    commit|cm)      shift; git_commit_cmd "${1:-}" ;;
    menu)           git_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

#!/usr/bin/env bash
# modules/common/db/dbmaster.sh - Universal Database Utilities

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

show_help() {
    ui_header "DB MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +dbmaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  check           Check available DB clients (sqlite3, psql, mysql)\n"
    printf "  --help, -h      Show this help\n"
}

db_check() {
    ui_section "DATABASE CLIENTS"
    local cli
    for cli in sqlite3 psql mysql mongosh redis-cli; do
        if command -v "$cli" >/dev/null 2>&1; then
            ui_ok "$cli ($(command -v "$cli"))"
        else
            ui_warn "$cli not installed"
        fi
    done
}

db_menu() {
    while true; do
        ui_header "DB MASTER" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Check DB Clients" "sqlite3, psql, mysql, mongosh, redis-cli"
        ui_item "0" "Back"             ""
        printf "\n"
        read -rp "Choice: " c
        case "$c" in
            1) db_check ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice." ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    check|status)   db_check ;;
    menu)           db_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

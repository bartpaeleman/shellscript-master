#!/usr/bin/env bash
# modules/common/db/dbmaster.sh - Universal Database Utilities

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

_py_bin() {
    local p="$ROOT_DIR/.dep/.venv/bin/python"
    [[ -x "$p" ]] && echo "$p" || echo "python3"
}

show_help() {
    ui_header "DB MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +dbmaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  backup          1) Compressed .sql.gz dump via mysqldump\n"
    printf "  analyze [db]    2) Analyze table sizes & row counts (db_stats.py)\n"
    printf "  check           3) Check available DB clients\n"
    printf "  --help, -h         Show this help\n"
}

opt_backup() {
    command -v mysqldump >/dev/null 2>&1 || { ui_err "mysqldump not installed."; return 1; }
    read -rp "Host [localhost]: " host; host="${host:-localhost}"
    read -rp "User [root]: " user; user="${user:-root}"
    read -rp "Database name: " db
    [[ -z "$db" ]] && { ui_warn "Database name required."; return 1; }
    local out="${db}_$(date +%Y%m%d_%H%M%S).sql.gz"
    ui_info "Dumping '$db' to $out..."
    mysqldump -h "$host" -u "$user" -p "$db" | gzip > "$out" && ui_ok "Backup saved: $out"
}

opt_analyze() {
    local target="${1:-}"
    if [[ -z "$target" ]]; then
        ui_read_path target "SQLite DB path (or leave blank for MySQL, 0 = annuleren)" || return 0
    fi
    if [[ -n "$target" && -f "$target" ]]; then
        "$(_py_bin)" "$MOD_DIR/db_stats.py" "$target"
    elif command -v mysql >/dev/null 2>&1; then
        read -rp "MySQL Host [localhost]: " host; host="${host:-localhost}"
        read -rp "MySQL User [root]: " user; user="${user:-root}"
        read -rp "Database name: " db
        [[ -z "$db" ]] && return 0
        mysql -h "$host" -u "$user" -p -e "SELECT table_name AS 'Table', table_rows AS 'Rows', ROUND((data_length+index_length)/1024/1024,2) AS 'Size_MB' FROM information_schema.tables WHERE table_schema='${db}' ORDER BY (data_length+index_length) DESC;"
    else
        ui_err "Provide a valid SQLite file or install mysql client."
        return 1
    fi
}

opt_check() {
    ui_section "DATABASE CLIENTS"
    local cli
    for cli in sqlite3 psql mysql mysqldump mongosh redis-cli; do
        if command -v "$cli" >/dev/null 2>&1; then
            ui_ok "$cli ($(command -v "$cli"))"
        else
            ui_warn "$cli not installed"
        fi
    done
}

db_menu() {
    while true; do
        ui_clear_screen
        ui_header "DB MASTER CONTROL PANEL" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Backup Database"  "Compressed .sql.gz via mysqldump"
        ui_item "2" "Analyze Database" "Table sizes & row counts (db_stats.py)"
        ui_item "3" "Check DB Clients" "sqlite3, psql, mysql, mongosh, redis-cli"
        ui_item "0" "Terug"            ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "Backup Database" opt_backup ;;
            2) ui_run_safe "Analyze Database" opt_analyze ;;
            3) ui_run_safe "Check DB Clients" opt_check ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    backup)         opt_backup ;;
    analyze)        shift; opt_analyze "${1:-}" ;;
    check|status)   opt_check ;;
    menu)           db_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

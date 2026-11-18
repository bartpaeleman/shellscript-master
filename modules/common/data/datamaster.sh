#!/usr/bin/env bash
# modules/common/data/datamaster.sh - Universal Data Processing Tools

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

show_help() {
    ui_header "DATA MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +datamaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  json <file>     Pretty-print & validate JSON via jq/python3\n"
    printf "  --help, -h      Show this help\n"
}

data_json() {
    local file="${1:-}"
    [[ -z "$file" || ! -f "$file" ]] && { ui_err "File not found: $file"; return 1; }
    if command -v jq >/dev/null 2>&1; then
        jq . "$file"
    else
        python3 -m json.tool "$file"
    fi
}

data_menu() {
    while true; do
        ui_header "DATA MASTER" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Validate/Format JSON" "Pretty-print a JSON file"
        ui_item "0" "Back"                 ""
        printf "\n"
        read -rp "Choice: " c
        case "$c" in
            1) read -rp "JSON file path: " f; data_json "$f" ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice." ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    json)           shift; data_json "${1:-}" ;;
    menu)           data_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

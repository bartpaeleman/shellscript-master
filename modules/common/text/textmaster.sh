#!/usr/bin/env bash
# modules/common/text/textmaster.sh - Universal Text & Log Utilities

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

show_help() {
    ui_header "TEXT MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +textmaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  stats <file>    Line, word, and character count\n"
    printf "  --help, -h      Show this help\n"
}

text_stats() {
    local file="${1:-}"
    [[ -z "$file" || ! -f "$file" ]] && { ui_err "File not found: $file"; return 1; }
    wc -l -w -c "$file"
}

text_menu() {
    while true; do
        ui_header "TEXT MASTER" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "File Stats (wc)" "Lines, words, bytes"
        ui_item "0" "Back"            ""
        printf "\n"
        read -rp "Choice: " c
        case "$c" in
            1) read -rp "File path: " f; text_stats "$f" ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice." ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    stats)          shift; text_stats "${1:-}" ;;
    menu)           text_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

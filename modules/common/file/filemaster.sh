#!/usr/bin/env bash
# modules/common/file/filemaster.sh - Universal File Management Tools

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

show_help() {
    ui_header "FILE MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +filemaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  large [dir]     Find top 15 largest files in directory\n"
    printf "  --help, -h      Show this help\n"
}

file_large() {
    local dir="${1:-.}"
    [[ ! -d "$dir" ]] && { ui_err "Directory not found: $dir"; return 1; }
    ui_section "LARGEST FILES IN $dir"
    find "$dir" -type f -exec ls -lh {} + 2>/dev/null | sort -k5 -hr | head -n 15
}

file_menu() {
    while true; do
        ui_header "FILE MASTER" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Largest Files" "Top 15 largest files in current dir"
        ui_item "0" "Back"          ""
        printf "\n"
        read -rp "Choice: " c
        case "$c" in
            1) file_large "." ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice." ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    large)          shift; file_large "${1:-.}" ;;
    menu)           file_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

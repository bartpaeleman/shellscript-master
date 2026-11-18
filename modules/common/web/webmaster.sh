#!/usr/bin/env bash
# modules/common/web/webmaster.sh - Universal Web Project Scaffold

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

show_help() {
    ui_header "WEB MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +webmaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  serve [port]    Start quick local Python HTTP server (default: 8000)\n"
    printf "  --help, -h      Show this help\n"
}

web_serve() {
    local port="${1:-8000}"
    ui_info "Starting local HTTP server on http://localhost:${port} (Ctrl+C to stop)..."
    python3 -m http.server "$port"
}

web_menu() {
    while true; do
        ui_header "WEB MASTER" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Local HTTP Server" "Serve current directory via python3"
        ui_item "0" "Back"              ""
        printf "\n"
        read -rp "Choice: " c
        case "$c" in
            1) read -rp "Port [8000]: " p; web_serve "${p:-8000}" ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice." ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    serve)          shift; web_serve "${1:-8000}" ;;
    menu)           web_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

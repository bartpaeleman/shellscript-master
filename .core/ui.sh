#!/usr/bin/env bash
# .core/ui.sh - Central TUI library (Git Master Control Panel style)

# --- ANSI COLOR PALETTE ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

UI_LINE="==============================================================="
UI_SUBLINE="---------------------------------------------------------------"

ui_divider() {
    printf "%b%s%b\n" "${DIM}" "$UI_SUBLINE" "${NC}"
}

ui_header() {
    local title="$1"
    shift || true
    printf "\n%b%s%b\n" "${GREEN}${BOLD}" "$UI_LINE" "${NC}"
    printf "       %b%s%b\n" "${GREEN}${BOLD}" "$title" "${NC}"
    printf "%b%s%b\n" "${GREEN}${BOLD}" "$UI_LINE" "${NC}"
    local line
    for line in "$@"; do
        printf " %b\n" "$line"
    done
    if [[ $# -gt 0 ]]; then
        printf "%b%s%b\n" "${GREEN}${BOLD}" "$UI_LINE" "${NC}"
    fi
}

ui_section() {
    local label="$1"
    printf "\n%b[%s]%b\n" "${YELLOW}${BOLD}" "$label" "${NC}"
}

ui_badge() {
    case "$1" in
        OK)      printf "%b[OK]%b" "${GREEN}" "${NC}" ;;
        MISSING) printf "%b[MISSING]%b" "${RED}" "${NC}" ;;
        MAC)     printf "%b[macOS]%b" "${MAGENTA}" "${NC}" ;;
        QNAP)    printf "%b[QNAP / Linux]%b" "${CYAN}" "${NC}" ;;
        LINUX)   printf "%b[Linux]%b" "${BLUE}" "${NC}" ;;
        CORE)    printf "%b[UNIVERSAL]%b" "${GREEN}" "${NC}" ;;
        *)       printf "[%s]" "$1" ;;
    esac
}

ui_item() {
    local key="$1"
    local label="$2"
    local desc="${3:-}"
    if [[ -n "$desc" ]]; then
        printf "  %b%3s)%b %-18s %b%s%b\n" "${CYAN}${BOLD}" "$key" "${NC}" "$label" "${DIM}" "$desc" "${NC}"
    else
        printf "  %b%3s)%b %s\n" "${CYAN}${BOLD}" "$key" "${NC}" "$label"
    fi
}

ui_ok()   { printf "%b[OK]%b %s\n" "${GREEN}" "${NC}" "$*"; }
ui_warn() { printf "%b[WARN]%b %s\n" "${YELLOW}" "${NC}" "$*"; }
ui_err()  { printf "%b[ERR]%b %s\n" "${RED}" "${NC}" "$*"; }
ui_info() { printf "%b[INFO]%b %s\n" "${CYAN}" "${NC}" "$*"; }

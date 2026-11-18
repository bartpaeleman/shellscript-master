#!/usr/bin/env bash
# modules/common/container/containermaster.sh - Universal Docker / Container Manager

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

_docker_cmd() {
    if command -v docker >/dev/null 2>&1; then
        echo "docker"
    elif command -v system-docker >/dev/null 2>&1; then
        echo "system-docker"
    else
        echo ""
    fi
}

show_help() {
    ui_header "CONTAINER MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +containermaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  ps              List running & stopped containers\n"
    printf "  images          List local images\n"
    printf "  prune           Prune unused containers/images\n"
    printf "  --help, -h      Show this help\n"
}

container_ps() {
    local d; d="$(_docker_cmd)"
    [[ -z "$d" ]] && { ui_err "Docker / Container Station CLI not found."; return 1; }
    "$d" ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
}

container_images() {
    local d; d="$(_docker_cmd)"
    [[ -z "$d" ]] && { ui_err "Docker / Container Station CLI not found."; return 1; }
    "$d" images
}

container_prune() {
    local d; d="$(_docker_cmd)"
    [[ -z "$d" ]] && { ui_err "Docker / Container Station CLI not found."; return 1; }
    "$d" system prune -f
}

container_menu() {
    while true; do
        ui_header "CONTAINER MASTER" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Containers (ps)" "List all containers"
        ui_item "2" "Images"          "List local images"
        ui_item "3" "System Prune"    "Clean unused containers & networks"
        ui_item "0" "Back"            ""
        printf "\n"
        read -rp "Choice: " c
        case "$c" in
            1) container_ps ;;
            2) container_images ;;
            3) container_prune ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice." ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    ps|status)      container_ps ;;
    images)         container_images ;;
    prune)          container_prune ;;
    menu)           container_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

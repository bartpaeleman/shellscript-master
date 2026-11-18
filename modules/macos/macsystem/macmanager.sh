#!/usr/bin/env bash
# modules/macos/macsystem/macmanager.sh - macOS System Control Panel

set -uo pipefail

MACSYSTEM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MACSYSTEM_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"
source "$ROOT_DIR/.core/aliases.sh"

show_help() {
    ui_header "MAC SYSTEM CONTROL PANEL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter -m [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  crontab         1) Crontab Manager\n"
    printf "  zshrc           2) Zshrc Editor\n"
    printf "  cleanup         3) Auto Cleanup\n"
    printf "  cache           4) Clear Cache\n"
    printf "  uninstall       5) Verwijder Applicatie\n"
    printf "  sweep           6) Network Sweep\n"
    printf "  aliases         7) Alias Manager (Target Selector, Presets, Legacy Cleanup)\n"
    printf "  --help, -h         Show this help\n"
}

_run_net_sweep() {
    local sweep="$ROOT_DIR/modules/macos/security/NETWORK/network-master.sh"
    if [[ -x "$sweep" ]]; then
        "$sweep" --sweep
    else
        ui_err "network-master.sh not found at $sweep"
        return 1
    fi
}

mac_menu() {
    while true; do
        ui_clear_screen
        ui_header "MAC SYSTEM CONTROL PANEL" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Crontab Manager"       "Beheer cronjobs"
        ui_item "2" "Zshrc Editor"          "Bewerk ~/.zshrc"
        ui_item "3" "Auto Cleanup"          "Periodieke systeemopschoning"
        ui_item "4" "Clear Cache"           "Caches opschonen"
        ui_item "5" "Verwijder Applicatie"  "Volledige app-verwijdering"
        ui_item "6" "Network Sweep"         "Snelle netwerk-sweep"
        ui_item "7" "Alias Manager"         "Profielen, Presets & Legacy cleanup"
        ui_item "0" "Terug"                 ""
        printf "\n"
        local choice=""
        ui_read_menu_choice choice "Choice"
        case "$choice" in
            1) ui_run_safe "Crontab Manager" "$MACSYSTEM_DIR/crontab_manager.sh" ;;
            2) ui_run_safe "Zshrc Editor" "$MACSYSTEM_DIR/zshrc_editor.sh" ;;
            3) ui_run_safe "Auto Cleanup" "$MACSYSTEM_DIR/auto_cleanup.sh" ;;
            4) ui_run_safe "Clear Cache" "$MACSYSTEM_DIR/clear_cache.sh" ;;
            5) ui_run_safe "Verwijder Applicatie" "$MACSYSTEM_DIR/uninstall.sh" ;;
            6) ui_run_safe "Network Sweep" _run_net_sweep ;;
            7) alias_manager_menu ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    crontab)        "$MACSYSTEM_DIR/crontab_manager.sh" ;;
    zshrc)          "$MACSYSTEM_DIR/zshrc_editor.sh" ;;
    cleanup)        "$MACSYSTEM_DIR/auto_cleanup.sh" ;;
    cache)          "$MACSYSTEM_DIR/clear_cache.sh" ;;
    uninstall)      "$MACSYSTEM_DIR/uninstall.sh" ;;
    sweep)          _run_net_sweep ;;
    aliases|alias)  alias_manager_menu ;;
    menu)           mac_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

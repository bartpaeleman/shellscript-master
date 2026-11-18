#!/usr/bin/env bash
# modules/qnap/qnapmaster.sh - QNAP-specific hooks & maintenance

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=.core/os_detect.sh
[[ -z "${OS_TYPE:-}" ]] && source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

qnap_container_status() {
    echo "=== QNAP Container Station Status ==="
    if command -v docker >/dev/null 2>&1; then
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    elif command -v system-docker >/dev/null 2>&1; then
        system-docker ps -a
    else
        echo "Docker / Container Station CLI not found."
    fi
}

qnap_share_cleanup() {
    echo "=== QNAP Share Cleanup (@Recycle / .@__thumb) ==="
    local share_root="/share"
    if [[ ! -d "$share_root" ]]; then
        echo "No /share directory found (not running on QNAP?)."
        return 1
    fi
    echo "Scanning $share_root for @Recycle and .@__thumb directories..."
    find "$share_root" -maxdepth 3 \( -name "@Recycle" -o -name ".@__thumb" \) -exec du -sh {} + 2>/dev/null || true
    read -rp "Purge @Recycle contents? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        find "$share_root" -maxdepth 3 -name "@Recycle" -exec rm -rf {}/* + 2>/dev/null || true
        echo "Cleanup complete."
    else
        echo "Skipped."
    fi
}

qnap_entware_update() {
    echo "=== QNAP Entware (opkg) Update ==="
    if command -v opkg >/dev/null 2>&1; then
        opkg update && opkg upgrade
    else
        echo "opkg (Entware) not installed."
        return 1
    fi
}

_qnap_editor() {
    if command -v nano >/dev/null 2>&1; then echo "nano"
    elif command -v vim >/dev/null 2>&1; then echo "vim"
    else echo "vi"
    fi
}

_qnap_backup_file() {
    local f="$1"
    local ts; ts="$(date +%Y%m%d-%H%M%S)"
    local bak="${f}.bak.${ts}"
    if [[ -w "$(dirname "$f")" && -w "$f" ]]; then
        cp -p "$f" "$bak" && ui_ok "Backup: $bak"
    elif command -v sudo >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        sudo cp -p "$f" "$bak" && ui_ok "Backup (sudo): $bak"
    else
        ui_err "Cannot create backup for $f (permission denied)."
        return 1
    fi
}

_qnap_file_actions() {
    local target="$1"
    while true; do
        ui_clear_screen
        ui_header "QNAP FILE ACTIONS" "Target: ${CYAN}${target}${NC}"
        ui_item "1" "Openen & bewerken in editor" "Met automatische .bak backup"
        ui_item "2" "Toon huidige scripter-regels" "Preview met regelnummers"
        ui_item "3" "Verwijder scripter-blok"      "Veilige opschoning + backup"
        ui_item "0" "Terug"                        ""
        printf "\n"
        read -rp "Choice: " act
        case "$act" in
            1)
                _qnap_backup_file "$target" || { ui_pause; continue; }
                local ed; ed="$(_qnap_editor)"
                if [[ -w "$target" ]]; then
                    "$ed" "$target"
                elif command -v sudo >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
                    sudo "$ed" "$target"
                else
                    ui_err "No write permission for $target."
                fi
                ui_pause
                ;;
            2)
                ui_section "SCRIPTER REGELS IN $target"
                grep -n -E "scripter|SCRIPTER_HOME" "$target" 2>/dev/null || ui_info "Geen scripter-regels gevonden."
                ui_pause
                ;;
            3)
                if ui_confirm_action "Verwijder scripter-hub blok uit $target?"; then
                    _qnap_backup_file "$target" || { ui_pause; continue; }
                    local tmp; tmp="$(mktemp)"
                    awk '
                        /# >>> scripter-hub >>>/ { skip=1; next }
                        /# <<< scripter-hub <<</ { skip=0; next }
                        !skip { print }
                    ' "$target" > "$tmp"
                    if [[ -w "$target" ]]; then
                        mv "$tmp" "$target"
                    elif command -v sudo >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
                        sudo mv "$tmp" "$target"
                    else
                        rm -f "$tmp"
                        ui_err "Permission denied."
                    fi
                    ui_ok "Scripter-blok verwijderd uit $target."
                fi
                ui_pause
                ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

qnap_persistence_scan() {
    ui_clear_screen
    ui_header "QNAP PERSISTENCE & PROFILE SCANNER" "System : ${CYAN}${OS_TYPE}${NC}"
    local candidates=()
    local f
    # Persistent locations
    for f in /share/homes/*/.profile /share/homes/*/.bashrc /opt/etc/profile /opt/bin/scripter /etc/config/autorun.sh; do
        [[ -e "$f" || -L "$f" ]] && candidates+=("PERSISTENT|$f")
    done
    # Session / Volatile locations
    for f in /root/.profile /root/.bashrc /etc/profile /etc/bashrc /usr/local/bin/scripter /usr/bin/scripter; do
        [[ -e "$f" || -L "$f" ]] && candidates+=("SESSION|$f")
    done

    if [[ ${#candidates[@]} -eq 0 ]]; then
        ui_warn "Geen bekende QNAP profiel- of symlink-locaties gevonden op dit systeem."
        return 0
    fi

    local idx=1
    local files=()
    local entry ptype ppath found_tag perm_tag
    for entry in "${candidates[@]}"; do
        IFS='|' read -r ptype ppath <<< "$entry"
        if [[ -L "$ppath" ]] || grep -q -E "scripter|SCRIPTER_HOME" "$ppath" 2>/dev/null; then
            found_tag="${GREEN}[GEVONDEN]${NC}"
        else
            found_tag="${DIM}[LEEG]${NC}"
        fi
        if [[ -w "$ppath" ]]; then
            perm_tag="${GREEN}[WRITABLE]${NC}"
        else
            perm_tag="${YELLOW}[SUDO REQUIRED]${NC}"
        fi
        printf "  %b%2d)%b [%-10s] %b %b %s\n" "${CYAN}${BOLD}" "$idx" "${NC}" "$ptype" "$found_tag" "$perm_tag" "$ppath"
        files+=("$ppath")
        ((idx++))
    done
    printf "  %b 0)%b Terug\n\n" "${CYAN}${BOLD}" "${NC}"

    local sel=""
    ui_prompt_input sel "Selecteer bestand [1-${#files[@]}]" || return 0
    if [[ "$sel" =~ ^[0-9]+$ ]] && [[ "$sel" -ge 1 && "$sel" -le ${#files[@]} ]]; then
        _qnap_file_actions "${files[$((sel-1))]}"
    else
        ui_cancel_msg
    fi
}

qnap_menu() {
    while true; do
        ui_clear_screen
        ui_header "QNAP MASTER" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Container Station status"     "docker / system-docker ps"
        ui_item "2" "Share cleanup"                "@Recycle / .@__thumb"
        ui_item "3" "Entware update"               "opkg update && opkg upgrade"
        ui_item "4" "Persistence Scanner / Editor" "Scan & edit QNAP profiles/autorun"
        ui_item "0" "Terug"                        ""
        printf "\n"
        read -rp "Choice: " choice
        case "$choice" in
            1) ui_run_safe "Container Station status" qnap_container_status ;;
            2) ui_run_safe "QNAP Share cleanup" qnap_share_cleanup ;;
            3) ui_run_safe "Entware update" qnap_entware_update ;;
            4) ui_run_safe "Persistence Scanner" qnap_persistence_scan ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-menu}" in
        containers|status) qnap_container_status ;;
        cleanup)           qnap_share_cleanup ;;
        entware|update)    qnap_entware_update ;;
        scan|persistence)  qnap_persistence_scan ;;
        menu)              qnap_menu ;;
        --help|-h)
            echo "Usage: scripter -q {containers|cleanup|entware|persistence|menu}"
            ;;
        *)
            echo "Unknown subcommand: $1"
            exit 1
            ;;
    esac
fi

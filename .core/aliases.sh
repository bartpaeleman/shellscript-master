#!/usr/bin/env bash
# .core/aliases.sh - Cross-Platform Alias Manager (macOS + QNAP + Linux)

CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$CORE_DIR/.." && pwd)"
declare -F os_is_macos >/dev/null 2>&1 || source "$CORE_DIR/os_detect.sh"
[[ -z "${UI_LINE:-}" ]] && source "$CORE_DIR/ui.sh"

_alias_profile() {
    case "$OS_TYPE" in
        macOS)
            echo "${HOME}/.zshrc"
            ;;
        QNAP)
            if [[ -d "/share/Public" ]]; then
                echo "/share/Public/.bash_aliases"
            else
                local u; u="$(whoami 2>/dev/null || echo admin)"
                if [[ -d "/share/homes/${u}" ]]; then
                    echo "/share/homes/${u}/.profile"
                else
                    echo "${HOME}/.profile"
                fi
            fi
            ;;
        *)
            echo "${HOME}/.bashrc"
            ;;
    esac
}

_alias_backup() {
    local f="$1"
    [[ ! -f "$f" ]] && return 0
    local bak="${f}.bak.$(date +%Y%m%d-%H%M%S)"
    if [[ -w "$(dirname "$f")" && -w "$f" ]]; then
        cp -p "$f" "$bak" 2>/dev/null && ui_ok "Backup: $bak"
    elif command -v sudo >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        sudo cp -p "$f" "$bak" 2>/dev/null && ui_ok "Backup (sudo): $bak"
    fi
}

_alias_read_list() {
    local prof="$1"
    ALIAS_NAMES=()
    ALIAS_CMDS=()
    [[ ! -f "$prof" ]] && return 0
    local line name cmd
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == alias\ * ]]; then
            name="${line#alias }"
            name="${name%%=*}"
            cmd="${line#*=}"
            cmd="${cmd#\'}"; cmd="${cmd%\'}"
            cmd="${cmd#\"}"; cmd="${cmd%\"}"
            ALIAS_NAMES+=("$name")
            ALIAS_CMDS+=("$cmd")
        fi
    done < "$prof"
}

_alias_write_list() {
    local prof="$1"
    _alias_backup "$prof"

    local tmp; tmp="$(mktemp)"
    if [[ -f "$prof" ]]; then
        awk '
            /# >>> scripter-aliases >>>/ { skip=1; next }
            /# <<< scripter-aliases <<</ { skip=0; next }
            !skip && $0 !~ /^alias / { print }
        ' "$prof" > "$tmp"
    fi

    {
        printf "\n# >>> scripter-aliases >>>\n"
        local i
        for ((i=0; i<${#ALIAS_NAMES[@]}; i++)); do
            printf "alias %s='%s'\n" "${ALIAS_NAMES[$i]}" "${ALIAS_CMDS[$i]}"
        done
        printf "# <<< scripter-aliases <<<\n"
    } >> "$tmp"

    if [[ -w "$prof" ]] || [[ ! -e "$prof" && -w "$(dirname "$prof")" ]]; then
        mv "$tmp" "$prof"
    elif command -v sudo >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        sudo mv "$tmp" "$prof"
    else
        rm -f "$tmp"
        ui_err "Cannot write to $prof (permission denied)."
        return 1
    fi
    ui_ok "Updated $prof (run 'source $prof' to activate)"

    if os_is_qnap && [[ "$prof" == /root/* || "$prof" == /etc/* ]]; then
        ui_warn "[VOLATILE RAM] Wijzigingen in $prof zijn actief voor deze sessie, maar kunnen bij een QNAP-reboot worden gereset."
    fi
}

_alias_upsert() {
    local prof="$1" name="$2" cmd="$3"
    _alias_read_list "$prof"
    local i found=0
    for ((i=0; i<${#ALIAS_NAMES[@]}; i++)); do
        if [[ "${ALIAS_NAMES[$i]}" == "$name" ]]; then
            ALIAS_CMDS[$i]="$cmd"
            found=1
            break
        fi
    done
    if [[ "$found" -eq 0 ]]; then
        ALIAS_NAMES+=("$name")
        ALIAS_CMDS+=("$cmd")
    fi
    _alias_write_list "$prof"
}

alias_presets_wizard() {
    local prof="${ACTIVE_ALIAS_PROFILE:-$(_alias_profile)}"
    ui_section "ALIAS PRESETS WIZARD ($OS_TYPE)"
    echo "  1) Webserver Presets (prd, dev, tst)"
    echo "  2) Python Venv Preset (pyvenv -> .dep/.venv)"
    echo "  3) Directe Module-Aliassen (gitmaster, dockermaster, dbmaster, ...)"
    if os_is_macos; then
        echo "  4) macOS Shortcuts (flushdns, showfiles, hidefiles, brewup)"
    fi
    echo "  0) Terug"
    local c=""
    ui_read_menu_choice c "Select preset"
    case "$c" in
        1)
            local def_prd def_dev def_tst
            if os_is_qnap; then
                def_prd="/share/Web/"
                def_dev="/share/Web/DEV/"
                def_tst="/share/Web/TEST/"
            else
                def_prd="${HOME}/Sites"
                def_dev="${HOME}/Sites/dev"
                def_tst="${HOME}/Sites/tst"
            fi
            local p_prd="" p_dev="" p_tst=""
            read -e -p "PRD path [$def_prd] (Enter=default, 0=cancel): " p_prd
            [[ "$p_prd" == "0" ]] && { ui_cancel_msg; return 0; }
            p_prd="${p_prd:-$def_prd}"
            read -e -p "DEV path [$def_dev] (Enter=default, 0=cancel): " p_dev
            [[ "$p_dev" == "0" ]] && { ui_cancel_msg; return 0; }
            p_dev="${p_dev:-$def_dev}"
            read -e -p "TST path [$def_tst] (Enter=default, 0=cancel): " p_tst
            [[ "$p_tst" == "0" ]] && { ui_cancel_msg; return 0; }
            p_tst="${p_tst:-$def_tst}"
            _alias_upsert "$prof" "prd" "cd \"${p_prd}\" && ls -la"
            _alias_upsert "$prof" "dev" "cd \"${p_dev}\" && ls -la"
            _alias_upsert "$prof" "tst" "cd \"${p_tst}\" && ls -la"
            ;;
        2)
            if os_is_qnap; then
                local def_py; def_py="$(command -v python3 2>/dev/null || echo "/share/CACHEDEV1_DATA/.samba_python3/Python3/bin/python3")"
                local py_path=""
                read -e -p "QNAP python3 path [$def_py] (Enter=default, 0=cancel): " py_path
                [[ "$py_path" == "0" ]] && { ui_cancel_msg; return 0; }
                py_path="${py_path:-$def_py}"
                local py_dir; py_dir="$(dirname "$py_path")"
                _alias_upsert "$prof" "python3" "$py_path"
                _alias_upsert "$prof" "pyvenv" "source \"${ROOT_DIR}/.dep/.venv/bin/activate\""
                if ! grep -q "export PATH=\"${py_dir}:\$PATH\"" "$prof" 2>/dev/null; then
                    printf "\nexport PATH=\"%s:\$PATH\"\n" "$py_dir" >> "$prof"
                    ui_ok "Added export PATH=\"${py_dir}:\$PATH\" to $prof"
                fi
            else
                _alias_upsert "$prof" "pyvenv" "source \"${ROOT_DIR}/.dep/.venv/bin/activate\""
            fi
            ;;
        3)
            _alias_upsert "$prof" "scripter" "${ROOT_DIR}/scripter"
            _alias_upsert "$prof" "scripts" "cd \"${ROOT_DIR}\""
            _alias_upsert "$prof" "gitmaster" "${ROOT_DIR}/scripter +gitmaster"
            _alias_upsert "$prof" "dockermaster" "${ROOT_DIR}/scripter +containermaster"
            _alias_upsert "$prof" "containermaster" "${ROOT_DIR}/scripter +containermaster"
            _alias_upsert "$prof" "dbmaster" "${ROOT_DIR}/scripter +dbmaster"
            _alias_upsert "$prof" "webmaster" "${ROOT_DIR}/scripter +webmaster"
            _alias_upsert "$prof" "datamaster" "${ROOT_DIR}/scripter +datamaster"
            _alias_upsert "$prof" "filemaster" "${ROOT_DIR}/scripter +filemaster"
            _alias_upsert "$prof" "textmaster" "${ROOT_DIR}/scripter +textmaster"
            if os_is_qnap; then
                _alias_upsert "$prof" "qnapmaster" "${ROOT_DIR}/scripter +qnapmaster"
                _alias_upsert "$prof" "sysmaster" "${ROOT_DIR}/scripter +qnapmaster"
            elif os_is_macos; then
                _alias_upsert "$prof" "macmaster" "${ROOT_DIR}/scripter +macmaster"
                _alias_upsert "$prof" "networkmaster" "${ROOT_DIR}/scripter +networkmaster"
                _alias_upsert "$prof" "cybermaster" "${ROOT_DIR}/scripter +cybermaster"
                _alias_upsert "$prof" "intelmaster" "${ROOT_DIR}/scripter +intelmaster"
                _alias_upsert "$prof" "audiomaster" "${ROOT_DIR}/scripter +audiomaster"
                _alias_upsert "$prof" "videomaster" "${ROOT_DIR}/scripter +videomaster"
                _alias_upsert "$prof" "imagemaster" "${ROOT_DIR}/scripter +imagemaster"
                _alias_upsert "$prof" "karaokemaster" "${ROOT_DIR}/scripter +karaokemaster"
            fi
            ;;
        4)
            if os_is_macos; then
                _alias_upsert "$prof" "flushdns" "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
                _alias_upsert "$prof" "showfiles" "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
                _alias_upsert "$prof" "hidefiles" "defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"
                _alias_upsert "$prof" "brewup" "brew update && brew upgrade && brew cleanup"
            fi
            ;;
        0|q|Q) ui_cancel_msg ;;
        *) ui_cancel_msg ;;
    esac
}

alias_add_custom() {
    local prof="${ACTIVE_ALIAS_PROFILE:-$(_alias_profile)}"
    local name="" cmd=""
    ui_prompt_input name "Alias name" || return 0
    [[ -z "$name" ]] && { ui_cancel_msg; return 0; }
    read -e -p "Target path or command (Tab for path autocomplete, 0=cancel): " cmd
    [[ "$cmd" == "0" || -z "$cmd" ]] && { ui_cancel_msg; return 0; }
    if [[ -d "$cmd" ]]; then
        if ui_confirm_action "'$cmd' is a directory. Navigate with 'cd \"$cmd\" && ls -la'?"; then
            cmd="cd \"${cmd}\" && ls -la"
        fi
    fi
    if [[ "$name" == "python3" ]]; then
        local py_dir; py_dir="$(dirname "$cmd")"
        ui_info "Let op: een alias voor 'python3' werkt niet in subshells/scripts."
        if ui_confirm_action "Ook 'export PATH=\"${py_dir}:\$PATH\"' toevoegen aan $prof?"; then
            printf "\nexport PATH=\"%s:\$PATH\"\n" "$py_dir" >> "$prof"
            ui_ok "Added export PATH=\"${py_dir}:\$PATH\" to $prof"
        fi
    fi
    _alias_upsert "$prof" "$name" "$cmd"
}

alias_edit_or_delete() {
    local prof="${ACTIVE_ALIAS_PROFILE:-$(_alias_profile)}"
    _alias_read_list "$prof"
    if [[ ${#ALIAS_NAMES[@]} -eq 0 ]]; then
        ui_info "Geen beheerde aliassen gevonden in $prof."
        return 0
    fi
    local i
    for ((i=0; i<${#ALIAS_NAMES[@]}; i++)); do
        printf "  %b%2d)%b %-14s -> %s\n" "${CYAN}${BOLD}" "$((i+1))" "${NC}" "${ALIAS_NAMES[$i]}" "${ALIAS_CMDS[$i]}"
    done
    printf "  %b 0)%b Terug\n\n" "${CYAN}${BOLD}" "${NC}"

    local sel=""
    ui_prompt_input sel "Selecteer alias nummer [1-${#ALIAS_NAMES[@]}]" || return 0
    if [[ ! "$sel" =~ ^[0-9]+$ ]] || [[ "$sel" -lt 1 || "$sel" -gt ${#ALIAS_NAMES[@]} ]]; then
        ui_cancel_msg; return 0
    fi
    local idx=$((sel-1))
    echo "Geselecteerd: ${ALIAS_NAMES[$idx]} -> ${ALIAS_CMDS[$idx]}"
    echo "  1) Wijzigen"
    echo "  2) Verwijderen"
    echo "  0) Terug"
    local act=""
    ui_prompt_input act "Actie [1/2]" || return 0
    case "$act" in
        1)
            local new_cmd=""
            read -e -p "Nieuw pad/commando (Tab autocomplete, 0=cancel): " new_cmd
            [[ "$new_cmd" == "0" || -z "$new_cmd" ]] && { ui_cancel_msg; return 0; }
            ALIAS_CMDS[$idx]="$new_cmd"
            _alias_write_list "$prof"
            ;;
        2)
            if ui_confirm_action "Verwijder alias '${ALIAS_NAMES[$idx]}'?"; then
                local new_n=() new_c=()
                for ((i=0; i<${#ALIAS_NAMES[@]}; i++)); do
                    [[ "$i" -ne "$idx" ]] && { new_n+=("${ALIAS_NAMES[$i]}"); new_c+=("${ALIAS_CMDS[$i]}"); }
                done
                ALIAS_NAMES=("${new_n[@]}")
                ALIAS_CMDS=("${new_c[@]}")
                _alias_write_list "$prof"
            fi
            ;;
        *) ui_cancel_msg ;;
    esac
}

alias_scan_all_qnap() {
    ui_section "OVERZICHT ALLE QNAP PROFIELEN"
    local u; u="$(whoami 2>/dev/null || echo admin)"
    local p
    for p in "/share/Public/.bash_aliases" "/share/homes/${u}/.profile" "/root/.profile" "/root/.bashrc" "/etc/profile" "/opt/etc/profile"; do
        if [[ -f "$p" ]]; then
            local cnt; cnt="$(grep -c '^alias ' "$p" 2>/dev/null || echo 0)"
            printf "  %b[OK]%b %-32s (%s aliassen)\n" "${GREEN}" "${NC}" "$p" "$cnt"
            grep '^alias ' "$p" 2>/dev/null | sed 's/^/      /'
        else
            printf "  %b[NIET GEVONDEN]%b %s\n" "${DIM}" "${NC}" "$p"
        fi
    done
}

alias_select_profile() {
    local u; u="$(whoami 2>/dev/null || echo admin)"
    local p_pub="/share/Public/.bash_aliases"
    local p_home="/share/homes/${u}/.profile"
    local p_opt="/opt/etc/profile"
    local opt_tag="${GREEN}[PERSISTENT — Entware]${NC}"
    [[ ! -f "$p_opt" ]] && opt_tag="${DIM}[NIET GEVONDEN]${NC}"

    ui_clear_screen
    ui_header "DOELBESTAND SELECTIE (QNAP)" "Actief: ${CYAN}${ACTIVE_ALIAS_PROFILE}${NC}"
    printf "  %b 1)%b %-30s %b[PERSISTENT — Centraal Alias Bestand]%b\n" "${CYAN}${BOLD}" "${NC}" "$p_pub" "${GREEN}" "${NC}"
    printf "  %b 2)%b %-30s %b[PERSISTENT]%b\n" "${CYAN}${BOLD}" "${NC}" "$p_home" "${GREEN}" "${NC}"
    printf "  %b 3)%b %-30s %b[SESSION / VOLATILE RAM]%b\n" "${CYAN}${BOLD}" "${NC}" "/root/.profile" "${YELLOW}" "${NC}"
    printf "  %b 4)%b %-30s %b[SESSION / VOLATILE RAM]%b\n" "${CYAN}${BOLD}" "${NC}" "/root/.bashrc" "${YELLOW}" "${NC}"
    printf "  %b 5)%b %-30s %b[SYSTEM / VOLATILE RAM]%b\n" "${CYAN}${BOLD}" "${NC}" "/etc/profile" "${YELLOW}" "${NC}"
    printf "  %b 6)%b %-30s %b\n" "${CYAN}${BOLD}" "${NC}" "$p_opt" "$opt_tag"
    printf "  %b 7)%b Scan alle bovenstaande bestanden tegelijk\n" "${CYAN}${BOLD}" "${NC}"
    printf "  %b 0)%b Terug\n\n" "${CYAN}${BOLD}" "${NC}"

    local s=""
    ui_read_menu_choice s "Choice"
    case "$s" in
        1) ACTIVE_ALIAS_PROFILE="$p_pub" ;;
        2) ACTIVE_ALIAS_PROFILE="$p_home" ;;
        3) ACTIVE_ALIAS_PROFILE="/root/.profile" ;;
        4) ACTIVE_ALIAS_PROFILE="/root/.bashrc" ;;
        5) ACTIVE_ALIAS_PROFILE="/etc/profile" ;;
        6) ACTIVE_ALIAS_PROFILE="$p_opt" ;;
        7) alias_scan_all_qnap; ui_pause ;;
        0|q|Q) return 0 ;;
        *) ui_warn "Invalid choice."; ui_pause ;;
    esac
}

alias_manager_menu() {
    ACTIVE_ALIAS_PROFILE="${ACTIVE_ALIAS_PROFILE:-$(_alias_profile)}"
    while true; do
        local prof="$ACTIVE_ALIAS_PROFILE"
        ui_clear_screen
        ui_header "ALIAS MANAGER ($OS_TYPE)" "Profile: ${CYAN}${prof}${NC}"
        _alias_read_list "$prof"
        if [[ ${#ALIAS_NAMES[@]} -gt 0 ]]; then
            ui_section "ACTIEVE ALIASSEN"
            local i
            for ((i=0; i<${#ALIAS_NAMES[@]}; i++)); do
                printf "  %b%2d)%b %-14s -> %s\n" "${DIM}" "$((i+1))" "${NC}" "${ALIAS_NAMES[$i]}" "${ALIAS_CMDS[$i]}"
            done
        fi
        ui_section "ACTIES"
        ui_item "1" "Nieuwe Alias Toevoegen"  "Met Tab pad-autocomplete"
        ui_item "2" "Presets Wizard"          "Webserver PRD/DEV/TST & pyvenv"
        ui_item "3" "Wijzigen / Verwijderen"  "Op nummer (met .bak backup)"
        if os_is_qnap; then
            ui_item "4" "Doelbestand Kiezen"  "Wissel profiel / scan alle QNAP files"
        fi
        ui_item "0" "Terug"                   ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "Nieuwe Alias" alias_add_custom ;;
            2) ui_run_safe "Presets Wizard" alias_presets_wizard ;;
            3) ui_run_safe "Alias Wijzigen/Verwijderen" alias_edit_or_delete ;;
            4) os_is_qnap && alias_select_profile ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

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
            local u; u="$(whoami 2>/dev/null || echo admin)"
            if [[ -d "/share/homes/${u}" ]]; then
                echo "/share/homes/${u}/.profile"
            else
                echo "${HOME}/.profile"
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
    cp -p "$f" "$bak" 2>/dev/null && ui_ok "Backup: $bak"
}

_alias_read_list() {
    local prof="$1"
    ALIAS_NAMES=()
    ALIAS_CMDS=()
    [[ ! -f "$prof" ]] && return 0
    local in_block=0 line name cmd
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" == "# >>> scripter-aliases >>>" ]] && { in_block=1; continue; }
        [[ "$line" == "# <<< scripter-aliases <<<" ]] && { in_block=0; continue; }
        if [[ "$in_block" -eq 1 && "$line" == alias\ * ]]; then
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
    touch "$prof" 2>/dev/null || { ui_err "Cannot write to $prof"; return 1; }
    _alias_backup "$prof"

    local tmp; tmp="$(mktemp)"
    if grep -q "# >>> scripter-aliases >>>" "$prof" 2>/dev/null; then
        awk '
            /# >>> scripter-aliases >>>/ { skip=1; next }
            /# <<< scripter-aliases <<</ { skip=0; next }
            !skip { print }
        ' "$prof" > "$tmp"
    else
        cat "$prof" > "$tmp"
    fi

    {
        printf "\n# >>> scripter-aliases >>>\n"
        local i
        for ((i=0; i<${#ALIAS_NAMES[@]}; i++)); do
            printf "alias %s='%s'\n" "${ALIAS_NAMES[$i]}" "${ALIAS_CMDS[$i]}"
        done
        printf "# <<< scripter-aliases <<<\n"
    } >> "$tmp"

    mv "$tmp" "$prof"
    ui_ok "Updated $prof (run 'source $prof' to activate)"
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
    local prof; prof="$(_alias_profile)"
    ui_section "ALIAS PRESETS WIZARD ($OS_TYPE)"
    echo "  1) Webserver Presets (prd, dev, tst)"
    echo "  2) Python Venv Preset (pyvenv -> .dep/.venv)"
    if os_is_macos; then
        echo "  3) macOS Shortcuts (flushdns, showfiles, hidefiles, brewup)"
    fi
    echo "  0) Terug"
    local c=""
    ui_prompt_input c "Select preset" || return 0
    case "$c" in
        1)
            local def_prd def_dev def_tst
            if os_is_qnap; then
                def_prd="/share/Web"
                def_dev="/share/Web/dev"
                def_tst="/share/Web/tst"
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
            _alias_upsert "$prof" "pyvenv" "source \"${ROOT_DIR}/.dep/.venv/bin/activate\""
            ;;
        3)
            if os_is_macos; then
                _alias_upsert "$prof" "flushdns" "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
                _alias_upsert "$prof" "showfiles" "defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
                _alias_upsert "$prof" "hidefiles" "defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"
                _alias_upsert "$prof" "brewup" "brew update && brew upgrade && brew cleanup"
            fi
            ;;
        *) ui_cancel_msg ;;
    esac
}

alias_add_custom() {
    local prof; prof="$(_alias_profile)"
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
    _alias_upsert "$prof" "$name" "$cmd"
}

alias_edit_or_delete() {
    local prof; prof="$(_alias_profile)"
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

alias_manager_menu() {
    local prof; prof="$(_alias_profile)"
    while true; do
        ui_clear_screen
        ui_header "ALIAS MANAGER ($OS_TYPE)" "Profile: ${CYAN}${prof}${NC}"
        _alias_read_list "$prof"
        if [[ ${#ALIAS_NAMES[@]} -gt 0 ]]; then
            ui_section "ACTIEVE SCRIPTER-ALIASSEN"
            local i
            for ((i=0; i<${#ALIAS_NAMES[@]}; i++)); do
                printf "  %b%2d)%b %-14s -> %s\n" "${DIM}" "$((i+1))" "${NC}" "${ALIAS_NAMES[$i]}" "${ALIAS_CMDS[$i]}"
            done
        fi
        ui_section "ACTIES"
        ui_item "1" "Nieuwe Alias Toevoegen"  "Met Tab pad-autocomplete"
        ui_item "2" "Presets Wizard"          "Webserver PRD/DEV/TST & pyvenv"
        ui_item "3" "Wijzigen / Verwijderen"  "Op nummer (met .bak backup)"
        ui_item "0" "Terug"                   ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "Nieuwe Alias" alias_add_custom ;;
            2) ui_run_safe "Presets Wizard" alias_presets_wizard ;;
            3) ui_run_safe "Alias Wijzigen/Verwijderen" alias_edit_or_delete ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

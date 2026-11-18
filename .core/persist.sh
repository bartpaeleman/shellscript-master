#!/usr/bin/env bash
# .core/persist.sh - OS-specific shell persistence for scripter

CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$CORE_DIR/.." && pwd)"
[[ -z "${OS_TYPE:-}" ]] && source "$CORE_DIR/os_detect.sh"
[[ -z "${UI_LINE:-}" ]] && source "$CORE_DIR/ui.sh"

_persist_block() {
    cat <<EOF
# >>> scripter-hub >>>
export SCRIPTER_HOME="$ROOT_DIR"
alias scripter='"$ROOT_DIR/scripter"'
# <<< scripter-hub <<<
EOF
}

_upsert_rc_block() {
    local rc_file="$1"
    [[ -z "$rc_file" ]] && return 1
    if ! touch "$rc_file" 2>/dev/null; then
        ui_err "Cannot write to $rc_file (permission denied)."
        return 1
    fi

    local action="Added"
    if grep -q "# >>> scripter-hub >>>" "$rc_file" 2>/dev/null; then
        action="Updated"
        local tmp_file
        tmp_file="$(mktemp)"
        awk '
            /# >>> scripter-hub >>>/ { skip=1; next }
            /# <<< scripter-hub <<</ { skip=0; next }
            !skip { print }
        ' "$rc_file" > "$tmp_file" && mv "$tmp_file" "$rc_file"
    fi

    printf "\n" >> "$rc_file"
    _persist_block >> "$rc_file"
    ui_ok "$action scripter-hub block in $rc_file:"
    _persist_block | sed 's/^/    /'
}

persist_system() {
    ui_header "SCRIPTER PERSISTENCE SETUP" "System : ${CYAN}${OS_TYPE}${NC} (${ARCH})" "Target : ${CYAN}${ROOT_DIR}/scripter${NC}"

    case "$OS_TYPE" in
        macOS)
            _upsert_rc_block "${HOME}/.zshrc"
            if [[ -f "${HOME}/.bash_profile" ]]; then
                _upsert_rc_block "${HOME}/.bash_profile"
            fi
            ui_info "Run 'source ~/.zshrc' or open a new terminal to use 'scripter' anywhere."
            ;;
        QNAP)
            local applied=0
            if [[ -d "/opt/etc" ]] && [[ -w "/opt/etc/profile" || -w "/opt/etc" ]]; then
                _upsert_rc_block "/opt/etc/profile" && applied=1
            fi
            if [[ -d "/opt/bin" ]] && [[ -w "/opt/bin" ]]; then
                ln -sf "$ROOT_DIR/scripter" "/opt/bin/scripter"
                ui_ok "Symlinked /opt/bin/scripter -> $ROOT_DIR/scripter"
                applied=1
            fi
            _upsert_rc_block "${HOME}/.profile" && applied=1
            local q_prof
            for q_prof in "/share/homes/$(whoami 2>/dev/null || echo admin)/.profile" "/root/.profile"; do
                if [[ -f "$q_prof" && -w "$q_prof" ]] && ! grep -q "# >>> scripter-hook >>>" "$q_prof" 2>/dev/null; then
                    printf "\n# >>> scripter-hook >>>\n[ -f /share/Public/.bash_aliases ] && . /share/Public/.bash_aliases\n# <<< scripter-hook <<<\n" >> "$q_prof"
                    ui_ok "Added scripter-hook to $q_prof"
                fi
            done
            if [[ "$applied" -eq 0 ]]; then
                ui_warn "Could not write to Entware (/opt/etc/profile). Check permissions."
            else
                ui_info "QNAP persistence configured. 'scripter' will survive SSH sessions & Entware profile loads."
            fi
            ;;
        Linux)
            _upsert_rc_block "${HOME}/.bashrc"
            [[ -f "${HOME}/.profile" ]] && _upsert_rc_block "${HOME}/.profile"
            if [[ -w "/usr/local/bin" ]]; then
                ln -sf "$ROOT_DIR/scripter" "/usr/local/bin/scripter"
                ui_ok "Symlinked /usr/local/bin/scripter -> $ROOT_DIR/scripter"
            else
                ui_info "Tip: Run 'sudo ln -sf \"$ROOT_DIR/scripter\" /usr/local/bin/scripter' for global access."
            fi
            ;;
        *)
            ui_warn "Unknown OS ($OS_TYPE). Add '$ROOT_DIR' to your PATH manually."
            ;;
    esac
}

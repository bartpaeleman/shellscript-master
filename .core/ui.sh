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

ui_clear_screen() {
    if [[ -t 1 ]]; then
        printf '\033[2J\033[3J\033[H' || clear 2>/dev/null || true
    fi
}

ui_pause() {
    printf "\n"
    read -rp "Druk op [Enter] of typ '0' om terug te keren... " _
}

ui_read_menu_choice() {
    local __var_name="$1"
    local __label="${2:-Choice}"
    local __val=""
    read -rp "${__label} [0]: " __val
    __val="${__val#"${__val%%[![:space:]]*}"}"
    __val="${__val%"${__val##*[![:space:]]}"}"
    [[ -z "$__val" ]] && __val="0"
    printf -v "$__var_name" '%s' "$__val"
}

ui_read_path() {
    local __var_name="$1"
    local __prompt="$2"
    local __default="${3:-}"
    local __val=""

    if [[ -n "${BASH_VERSION:-}" ]]; then
        local __tty_in=""
        if [[ ! -t 0 ]] && { : </dev/tty; } 2>/dev/null; then
            __tty_in="/dev/tty"
        fi
        printf "%s: " "$__prompt"
        local __ch=""
        while true; do
            if [[ -n "$__tty_in" ]]; then
                IFS= read -r -s -n 1 __ch <"$__tty_in" || break
            else
                IFS= read -r -s -n 1 __ch || break
            fi

            if [[ -z "$__ch" ]]; then
                printf "\n"
                break
            elif [[ "$__ch" == $'\177' || "$__ch" == $'\b' ]]; then
                if [[ ${#__val} -gt 0 ]]; then
                    __val="${__val%?}"
                    printf "\b \b"
                fi
            elif [[ "$__ch" == $'\t' ]]; then
                local __search="$__val"
                local __tilde_mode=0
                if [[ "$__search" == "~" ]]; then
                    __search="${HOME}/"
                    __tilde_mode=1
                elif [[ "$__search" == "~/"* ]]; then
                    __search="${HOME}/${__search#\~/}"
                    __tilde_mode=1
                fi

                local -a __matches=()
                local __m=""
                while IFS= read -r __m; do
                    __matches+=("$__m")
                done < <(compgen -f -- "$__search" 2>/dev/null)

                if [[ ${#__matches[@]} -eq 1 ]]; then
                    local __match="${__matches[0]}"
                    [[ -d "$__match" && "$__match" != */ ]] && __match="${__match}/"
                    if [[ "$__tilde_mode" -eq 1 && "$__match" == "${HOME}/"* ]]; then
                        __match="~/${__match#"${HOME}/"}"
                    fi
                    local __i
                    for ((__i = 0; __i < ${#__val}; __i++)); do printf "\b \b"; done
                    __val="$__match"
                    printf "%s" "$__val"
                elif [[ ${#__matches[@]} -gt 1 ]]; then
                    local __lcp="${__matches[0]}"
                    local __j
                    for ((__j = 1; __j < ${#__matches[@]}; __j++)); do
                        local __other="${__matches[$__j]}"
                        while [[ "$__other" != "$__lcp"* && -n "$__lcp" ]]; do
                            __lcp="${__lcp%?}"
                        done
                    done
                    if [[ "$__tilde_mode" -eq 1 && "$__lcp" == "${HOME}/"* ]]; then
                        __lcp="~/${__lcp#"${HOME}/"}"
                    fi
                    if [[ ${#__lcp} -gt ${#__val} ]]; then
                        local __i
                        for ((__i = 0; __i < ${#__val}; __i++)); do printf "\b \b"; done
                        __val="$__lcp"
                        printf "%s" "$__val"
                    else
                        printf "\n"
                        local __shown=0
                        for __m in "${__matches[@]}"; do
                            [[ -d "$__m" && "$__m" != */ ]] && __m="${__m}/"
                            printf "  %s\n" "$__m"
                            __shown=$((__shown + 1))
                            [[ "$__shown" -ge 20 ]] && { printf "  ... (%d meer)\n" "$((${#__matches[@]} - 20))"; break; }
                        done
                        printf "%s: %s" "$__prompt" "$__val"
                    fi
                fi
            else
                __val="${__val}${__ch}"
                printf "%s" "$__ch"
            fi
        done
    else
        IFS= read -r -p "${__prompt}: " __val || return 1
    fi

    __val="${__val#"${__val%%[![:space:]]*}"}"
    __val="${__val%"${__val##*[![:space:]]}"}"
    if [[ "$__val" == "0" ]]; then
        return 1
    fi
    [[ -z "$__val" && -n "$__default" ]] && __val="$__default"
    if [[ "$__val" == "~" ]]; then
        __val="$HOME"
    elif [[ "$__val" == "~/"* ]]; then
        __val="${HOME}/${__val#\~/}"
    fi
    printf -v "$__var_name" '%s' "$__val"
    return 0
}

ui_run_safe() {
    local __desc="$1"
    shift
    local __rc=0
    local __had_errexit=0
    local __err_file
    __err_file="$(mktemp 2>/dev/null || echo "/tmp/scripter_err_$$")"
    case "$-" in *e*) __had_errexit=1; set +e ;; esac
    "$@" 2> >(tee "$__err_file" >&2)
    __rc=$?
    [[ "$__had_errexit" -eq 1 ]] && set -e

    if [[ "$__rc" -ne 0 ]]; then
        printf "\n%b===============================================================%b\n" "${RED}${BOLD}" "${NC}"
        printf "%b[FOUT] Actie mislukt: %s (Exit code: %s)%b\n" "${RED}${BOLD}" "$__desc" "$__rc" "${NC}"
        if [[ -s "$__err_file" ]]; then
            printf "%bDetails:%b\n" "${YELLOW}" "${NC}"
            tail -n 5 "$__err_file" | sed 's/^/  /'
        fi
        printf "%b===============================================================%b\n" "${RED}${BOLD}" "${NC}"
        rm -f "$__err_file" 2>/dev/null || true
        read -rp "Druk op [Enter] of typ '0' om terug te keren naar het vorige scherm... " _
    else
        rm -f "$__err_file" 2>/dev/null || true
        ui_pause
    fi
    return 0
}

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

ui_cancel_msg() {
    printf "%b[Cancelled]%b Geen wijzigingen uitgevoerd.\n" "${YELLOW}" "${NC}"
}

ui_prompt_input() {
    local __var_name="$1"
    local __prompt="$2"
    local __default="${3:-}"
    local __val=""
    read -rp "${__prompt} (typ '0' of 'q' om te annuleren): " __val
    case "$__val" in
        0|q|Q|cancel|CANCEL)
            ui_cancel_msg
            return 1
            ;;
        "")
            __val="$__default"
            ;;
    esac
    printf -v "$__var_name" '%s' "$__val"
    return 0
}

ui_confirm_action() {
    local __prompt="$1"
    local __ans=""
    read -rp "${__prompt} [y/N] (of '0'/'q' om te annuleren): " __ans
    case "$__ans" in
        y|Y|yes|YES) return 0 ;;
        *) ui_cancel_msg; return 1 ;;
    esac
}

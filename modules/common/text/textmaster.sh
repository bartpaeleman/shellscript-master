#!/usr/bin/env bash
# modules/common/text/textmaster.sh - Universal Text & Log Utilities

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

_py_bin() {
    local p="$ROOT_DIR/.dep/.venv/bin/python"
    [[ -x "$p" ]] && echo "$p" || echo "python3"
}

show_help() {
    ui_header "TEXT MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +textmaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  stats [file]    1) Text statistics (text_stats.py)\n"
    printf "  replace         2) Search & replace with .bak backup\n"
    printf "  diff            3) Compare two files (diff -u)\n"
    printf "  merge           4) Merge multiple files\n"
    printf "  case            5) Case conversion (UPPERCASE / lowercase)\n"
    printf "  --help, -h         Show this help\n"
}

opt_stats() {
    local f="${1:-}"
    [[ -z "$f" ]] && read -rp "File path: " f
    [[ ! -f "$f" ]] && { ui_err "File not found: $f"; return 1; }
    "$(_py_bin)" "$MOD_DIR/text_stats.py" "$f"
}

opt_replace() {
    read -rp "Target file: " f
    [[ ! -f "$f" ]] && { ui_err "File not found: $f"; return 1; }
    read -rp "Search pattern: " pat
    read -rp "Replacement: " repl
    [[ -z "$pat" ]] && { ui_warn "Pattern required."; return 1; }
    grep -n "$pat" "$f" || { ui_info "No matches found."; return 0; }
    read -rp "Proceed with replace (creates ${f}.bak)? [y/N]: " ans
    [[ ! "$ans" =~ ^[Yy]$ ]] && return 0
    cp "$f" "${f}.bak"
    os_sed_inplace "s|${pat}|${repl}|g" "$f"
    ui_ok "Replaced in $f (backup: ${f}.bak)"
}

opt_diff() {
    read -rp "File 1: " f1
    read -rp "File 2: " f2
    [[ ! -f "$f1" || ! -f "$f2" ]] && { ui_err "Both files must exist."; return 1; }
    diff -u "$f1" "$f2" || true
}

opt_merge() {
    read -rp "Input files (space-separated): " files
    read -rp "Output file [merged.txt]: " out; out="${out:-merged.txt}"
    # shellcheck disable=SC2086
    cat $files > "$out" && ui_ok "Merged into $out"
}

opt_case() {
    read -rp "Input file: " f
    [[ ! -f "$f" ]] && { ui_err "File not found: $f"; return 1; }
    echo "1) UPPERCASE  2) lowercase"
    read -rp "Choice [1/2]: " m
    local out="${f}.converted"
    if [[ "$m" == "1" ]]; then
        tr '[:lower:]' '[:upper:]' < "$f" > "$out"
    else
        tr '[:upper:]' '[:lower:]' < "$f" > "$out"
    fi
    ui_ok "Saved: $out"
}

text_menu() {
    while true; do
        ui_clear_screen
        ui_header "TEXT MASTER CONTROL PANEL" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Text Statistics"  "Lines, words, char frequency"
        ui_item "2" "Search & Replace" "grep + sed with .bak backup"
        ui_item "3" "Compare Files"    "Unified diff"
        ui_item "4" "Merge Files"      "Combine multiple files"
        ui_item "5" "Case Conversion"  "UPPERCASE / lowercase"
        ui_item "0" "Terug"            ""
        printf "\n"
        read -rp "Choice: " c
        case "$c" in
            1) ui_run_safe "Text Statistics" opt_stats ;;
            2) ui_run_safe "Search & Replace" opt_replace ;;
            3) ui_run_safe "Compare Files" opt_diff ;;
            4) ui_run_safe "Merge Files" opt_merge ;;
            5) ui_run_safe "Case Conversion" opt_case ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    stats)          shift; opt_stats "${1:-}" ;;
    replace)        opt_replace ;;
    diff)           opt_diff ;;
    merge)          opt_merge ;;
    case)           opt_case ;;
    menu)           text_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

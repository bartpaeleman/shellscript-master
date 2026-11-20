#!/usr/bin/env bash
# modules/common/file/filemaster.sh - Universal File & Directory Manager

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
    ui_header "FILE MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +filemaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  rename          1) Bulk regex rename (Python, with preview)\n"
    printf "  mkdirs [file]   2) Create directory tree from text file\n"
    printf "  archive [dir]   3) Archive directory (.zip or .tar.gz)\n"
    printf "  cleanup [dir]   4) Clean .DS_Store, empty dirs, MD5 duplicates\n"
    printf "  compare         5) Compare two files or folders\n"
    printf "  sync            6) Sync/copy folder (rsync/cp)\n"
    printf "  csv [dir]       7) Export directory listing to CSV\n"
    printf "  find|fzf        8) Interactive finder (fzf)\n"
    printf "  large [dir]     9) Top 15 largest files\n"
    printf "  --help, -h         Show this help\n"
}

opt_rename() {
    ui_read_path dir "Target directory [.] (Tab = aanvullen, 0 = annuleren)" "." || return 0
    read -rp "Regex pattern: " pat
    read -rp "Replacement: " repl
    [[ -z "$pat" ]] && { ui_warn "Pattern required."; return 1; }
    "$(_py_bin)" - "$dir" "$pat" "$repl" <<'PY'
import os, re, sys
d, pat, repl = sys.argv[1], sys.argv[2], sys.argv[3]
rx = re.compile(pat)
changes = []
for f in sorted(os.listdir(d)):
    nf = rx.sub(repl, f)
    if nf != f:
        changes.append((f, nf))
if not changes:
    print("No files matched.")
    sys.exit(0)
print("Preview:")
for old, new in changes:
    print(f"  {old} -> {new}")
if input("Apply? [y/N]: ").lower() == "y":
    for old, new in changes:
        os.rename(os.path.join(d, old), os.path.join(d, new))
    print(f"Renamed {len(changes)} files.")
PY
}

opt_mkdirs() {
    local f="${1:-}"
    if [[ -z "$f" ]]; then
        ui_read_path f "Structure text file (Tab = aanvullen, 0 = annuleren)" || return 0
    fi
    [[ ! -f "$f" ]] && { ui_err "File not found: $f"; return 1; }
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$line" || "$line" == \#* ]] && continue
        mkdir -p "$line" && ui_ok "Created: $line"
    done < "$f"
}

opt_archive() {
    local dir="${1:-}"
    if [[ -z "$dir" ]]; then
        ui_read_path dir "Directory to archive [.] (Tab = aanvullen, 0 = annuleren)" "." || return 0
    fi
    dir="${dir:-.}"
    [[ ! -d "$dir" ]] && { ui_err "Not a directory: $dir"; return 1; }
    local base; base="$(basename "$dir")"
    echo "1) .zip  2) .tar.gz"
    read -rp "Format [1/2]: " fmt
    if [[ "$fmt" == "2" ]]; then
        tar -czf "${base}_$(date +%Y%m%d).tar.gz" "$dir" && ui_ok "Created ${base}_$(date +%Y%m%d).tar.gz"
    else
        zip -rq "${base}_$(date +%Y%m%d).zip" "$dir" && ui_ok "Created ${base}_$(date +%Y%m%d).zip"
    fi
}

opt_cleanup() {
    local dir="${1:-.}"
    ui_info "Removing .DS_Store and Thumbs.db in $dir..."
    find "$dir" -type f \( -name ".DS_Store" -o -name "Thumbs.db" \) -delete 2>/dev/null || true
    ui_info "Removing empty directories..."
    find "$dir" -type d -empty -delete 2>/dev/null || true
    ui_info "Scanning for MD5 duplicates..."
    "$(_py_bin)" - "$dir" <<'PY'
import hashlib, os, sys
from collections import defaultdict
by_size = defaultdict(list)
for root, _, files in os.walk(sys.argv[1]):
    for f in files:
        p = os.path.join(root, f)
        try:
            by_size[os.path.getsize(p)].append(p)
        except OSError:
            pass
dups = 0
for sz, paths in by_size.items():
    if len(paths) < 2: continue
    hashes = defaultdict(list)
    for p in paths:
        h = hashlib.md5(open(p, "rb").read()).hexdigest()
        hashes[h].append(p)
    for h, ps in hashes.items():
        if len(ps) > 1:
            dups += 1
            print(f"Duplicate ({sz}B): " + " | ".join(ps))
print(f"Found {dups} duplicate groups.")
PY
}

opt_compare() {
    ui_read_path p1 "Path 1 (Tab = aanvullen, 0 = annuleren)" || return 0
    ui_read_path p2 "Path 2 (Tab = aanvullen, 0 = annuleren)" || return 0
    if [[ -d "$p1" && -d "$p2" ]]; then
        diff -rq "$p1" "$p2" || true
    elif [[ -f "$p1" && -f "$p2" ]]; then
        diff -u "$p1" "$p2" || true
    else
        ui_err "Both paths must be existing files or directories."
    fi
}

opt_sync() {
    ui_read_path src "Source directory (Tab = aanvullen, 0 = annuleren)" || return 0
    ui_read_path dst "Destination directory (Tab = aanvullen, 0 = annuleren)" || return 0
    [[ ! -d "$src" ]] && { ui_err "Source not found: $src"; return 1; }
    mkdir -p "$dst"
    if command -v rsync >/dev/null 2>&1; then
        rsync -avh --progress "$src/" "$dst/"
    else
        cp -R "$src/"* "$dst/"
    fi
}

opt_csv() {
    local dir="${1:-.}"
    local out="listing_$(date +%Y%m%d_%H%M%S).csv"
    echo "path,size_bytes" > "$out"
    "$(_py_bin)" - "$dir" >> "$out" <<'PY'
import os, sys
for root, _, files in os.walk(sys.argv[1]):
    for f in files:
        p = os.path.join(root, f)
        try:
            print(f'"{p}",{os.path.getsize(p)}')
        except OSError:
            pass
PY
    ui_ok "Exported CSV: $out"
}

opt_fzf() {
    if ! command -v fzf >/dev/null 2>&1; then
        ui_warn "'fzf' is not installed. Install it via './scripter +deps install' or your package manager."
        return 1
    fi
    find . -maxdepth 4 2>/dev/null | fzf --preview 'ls -la {}'
}

opt_large() {
    local dir="${1:-.}"
    find "$dir" -type f -exec ls -lh {} + 2>/dev/null | sort -k5 -hr | awk 'NR <= 15'
}

file_menu() {
    while true; do
        ui_clear_screen
        ui_header "FILE MASTER CONTROL PANEL" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Bulk Rename"        "Python regex with preview"
        ui_item "2" "Create Dir Tree"    "From text file"
        ui_item "3" "Archive Directory"  ".zip or .tar.gz"
        ui_item "4" "Cleanup"            ".DS_Store, empty dirs, MD5 dups"
        ui_item "5" "Compare"            "Diff two files or folders"
        ui_item "6" "Folder Sync"        "Copy/sync via rsync or cp"
        ui_item "7" "CSV Export"         "Directory listing to CSV"
        ui_item "8" "Interactive Finder" "fzf file/dir browser"
        ui_item "9" "Largest Files"      "Top 15 largest files"
        ui_item "0" "Terug"              ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "Bulk Rename" opt_rename ;;
            2) ui_run_safe "Create Dir Tree" opt_mkdirs ;;
            3) ui_run_safe "Archive Directory" opt_archive ;;
            4) ui_run_safe "Cleanup" opt_cleanup ;;
            5) ui_run_safe "Compare" opt_compare ;;
            6) ui_run_safe "Folder Sync" opt_sync ;;
            7) ui_run_safe "CSV Export" opt_csv ;;
            8) ui_run_safe "Interactive Finder" opt_fzf ;;
            9) ui_run_safe "Largest Files" opt_large ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    rename)         opt_rename ;;
    mkdirs)         shift; opt_mkdirs "${1:-}" ;;
    archive)        shift; opt_archive "${1:-}" ;;
    cleanup)        shift; opt_cleanup "${1:-.}" ;;
    compare)        opt_compare ;;
    sync)           opt_sync ;;
    csv)            shift; opt_csv "${1:-.}" ;;
    find|fzf)       opt_fzf ;;
    large)          shift; opt_large "${1:-.}" ;;
    menu)           file_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

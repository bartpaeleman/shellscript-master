#!/usr/bin/env bash
# modules/common/data/datamaster.sh - Universal Data Processing Tools

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
    ui_header "DATA MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +datamaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  table [csv]     1) View CSV as ASCII table\n"
    printf "  delimiter       2) Convert CSV delimiter\n"
    printf "  convert         3) Convert format (CSV<->JSON, XML->JSON, YAML->JSON/CSV)\n"
    printf "  normalize [csv] 4) Normalize CSV (strip whitespace & empty rows)\n"
    printf "  deps            5) Check Python data dependencies (pandas, pyyaml)\n"
    printf "  json [file]        Pretty-print JSON\n"
    printf "  --help, -h         Show this help\n"
}

opt_table() {
    local f="${1:-}"
    if [[ -z "$f" ]]; then
        ui_read_path f "CSV file path (0 = annuleren)" || return 0
    fi
    [[ ! -f "$f" ]] && { ui_err "File not found: $f"; return 1; }
    "$(_py_bin)" - "$f" <<'PY'
import csv, sys
with open(sys.argv[1], newline="", encoding="utf-8-sig") as fh:
    rows = list(csv.reader(fh))
if not rows:
    print("Empty CSV."); sys.exit(0)
widths = [max(len(str(c)) for c in col) for col in zip(*rows)]
sep = "+-" + "-+-".join("-" * w for w in widths) + "-+"
print(sep)
for idx, r in enumerate(rows[:50]):
    print("| " + " | ".join(str(c).ljust(w) for c, w in zip(r, widths)) + " |")
    if idx == 0: print(sep)
print(sep)
PY
}

opt_delimiter() {
    ui_read_path f "Input CSV file (0 = annuleren)" || return 0
    [[ ! -f "$f" ]] && { ui_err "File not found: $f"; return 1; }
    read -rp "Current delimiter [,]: " d_in; d_in="${d_in:-,}"
    read -rp "New delimiter [;]: " d_out; d_out="${d_out:-;}"
    ui_read_path out "Output file [${f%.csv}_delim.csv] (0 = annuleren)" "${f%.csv}_delim.csv" || return 0
    "$(_py_bin)" - "$f" "$d_in" "$d_out" "$out" <<'PY'
import csv, sys
with open(sys.argv[1], newline="", encoding="utf-8-sig") as fin, open(sys.argv[4], "w", newline="", encoding="utf-8") as fout:
    w = csv.writer(fout, delimiter=sys.argv[3])
    for row in csv.reader(fin, delimiter=sys.argv[2]):
        w.writerow(row)
print(f"Saved: {sys.argv[4]}")
PY
}

opt_convert() {
    echo "1) CSV -> JSON  2) JSON -> CSV  3) XML -> JSON  4) YAML -> JSON"
    read -rp "Choice [1-4]: " m
    ui_read_path fin "Input file (0 = annuleren)" || return 0
    [[ ! -f "$fin" ]] && { ui_err "File not found: $fin"; return 1; }
    ui_read_path fout "Output file (0 = annuleren)" || return 0
    [[ -z "$fout" ]] && { ui_warn "Output file required."; return 1; }
    "$(_py_bin)" - "$m" "$fin" "$fout" <<'PY'
import csv, json, sys, xml.etree.ElementTree as ET
mode, fin, fout = sys.argv[1], sys.argv[2], sys.argv[3]
if mode == "1":
    with open(fin, newline="", encoding="utf-8-sig") as f:
        data = list(csv.DictReader(f))
    json.dump(data, open(fout, "w"), indent=2)
elif mode == "2":
    data = json.load(open(fin))
    if isinstance(data, list) and data:
        with open(fout, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(data[0].keys()))
            w.writeheader(); w.writerows(data)
elif mode == "3":
    def elem_to_dict(e):
        d = {c.tag: elem_to_dict(c) for c in e}
        return d if d else (e.text or "").strip()
    root = ET.parse(fin).getroot()
    json.dump({root.tag: elem_to_dict(root)}, open(fout, "w"), indent=2)
elif mode == "4":
    import yaml
    data = yaml.safe_load(open(fin))
    json.dump(data, open(fout, "w"), indent=2)
print(f"Converted -> {fout}")
PY
}

opt_normalize() {
    local f="${1:-}"
    if [[ -z "$f" ]]; then
        ui_read_path f "CSV file path (0 = annuleren)" || return 0
    fi
    [[ ! -f "$f" ]] && { ui_err "File not found: $f"; return 1; }
    local out="${f%.csv}_clean.csv"
    "$(_py_bin)" - "$f" "$out" <<'PY'
import csv, sys
with open(sys.argv[1], newline="", encoding="utf-8-sig") as fin, open(sys.argv[2], "w", newline="", encoding="utf-8") as fout:
    w = csv.writer(fout)
    for row in csv.reader(fin):
        cleaned = [c.strip() for c in row]
        if any(cleaned):
            w.writerow(cleaned)
print(f"Normalized -> {sys.argv[2]}")
PY
}

opt_deps() {
    local py; py="$(_py_bin)"
    ui_section "DATA PYTHON DEPENDENCIES ($py)"
    local pkg
    for pkg in pandas yaml; do
        if "$py" -c "import $pkg" >/dev/null 2>&1; then
            ui_ok "$pkg"
        else
            ui_warn "$pkg not installed in $py"
        fi
    done
}

opt_json() {
    local f="${1:-}"
    [[ ! -f "$f" ]] && { ui_err "File not found: $f"; return 1; }
    if command -v jq >/dev/null 2>&1; then jq . "$f"; else "$(_py_bin)" -m json.tool "$f"; fi
}

data_menu() {
    while true; do
        ui_clear_screen
        ui_header "DATA MASTER CONTROL PANEL" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "View CSV as Table"    "Pretty ASCII table"
        ui_item "2" "Convert Delimiter"    "Change CSV separator"
        ui_item "3" "Convert File Format"  "CSV<->JSON, XML->JSON, YAML->JSON"
        ui_item "4" "Normalize CSV"        "Strip whitespace & empty rows"
        ui_item "5" "Dependency Check"     "Check pandas & pyyaml"
        ui_item "0" "Terug"                ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "View CSV as Table" opt_table ;;
            2) ui_run_safe "Convert Delimiter" opt_delimiter ;;
            3) ui_run_safe "Convert File Format" opt_convert ;;
            4) ui_run_safe "Normalize CSV" opt_normalize ;;
            5) ui_run_safe "Dependency Check" opt_deps ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    table)          shift; opt_table "${1:-}" ;;
    delimiter)      opt_delimiter ;;
    convert)        opt_convert ;;
    normalize)      shift; opt_normalize "${1:-}" ;;
    deps)           opt_deps ;;
    json)           shift; opt_json "${1:-}" ;;
    menu)           data_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

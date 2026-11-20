#!/usr/bin/env bash
# modules/common/web/webmaster.sh - Universal Web Project Scaffold

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
    ui_header "WEB MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +webmaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  scaffold [dir]  1) Create web project structure (assets, includes, config, index.php)\n"
    printf "  readme [dir]    2) Generate README.md (generate_readme.py)\n"
    printf "  serve [port]    3) Start local Python HTTP server (default: 8000)\n"
    printf "  --help, -h         Show this help\n"
}

opt_scaffold() {
    local dir="${1:-}"
    if [[ -z "$dir" ]]; then
        ui_read_path dir "Project directory [./web-app] (0 = annuleren)" "./web-app" || return 0
    fi
    dir="${dir:-./web-app}"
    mkdir -p "$dir/assets/css" "$dir/assets/js" "$dir/assets/img" "$dir/includes" "$dir/config"
    cat > "$dir/index.php" <<'PHP'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Web App</title>
    <link rel="stylesheet" href="assets/css/style.css">
</head>
<body>
    <h1>Hello from Web Scaffold</h1>
    <script src="assets/js/app.js"></script>
</body>
</html>
PHP
    printf "body { font-family: system-ui, sans-serif; margin: 2rem; }\n" > "$dir/assets/css/style.css"
    printf "console.log('App ready');\n" > "$dir/assets/js/app.js"
    printf ".DS_Store\n.env\nnode_modules/\n" > "$dir/.gitignore"
    ui_ok "Scaffolded web project in $dir"
}

opt_readme() {
    local dir="${1:-}"
    if [[ -z "$dir" ]]; then
        ui_read_path dir "Project directory [.] (0 = annuleren)" "." || return 0
    fi
    dir="${dir:-.}"
    "$(_py_bin)" "$MOD_DIR/generate_readme.py" "$dir"
}

opt_serve() {
    local port="${1:-8000}"
    ui_info "Starting local HTTP server on http://localhost:${port} (Ctrl+C to stop)..."
    python3 -m http.server "$port"
}

web_menu() {
    while true; do
        ui_clear_screen
        ui_header "WEB MASTER CONTROL PANEL" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1" "Create Web Project" "Scaffold assets, includes, config, index.php"
        ui_item "2" "Generate README.md" "Via generate_readme.py"
        ui_item "3" "Local HTTP Server"  "Serve current directory via python3"
        ui_item "0" "Terug"              ""
        printf "\n"
        local c=""
        ui_read_menu_choice c "Choice"
        case "$c" in
            1) ui_run_safe "Create Web Project" opt_scaffold ;;
            2) ui_run_safe "Generate README.md" opt_readme ;;
            3) read -rp "Port [8000]: " p; ui_run_safe "Local HTTP Server" opt_serve "${p:-8000}" ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    scaffold)       shift; opt_scaffold "${1:-}" ;;
    readme)         shift; opt_readme "${1:-}" ;;
    serve)          shift; opt_serve "${1:-8000}" ;;
    menu)           web_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

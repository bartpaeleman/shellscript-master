#!/usr/bin/env bash
# .core/deps.sh - OS-Scoped Dependency & Update Center

CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$CORE_DIR/.." && pwd)"
[[ -z "${OS_TYPE:-}" ]] && source "$CORE_DIR/os_detect.sh"
[[ -z "${UI_LINE:-}" ]] && source "$CORE_DIR/ui.sh"

# Format: "cmd:brew_pkg:opkg_pkg:apt_pkg:description"
COMMON_DEPS=(
    "git:git:git:git:Version control"
    "curl:curl:curl:curl:HTTP client"
    "jq:jq:jq:jq:JSON processor"
    "python3:python3:python3:python3:Python 3 runtime"
    "zip:zip:zip:zip:Archive tool (filemaster)"
    "tar:gnu-tar:tar:tar:Archive tool (filemaster)"
    "fzf:fzf:fzf:fzf:Interactive finder (optional)"
)

MACOS_DEPS=(
    "ffmpeg:ffmpeg:ffmpeg:ffmpeg:Audio/video processing (audiomaster, videomaster, karaokemaster)"
    "nmap:nmap:nmap:nmap:Network scanner (networkmaster, cybermaster)"
    "exiftool:exiftool:perl-image-exiftool:libimage-exiftool-perl:Metadata tool (imagemaster, rename_ebooks)"
    "magick:imagemagick:imagemagick:imagemagick:ImageMagick CLI (imagemaster)"
    "yt-dlp:yt-dlp:yt-dlp:yt-dlp:Media downloader (audiomaster, videomaster)"
)

QNAP_DEPS=()

# Format: "import_name:pip_pkg:description"
COMMON_PYTHON_DEPS=(
    "requests:requests:HTTP requests"
    "yaml:pyyaml:YAML parser (datamaster)"
)

MACOS_PYTHON_DEPS=(
    "mutagen:mutagen:Audio tagger (audiomaster)"
    "PIL:pillow:Image processing (imagemaster)"
    "pypdf:pypdf:PDF metadata/ebooks (rename_ebooks)"
    "bs4:beautifulsoup4:HTML parsing (intelmaster)"
    "rich:rich:Terminal UI formatting (cybermaster)"
    "typer:typer:CLI framework (cybermaster)"
    "httpx:httpx:Async HTTP client (cybermaster)"
    "scapy:scapy:Packet manipulation (cybermaster)"
    "mailparser:mail-parser:Email parser (cybermaster)"
    "pydantic:pydantic:Data validation (cybermaster)"
    "authheaders:authheaders:SPF/DKIM/DMARC verification (cybermaster)"
    "dkim:dkimpy:DKIM verification (cybermaster)"
    "dateutil:python-dateutil:Date parsing (cybermaster, intelmaster)"
    "tldextract:tldextract:Domain extraction (cybermaster)"
    "cryptography:cryptography:TLS/crypto utilities (cybermaster)"
    "jinja2:jinja2:Report templating (cybermaster)"
    "weasyprint:weasyprint:PDF report generation (cybermaster)"
)

_dep_color() {
    local code="$1"; shift
    if [[ -t 1 ]]; then
        printf "\033[%sm%s\033[0m" "$code" "$*"
    else
        printf "%s" "$*"
    fi
}

_pip_bin() {
    if [[ -x "$ROOT_DIR/.dep/.venv/bin/pip" ]]; then
        echo "$ROOT_DIR/.dep/.venv/bin/pip"
    elif command -v pip3 >/dev/null 2>&1; then
        echo "pip3"
    else
        echo ""
    fi
}

_py_bin() {
    if [[ -x "$ROOT_DIR/.dep/.venv/bin/python" ]]; then
        echo "$ROOT_DIR/.dep/.venv/bin/python"
    elif command -v python3 >/dev/null 2>&1; then
        echo "python3"
    else
        echo ""
    fi
}

_active_bin_deps() {
    ACTIVE_BINS=("${COMMON_DEPS[@]}")
    if [[ "$OS_TYPE" == "macOS" || "${SHOW_ALL:-false}" == "true" ]]; then
        ACTIVE_BINS+=("${MACOS_DEPS[@]}")
    fi
    if [[ "$OS_TYPE" == "QNAP" || "${SHOW_ALL:-false}" == "true" ]]; then
        [[ ${#QNAP_DEPS[@]} -gt 0 ]] && ACTIVE_BINS+=("${QNAP_DEPS[@]}")
    fi
}

_active_py_deps() {
    ACTIVE_PY=("${COMMON_PYTHON_DEPS[@]}")
    if [[ "$OS_TYPE" == "macOS" || "${SHOW_ALL:-false}" == "true" ]]; then
        ACTIVE_PY+=("${MACOS_PYTHON_DEPS[@]}")
    fi
}

deps_status() {
    _active_bin_deps
    _active_py_deps
    echo "=== Dependency Status ($OS_TYPE / $ARCH / pkg: $PKG_MGR) ==="
    echo ""
    echo "--- CLI Binaries ---"
    local missing_bins=0
    local entry cmd brew_p opkg_p apt_p desc
    for entry in "${ACTIVE_BINS[@]}"; do
        IFS=':' read -r cmd brew_p opkg_p apt_p desc <<< "$entry"
        if command -v "$cmd" >/dev/null 2>&1; then
            printf "  [%s] %-12s - %s\n" "$(_dep_color '32' 'OK')" "$cmd" "$desc"
        else
            printf "  [%s] %-12s - %s\n" "$(_dep_color '31' 'MISSING')" "$cmd" "$desc"
            ((missing_bins++))
        fi
    done

    echo ""
    echo "--- Python Packages ---"
    local missing_py=0
    local py; py="$(_py_bin)"
    if [[ -n "$py" ]]; then
        local imp pkg pdesc
        for entry in "${ACTIVE_PY[@]}"; do
            IFS=':' read -r imp pkg pdesc <<< "$entry"
            if "$py" -c "import $imp" >/dev/null 2>&1; then
                printf "  [%s] %-14s - %s\n" "$(_dep_color '32' 'OK')" "$pkg" "$pdesc"
            else
                printf "  [%s] %-14s - %s\n" "$(_dep_color '31' 'MISSING')" "$pkg" "$pdesc"
                ((missing_py++))
            fi
        done
    else
        echo "  [SKIP] python3 is not installed."
    fi
    echo ""
    echo "Summary: $missing_bins missing binaries, $missing_py missing Python packages."
}

_install_pkg() {
    local brew_p="$1" opkg_p="$2" apt_p="$3"
    case "$PKG_MGR" in
        brew) brew install "$brew_p" ;;
        opkg) opkg install "$opkg_p" ;;
        apt)  sudo apt-get install -y "$apt_p" ;;
        dnf)  sudo dnf install -y "$apt_p" ;;
        apk)  sudo apk add "$apt_p" ;;
        *)    return 1 ;;
    esac
}

deps_install_missing() {
    _active_bin_deps
    _active_py_deps
    echo "Checking and installing missing dependencies for $OS_TYPE..."

    if [[ "$PKG_MGR" == "opkg" ]]; then
        opkg update >/dev/null 2>&1 || true
    elif [[ "$PKG_MGR" == "none" && "$OS_TYPE" == "QNAP" ]]; then
        echo "[INFO] Entware (opkg) niet gedetecteerd op QNAP — systeem-packages worden overgeslagen; Python .venv packages werken wel zelfstandig."
    fi

    local entry cmd brew_p opkg_p apt_p desc
    if [[ "$PKG_MGR" != "none" ]]; then
        for entry in "${ACTIVE_BINS[@]}"; do
            IFS=':' read -r cmd brew_p opkg_p apt_p desc <<< "$entry"
            if ! command -v "$cmd" >/dev/null 2>&1; then
                echo "Installing $cmd..."
                _install_pkg "$brew_p" "$opkg_p" "$apt_p" || echo "Warning: failed to install $cmd"
            fi
        done
    fi

    if [[ ! -x "$ROOT_DIR/.dep/.venv/bin/python3" ]] && command -v python3 >/dev/null 2>&1; then
        echo "Creating central Python virtual environment in $ROOT_DIR/.dep/.venv..."
        python3 -m venv "$ROOT_DIR/.dep/.venv" || echo "Warning: failed to create central .venv"
    fi

    local pip_cmd; pip_cmd="$(_pip_bin)"
    local py; py="$(_py_bin)"
    if [[ -n "$py" && -n "$pip_cmd" ]]; then
        if [[ -f "$ROOT_DIR/.dep/requirements.txt" ]]; then
            echo "Installing Python packages from .dep/requirements.txt..."
            "$pip_cmd" install -q -r "$ROOT_DIR/.dep/requirements.txt" 2>/dev/null || echo "Warning: some packages from .dep/requirements.txt failed to install"
        fi
        local imp pkg pdesc
        for entry in "${ACTIVE_PY[@]}"; do
            IFS=':' read -r imp pkg pdesc <<< "$entry"
            if ! "$py" -c "import $imp" >/dev/null 2>&1; then
                echo "Installing Python package $pkg..."
                "$pip_cmd" install "$pkg" 2>/dev/null || "$pip_cmd" install --user "$pkg" || echo "Warning: failed to install $pkg"
            fi
        done
    fi
}

deps_update_all() {
    echo "Updating system packages via $PKG_MGR..."
    case "$PKG_MGR" in
        brew) brew update && brew upgrade ;;
        opkg) opkg update && opkg upgrade ;;
        apt)  sudo apt-get update && sudo apt-get upgrade -y ;;
        dnf)  sudo dnf upgrade -y ;;
        apk)  sudo apk update && sudo apk upgrade ;;
        *)    echo "[INFO] Geen ondersteunde systeem-package manager ($PKG_MGR); systeem-update overgeslagen." ;;
    esac

    local pip_cmd; pip_cmd="$(_pip_bin)"
    if [[ -n "$pip_cmd" ]]; then
        _active_py_deps
        echo "Updating Python packages..."
        local entry imp pkg pdesc
        for entry in "${ACTIVE_PY[@]}"; do
            IFS=':' read -r imp pkg pdesc <<< "$entry"
            "$pip_cmd" install --upgrade "$pkg" 2>/dev/null || true
        done
    fi
}

# Just-in-time, race-free self-healing helper for Python-dependent modules.
# Usage: deps_ensure_python [import_name ...]
deps_ensure_python() {
    local py_bin="$ROOT_DIR/.dep/.venv/bin/python3"
    local pip_bin="$ROOT_DIR/.dep/.venv/bin/pip"
    local req_file="$ROOT_DIR/.dep/requirements.txt"
    local lock_dir="$ROOT_DIR/.dep/.venv.lock"
    local -a imports=("$@")

    if [[ ${#imports[@]} -eq 0 ]]; then
        imports=("requests" "yaml")
    fi

    # Fast-path: venv exists and all required imports succeed in one Python call
    if [[ -x "$py_bin" ]] && "$py_bin" -c "import sys; [__import__(m) for m in sys.argv[1:]]" "${imports[@]}" >/dev/null 2>&1; then
        return 0
    fi

    echo "[INFO] Ontbrekende Python-dependencies gedetecteerd — automatisch installeren in .dep/.venv..." >&2

    mkdir -p "$ROOT_DIR/.dep"
    local waited=0
    while ! mkdir "$lock_dir" 2>/dev/null; do
        sleep 1
        ((waited++))
        if [[ $waited -ge 60 ]]; then
            echo "[WARN] Lock timeout op $lock_dir; geforceerde voortzetting." >&2
            rm -rf "$lock_dir" 2>/dev/null || true
            mkdir "$lock_dir" 2>/dev/null || break
        fi
    done
    trap 'rmdir "$lock_dir" 2>/dev/null || true' RETURN

    # Re-check after acquiring lock in case another process finished installing
    if [[ -x "$py_bin" ]] && "$py_bin" -c "import sys; [__import__(m) for m in sys.argv[1:]]" "${imports[@]}" >/dev/null 2>&1; then
        return 0
    fi

    if [[ ! -x "$py_bin" ]]; then
        if ! command -v python3 >/dev/null 2>&1; then
            echo "[ERR] python3 niet gevonden in PATH; kan .dep/.venv niet aanmaken." >&2
            return 1
        fi
        python3 -m venv "$ROOT_DIR/.dep/.venv" >&2 || {
            echo "[ERR] Aanmaken van $ROOT_DIR/.dep/.venv is mislukt." >&2
            return 1
        }
    fi

    if [[ -f "$req_file" ]]; then
        "$pip_bin" install -q --disable-pip-version-check -r "$req_file" >&2 || {
            echo "[ERR] Installatie vanuit $req_file is mislukt." >&2
            return 1
        }
    fi

    # Install any extra requested module names if still missing
    local mod
    for mod in "${imports[@]}"; do
        if ! "$py_bin" -c "import $mod" >/dev/null 2>&1; then
            "$pip_bin" install -q --disable-pip-version-check "$mod" >&2 || true
        fi
    done

    if ! "$py_bin" -c "import sys; [__import__(m) for m in sys.argv[1:]]" "${imports[@]}" >/dev/null 2>&1; then
        echo "[ERR] Niet alle vereiste Python-dependencies konden worden geladen: ${imports[*]}" >&2
        return 1
    fi
    return 0
}

deps_menu() {
    while true; do
        ui_clear_screen
        ui_header "DEPENDENCY & UPDATE CENTER" "System : ${CYAN}${OS_TYPE}${NC} | PkgMgr: ${CYAN}${PKG_MGR}${NC}"
        ui_item "1" "Check Status"         "Binaries & Python packages"
        ui_item "2" "Install Missing"      "Installeer ontbrekende tools"
        ui_item "3" "Update All"           "Update tools & packages"
        ui_item "0" "Terug"                ""
        printf "\n"
        local choice=""
        ui_read_menu_choice choice "Choice"
        case "$choice" in
            1) ui_run_safe "Check Dependencies" deps_status ;;
            2) ui_run_safe "Install Dependencies" deps_install_missing ;;
            3) ui_run_safe "Update Dependencies" deps_update_all ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-status}" in
        status|check) deps_status ;;
        install)      deps_install_missing ;;
        update)       deps_update_all ;;
        menu)         deps_menu ;;
        *)
            echo "Usage: $0 {status|install|update|menu}"
            exit 1
            ;;
    esac
fi

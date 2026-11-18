#!/usr/bin/env bash
# .core/deps.sh - Dependency & Update Center for Master Hub

CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.core/os_detect.sh
[[ -z "${OS_TYPE:-}" ]] && source "$CORE_DIR/os_detect.sh"

# Required/optional CLI binaries: "cmd:brew_pkg:opkg_pkg:apt_pkg:description"
DEPS_BINARIES=(
    "git:git:git:git:Version control"
    "curl:curl:curl:curl:HTTP client"
    "jq:jq:jq:jq:JSON processor"
    "python3:python3:python3:python3:Python 3 runtime"
    "ffmpeg:ffmpeg:ffmpeg:ffmpeg:Audio/video processing (audiomaster, videomaster, karaokemaster)"
    "nmap:nmap:nmap:nmap:Network scanner (networkmaster, cybermaster)"
    "exiftool:exiftool:perl-image-exiftool:libimage-exiftool-perl:Metadata tool (imagemaster, rename_ebooks)"
    "magick:imagemagick:imagemagick:imagemagick:ImageMagick CLI (imagemaster)"
    "yt-dlp:yt-dlp:yt-dlp:yt-dlp:Media downloader (audiomaster, videomaster)"
)

# Required/optional Python packages: "import_name:pip_pkg:description"
DEPS_PYTHON=(
    "mutagen:mutagen:Audio tagger (audiomaster)"
    "PIL:pillow:Image processing (imagemaster)"
    "pypdf:pypdf:PDF metadata/ebooks (rename_ebooks)"
    "requests:requests:HTTP requests (intelmaster, cybermaster)"
    "bs4:beautifulsoup4:HTML parsing (intelmaster)"
)

_dep_color() {
    local code="$1"
    shift
    if [[ -t 1 ]]; then
        printf "\033[%sm%s\033[0m" "$code" "$*"
    else
        printf "%s" "$*"
    fi
}

deps_status() {
    echo "=== Dependency Status ($OS_TYPE / $ARCH / pkg: $PKG_MGR) ==="
    echo ""
    echo "--- CLI Binaries ---"
    local missing_bins=0
    local entry cmd brew_p opkg_p apt_p desc
    for entry in "${DEPS_BINARIES[@]}"; do
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
    if command -v python3 >/dev/null 2>&1; then
        local imp pkg pdesc
        for entry in "${DEPS_PYTHON[@]}"; do
            IFS=':' read -r imp pkg pdesc <<< "$entry"
            if python3 -c "import $imp" >/dev/null 2>&1; then
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
        *)    echo "No supported package manager found for $OS_TYPE." ; return 1 ;;
    esac
}

deps_install_missing() {
    echo "Checking and installing missing dependencies..."
    local entry cmd brew_p opkg_p apt_p desc
    for entry in "${DEPS_BINARIES[@]}"; do
        IFS=':' read -r cmd brew_p opkg_p apt_p desc <<< "$entry"
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Installing $cmd ($brew_p)..."
            _install_pkg "$brew_p" "$opkg_p" "$apt_p" || echo "Warning: failed to install $cmd"
        fi
    done

    if command -v python3 >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then
        local imp pkg pdesc
        for entry in "${DEPS_PYTHON[@]}"; do
            IFS=':' read -r imp pkg pdesc <<< "$entry"
            if ! python3 -c "import $imp" >/dev/null 2>&1; then
                echo "Installing Python package $pkg..."
                pip3 install --user "$pkg" 2>/dev/null || pip3 install "$pkg" || echo "Warning: failed to install $pkg"
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
        *)    echo "No supported package manager found." ;;
    esac

    if command -v pip3 >/dev/null 2>&1; then
        echo "Updating Python packages..."
        local entry imp pkg pdesc
        for entry in "${DEPS_PYTHON[@]}"; do
            IFS=':' read -r imp pkg pdesc <<< "$entry"
            pip3 install --upgrade --user "$pkg" 2>/dev/null || true
        done
    fi
}

deps_menu() {
    while true; do
        echo ""
        echo "=== Dependency & Update Center ==="
        echo "1) Check status of all binaries & Python packages"
        echo "2) Install missing dependencies"
        echo "3) Update all tools & packages"
        echo "0) Back"
        read -rp "Choice: " choice
        case "$choice" in
            1) deps_status ;;
            2) deps_install_missing ;;
            3) deps_update_all ;;
            0|q|Q) break ;;
            *) echo "Invalid choice." ;;
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

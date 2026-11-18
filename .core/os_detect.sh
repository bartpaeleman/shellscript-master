#!/usr/bin/env bash
# .core/os_detect.sh - Platform, architecture, and package manager detection

detect_os() {
    local uname_s
    uname_s="$(uname -s 2>/dev/null || echo Unknown)"
    ARCH="$(uname -m 2>/dev/null || echo unknown)"

    if [[ "$uname_s" == "Darwin" ]]; then
        OS_TYPE="macOS"
    elif [[ -f /etc/config/uLinux.conf ]] || [[ -d /share/CACHEDEV1_DATA ]] || [[ -x /sbin/getcfg ]]; then
        OS_TYPE="QNAP"
    elif [[ "$uname_s" == "Linux" ]]; then
        OS_TYPE="Linux"
    else
        OS_TYPE="Unknown"
    fi

    if command -v brew >/dev/null 2>&1; then
        PKG_MGR="brew"
    elif command -v opkg >/dev/null 2>&1; then
        PKG_MGR="opkg"
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v apk >/dev/null 2>&1; then
        PKG_MGR="apk"
    else
        PKG_MGR="none"
    fi

    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        IS_ROOT="true"
    else
        IS_ROOT="false"
    fi

    export OS_TYPE ARCH PKG_MGR IS_ROOT
}

# --- OS-ABSTRACTION WRAPPERS (macOS Bash 3.2 + GNU/Linux/QNAP portable) ---
os_is_macos() { [[ "${OS_TYPE:-}" == "macOS" ]]; }
os_is_qnap()  { [[ "${OS_TYPE:-}" == "QNAP" ]]; }
os_is_linux() { [[ "${OS_TYPE:-}" == "Linux" ]]; }

os_sed_inplace() {
    local expr="$1"
    local file="$2"
    if os_is_macos; then
        sed -i '' "$expr" "$file"
    else
        sed -i "$expr" "$file"
    fi
}

os_readlink_f() {
    local target="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$target"
    elif readlink -f "$target" >/dev/null 2>&1; then
        readlink -f "$target"
    else
        local dir base
        dir="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)"
        base="$(basename "$target")"
        echo "${dir}/${base}"
    fi
}

detect_os

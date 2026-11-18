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

detect_os

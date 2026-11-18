#!/usr/bin/env bash
# modules/qnap/qnapmaster.sh - QNAP-specific hooks & maintenance

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=.core/os_detect.sh
[[ -z "${OS_TYPE:-}" ]] && source "$ROOT_DIR/.core/os_detect.sh"

qnap_container_status() {
    echo "=== QNAP Container Station Status ==="
    if command -v docker >/dev/null 2>&1; then
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    elif command -v system-docker >/dev/null 2>&1; then
        system-docker ps -a
    else
        echo "Docker / Container Station CLI not found."
    fi
}

qnap_share_cleanup() {
    echo "=== QNAP Share Cleanup (@Recycle / .@__thumb) ==="
    local share_root="/share"
    if [[ ! -d "$share_root" ]]; then
        echo "No /share directory found (not running on QNAP?)."
        return 1
    fi
    echo "Scanning $share_root for @Recycle and .@__thumb directories..."
    find "$share_root" -maxdepth 3 \( -name "@Recycle" -o -name ".@__thumb" \) -exec du -sh {} + 2>/dev/null || true
    read -rp "Purge @Recycle contents? [y/N]: " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        find "$share_root" -maxdepth 3 -name "@Recycle" -exec rm -rf {}/* + 2>/dev/null || true
        echo "Cleanup complete."
    else
        echo "Skipped."
    fi
}

qnap_entware_update() {
    echo "=== QNAP Entware (opkg) Update ==="
    if command -v opkg >/dev/null 2>&1; then
        opkg update && opkg upgrade
    else
        echo "opkg (Entware) not installed."
        return 1
    fi
}

qnap_menu() {
    while true; do
        echo ""
        echo "=== QNAP Master ($OS_TYPE) ==="
        echo "1) Container Station status"
        echo "2) Share cleanup (@Recycle / .@__thumb)"
        echo "3) Entware (opkg) update & upgrade"
        echo "0) Back"
        read -rp "Choice: " choice
        case "$choice" in
            1) qnap_container_status ;;
            2) qnap_share_cleanup ;;
            3) qnap_entware_update ;;
            0|q|Q) break ;;
            *) echo "Invalid choice." ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-menu}" in
        containers|status) qnap_container_status ;;
        cleanup)           qnap_share_cleanup ;;
        entware|update)    qnap_entware_update ;;
        menu)              qnap_menu ;;
        --help|-h)
            echo "Usage: $0 {containers|cleanup|entware|menu}"
            ;;
        *)
            echo "Unknown subcommand: $1"
            exit 1
            ;;
    esac
fi

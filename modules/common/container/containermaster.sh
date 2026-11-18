#!/usr/bin/env bash
# modules/common/container/containermaster.sh - Universal Docker / Container Station Manager

set -uo pipefail

MOD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$MOD_DIR/../../.." && pwd)"
source "$ROOT_DIR/.core/os_detect.sh"
source "$ROOT_DIR/.core/ui.sh"

# QNAP Container Station PATH support
if os_is_qnap && [[ -d "/share/CACHEDEV1_DATA/.qpkg/container-station/bin" ]]; then
    export PATH="/share/CACHEDEV1_DATA/.qpkg/container-station/bin:$PATH"
fi

_docker_cmd() {
    if command -v docker >/dev/null 2>&1; then
        echo "docker"
    elif command -v system-docker >/dev/null 2>&1; then
        echo "system-docker"
    else
        echo ""
    fi
}

_require_docker() {
    DOCKER_BIN="$(_docker_cmd)"
    if [[ -z "$DOCKER_BIN" ]]; then
        ui_err "Docker / Container Station CLI not found."
        return 1
    fi
    if ! "$DOCKER_BIN" info >/dev/null 2>&1; then
        ui_err "Docker daemon is not running (start Docker Desktop / Colima / OrbStack / Container Station)."
        return 1
    fi
}

_select_container() {
    local filter="${1:-all}"
    local list=()
    local i=1
    local cmd_args=("ps")
    [[ "$filter" == "all" ]] && cmd_args+=("-a")
    [[ "$filter" == "stopped" ]] && cmd_args+=("-a" "--filter" "status=exited" "--filter" "status=created")
    cmd_args+=("--format" "{{.Names}}")

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        list+=("$name")
        printf "  %2d) %s\n" "$i" "$name" >&2
        ((i++))
    done < <("$DOCKER_BIN" "${cmd_args[@]}" 2>/dev/null)

    if [[ ${#list[@]} -eq 0 ]]; then
        ui_warn "No matching containers found." >&2
        return 1
    fi
    local num
    read -rp "Select container [1-${#list[@]}]: " num
    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 && "$num" -le ${#list[@]} ]]; then
        echo "${list[$((num-1))]}"
        return 0
    fi
    return 1
}

show_help() {
    ui_header "CONTAINER MASTER - UNIVERSAL" "System : ${CYAN}${OS_TYPE}${NC}"
    printf "Usage: scripter +containermaster [subcommand]\n\n"
    printf "Subcommands:\n"
    printf "  list|ps         1) List all containers (status, uptime, image, ports)\n"
    printf "  logs [name]     2) View live logs (Ctrl+C returns to menu)\n"
    printf "  inspect [name]  3) Inspect container JSON\n"
    printf "  start [name]    4) Start a stopped container\n"
    printf "  stop [name]     5) Stop a running container\n"
    printf "  restart [name]  6) Restart a container\n"
    printf "  shell|exec [n]  7) Open interactive /bin/bash (fallback /bin/sh)\n"
    printf "  create|stack    8) Create new container or compose stack\n"
    printf "  rm [name]       9) Remove a container\n"
    printf "  prune          10) Interactive system cleanup\n"
    printf "  --help, -h         Show this help\n"
}

opt_list() {
    _require_docker || return 1
    ui_section "CONTAINERS (ALL)"
    "$DOCKER_BIN" ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
}

opt_logs() {
    _require_docker || return 1
    local c="${1:-}"
    [[ -z "$c" ]] && c="$(_select_container all)" || true
    [[ -z "$c" ]] && return 0
    ui_info "Streaming logs for '$c' (press Ctrl+C to return)..."
    trap 'true' INT
    "$DOCKER_BIN" logs -f --tail 100 "$c" || true
    trap - INT
}

opt_inspect() {
    _require_docker || return 1
    local c="${1:-}"
    [[ -z "$c" ]] && c="$(_select_container all)" || true
    [[ -z "$c" ]] && return 0
    local py="$ROOT_DIR/.dep/.venv/bin/python"
    [[ ! -x "$py" ]] && py="python3"
    if [[ -f "$MOD_DIR/inspect_viewer.py" ]] && command -v "$py" >/dev/null 2>&1; then
        "$DOCKER_BIN" inspect "$c" | "$py" "$MOD_DIR/inspect_viewer.py"
    elif command -v jq >/dev/null 2>&1; then
        "$DOCKER_BIN" inspect "$c" | jq .
    else
        "$DOCKER_BIN" inspect "$c"
    fi
}

opt_start() {
    _require_docker || return 1
    local c="${1:-}"
    [[ -z "$c" ]] && c="$(_select_container stopped)" || true
    [[ -z "$c" ]] && return 0
    "$DOCKER_BIN" start "$c" && ui_ok "Started '$c'."
}

opt_stop() {
    _require_docker || return 1
    local c="${1:-}"
    [[ -z "$c" ]] && c="$(_select_container running)" || true
    [[ -z "$c" ]] && return 0
    "$DOCKER_BIN" stop "$c" && ui_ok "Stopped '$c'."
}

opt_restart() {
    _require_docker || return 1
    local c="${1:-}"
    [[ -z "$c" ]] && c="$(_select_container all)" || true
    [[ -z "$c" ]] && return 0
    "$DOCKER_BIN" restart "$c" && ui_ok "Restarted '$c'."
}

opt_shell() {
    _require_docker || return 1
    local c="${1:-}"
    [[ -z "$c" ]] && c="$(_select_container running)" || true
    [[ -z "$c" ]] && return 0
    ui_info "Opening shell in '$c'..."
    "$DOCKER_BIN" exec -it "$c" /bin/bash 2>/dev/null || "$DOCKER_BIN" exec -it "$c" /bin/sh
}

opt_create() {
    _require_docker || return 1
    echo "1) Start from docker-compose.yml  2) Run single container manually"
    read -rp "Choice [1/2]: " m
    if [[ "$m" == "1" ]]; then
        read -rp "Path to docker-compose.yml [./docker-compose.yml]: " f
        f="${f:-./docker-compose.yml}"
        [[ ! -f "$f" ]] && { ui_err "File not found: $f"; return 1; }
        if "$DOCKER_BIN" compose version >/dev/null 2>&1; then
            "$DOCKER_BIN" compose -f "$f" up -d
        elif command -v docker-compose >/dev/null 2>&1; then
            docker-compose -f "$f" up -d
        else
            ui_err "Neither 'docker compose' nor 'docker-compose' found."
        fi
    else
        read -rp "Container name: " cname
        read -rp "Image (e.g. nginx:alpine): " img
        read -rp "Port mapping (e.g. 8080:80, optional): " port
        read -rp "Volume mount (e.g. /host:/container, optional): " vol
        [[ -z "$cname" || -z "$img" ]] && { ui_warn "Name and image required."; return 1; }
        local args=("run" "-d" "--name" "$cname")
        [[ -n "$port" ]] && args+=("-p" "$port")
        [[ -n "$vol" ]] && args+=("-v" "$vol")
        args+=("$img")
        "$DOCKER_BIN" "${args[@]}"
    fi
}

opt_rm() {
    _require_docker || return 1
    local c="${1:-}"
    [[ -z "$c" ]] && c="$(_select_container all)" || true
    [[ -z "$c" ]] && return 0
    read -rp "Remove '$c'? [y/N]: " ans
    [[ ! "$ans" =~ ^[Yy]$ ]] && return 0
    "$DOCKER_BIN" rm "$c" 2>/dev/null || {
        read -rp "Container is running. Force remove (--force)? [y/N]: " f
        [[ "$f" =~ ^[Yy]$ ]] && "$DOCKER_BIN" rm --force "$c"
    }
}

opt_prune() {
    _require_docker || return 1
    echo "1) Prune stopped containers & dangling images/networks (safe)"
    printf "2) %bPrune ALL unused images & volumes (DESTRUCTIVE)%b\n" "${RED}${BOLD}" "${NC}"
    read -rp "Choice [1/2]: " p
    case "$p" in
        1) "$DOCKER_BIN" system prune -f ;;
        2)
            read -rp "Are you SURE you want to delete unused volumes? [y/N]: " ans
            [[ "$ans" =~ ^[Yy]$ ]] && "$DOCKER_BIN" system prune -a --volumes -f
            ;;
    esac
}

container_menu() {
    while true; do
        ui_clear_screen
        ui_header "CONTAINER MASTER CONTROL PANEL" "System : ${CYAN}${OS_TYPE}${NC}"
        ui_item "1"  "List Containers"   "Status, uptime, image, ports"
        ui_item "2"  "View Live Logs"    "docker logs -f (Ctrl+C safe)"
        ui_item "3"  "Inspect Container" "Formatted JSON inspection"
        ui_item "4"  "Start Container"   "Start a stopped container"
        ui_item "5"  "Stop Container"    "Stop a running container"
        ui_item "6"  "Restart Container" "Restart a container"
        ui_item "7"  "Shell Access"      "/bin/bash (fallback /bin/sh)"
        ui_item "8"  "Create New Stack"  "Compose file or manual run"
        ui_item "9"  "Remove Container"  "Delete (with --force option)"
        ui_item "10" "System Cleanup"    "Prune containers, images, volumes"
        ui_item "0"  "Terug"             ""
        printf "\n"
        read -rp "Choice: " c
        case "$c" in
            1)  ui_run_safe "List Containers" opt_list ;;
            2)  ui_run_safe "View Live Logs" opt_logs ;;
            3)  ui_run_safe "Inspect Container" opt_inspect ;;
            4)  ui_run_safe "Start Container" opt_start ;;
            5)  ui_run_safe "Stop Container" opt_stop ;;
            6)  ui_run_safe "Restart Container" opt_restart ;;
            7)  ui_run_safe "Shell Access" opt_shell ;;
            8)  ui_run_safe "Create New Stack" opt_create ;;
            9)  ui_run_safe "Remove Container" opt_rm ;;
            10) ui_run_safe "System Cleanup" opt_prune ;;
            0|q|Q) break ;;
            *) ui_warn "Invalid choice."; ui_pause ;;
        esac
    done
}

case "${1:-menu}" in
    -h|--help|help) show_help ;;
    list|ps|status) opt_list ;;
    logs)           shift; opt_logs "${1:-}" ;;
    inspect)        shift; opt_inspect "${1:-}" ;;
    start)          shift; opt_start "${1:-}" ;;
    stop)           shift; opt_stop "${1:-}" ;;
    restart)        shift; opt_restart "${1:-}" ;;
    shell|exec)     shift; opt_shell "${1:-}" ;;
    create|stack)   opt_create ;;
    rm)             shift; opt_rm "${1:-}" ;;
    prune)          opt_prune ;;
    menu)           container_menu ;;
    *)              ui_err "Unknown subcommand: $1"; show_help; exit 1 ;;
esac

#!/usr/bin/env bash
# Wrapper script to run CYBER python scripts using the central scripter .dep/.venv

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPTER_ROOT="$(cd "$BASE_DIR/../../../.." && pwd)"
CENTRAL_VENV="$SCRIPTER_ROOT/.dep/.venv"
CENTRAL_PY="$CENTRAL_VENV/bin/python3"

# Just-in-time self-healing dependency check via .core/deps.sh
if [[ -f "$SCRIPTER_ROOT/.core/deps.sh" ]]; then
    # shellcheck source=/dev/null
    source "$SCRIPTER_ROOT/.core/deps.sh"
    deps_ensure_python httpx typer rich pydantic yaml jinja2 dateutil tldextract mailparser authheaders dkim cryptography || {
        echo "[error] Initialisatie van Python-dependencies via .core/deps.sh is mislukt." >&2
        exit 1
    }
else
    echo "[error] Centrale .core/deps.sh niet gevonden in $SCRIPTER_ROOT/.core/deps.sh" >&2
    exit 1
fi

if [[ ! -x "$CENTRAL_PY" ]]; then
    echo "[error] Python interpreter niet gevonden in $CENTRAL_PY" >&2
    exit 1
fi

# Run the passed python script and arguments
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <python_script> [args...]" >&2
    exit 1
fi

exec "$CENTRAL_PY" "$@"

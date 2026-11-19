#!/usr/bin/env bash
# Shell aliases and wrappers for CYBER toolset

CYBER_MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_WRAPPER="$CYBER_MASTER_DIR/common/run_python.sh"

# 1. mailtrace: Roept mail_analyzer.py aan en toont de terminal TUI
mailtrace() {
    if [[ -z "${1:-}" ]]; then
        echo "Usage: mailtrace <path_to_eml_file>"
        return 1
    fi
    "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/mail/mail_analyzer.py" "$1"
}

# 2. threatctx: Sequentiële pipeline voor target verrijking, scoring en rapportage
threatctx() {
    local target="${1:-}"
    local format="${2:-md}"
    if [[ -z "$target" ]]; then
        echo "Usage: threatctx <target_ip_or_domain> [md|html|pdf]"
        return 1
    fi

    local tmp_enriched tmp_scored
    tmp_enriched="$(mktemp "${TMPDIR:-/tmp}/cyber_enriched.XXXXXX")"
    tmp_scored="$(mktemp "${TMPDIR:-/tmp}/cyber_scored.XXXXXX")"

    _threatctx_cleanup() {
        rm -f "$tmp_enriched" "$tmp_scored" 2>/dev/null || true
    }

    local init_json
    init_json="$(printf '{"target": "%s"}' "${target//\"/\\\"}")"

    # Stap 1: Verrijking (sequentieel naar tijdelijk bestand)
    if ! printf '%s\n' "$init_json" | "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/enrich/enricher.py" > "$tmp_enriched"; then
        echo "[warn] Enricher gaf een fout; terugval op minimale target-JSON." >&2
        printf '%s\n' "$init_json" > "$tmp_enriched"
    fi
    if [[ ! -s "$tmp_enriched" ]]; then
        echo "[warn] Enricher leverde lege output; terugval op minimale target-JSON." >&2
        printf '%s\n' "$init_json" > "$tmp_enriched"
    fi

    # Stap 2: Risk Scoring (leest gegarandeerd van ingevuld bestand)
    if ! "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/scoring/risk_scorer.py" --target "$target" < "$tmp_enriched" > "$tmp_scored"; then
        echo "[error] Risk scorer is mislukt." >&2
        _threatctx_cleanup
        return 1
    fi
    if [[ ! -s "$tmp_scored" ]]; then
        cp "$tmp_enriched" "$tmp_scored"
    fi

    # Stap 3: Rapportage (md, html, of pdf)
    if ! "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/reporting/reporter.py" --format "$format" < "$tmp_scored"; then
        echo "[error] Reporter is mislukt." >&2
        _threatctx_cleanup
        return 1
    fi

    _threatctx_cleanup
}

# 3. mhdr: Gooit stdin in mail_analyzer en toont key findings via jq
mhdr() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required for mhdr. Please install jq." >&2
        return 1
    fi

    # Read stdin to a temporary file
    local temp_file
    temp_file="$(mktemp)"
    cat > "$temp_file"

    # Process and pipe to jq to extract key findings
    "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/mail/mail_analyzer.py" "$temp_file" --json | \
    jq '{
        "Origin IP": .ioc.originating_ip,
        "SPF": .mail.auth.spf,
        "DKIM": .mail.auth.dkim,
        "Spoof Likelihood / Risk Score": .risk_score
    }'

    rm -f "$temp_file"
}

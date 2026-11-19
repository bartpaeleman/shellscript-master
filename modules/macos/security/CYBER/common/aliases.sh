#!/usr/bin/env bash
# Shell aliases and wrappers for CYBER toolset

CYBER_MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_WRAPPER="$CYBER_MASTER_DIR/common/run_python.sh"

# Render a Markdown file cleanly to the terminal
_cyber_render_markdown() {
    local md_file="$1"
    if [[ ! -f "$md_file" ]]; then
        echo "[error] Markdown-bestand niet gevonden: $md_file" >&2
        return 1
    fi

    echo ""
    echo "================================================================"
    if command -v glow >/dev/null 2>&1; then
        glow "$md_file"
    elif command -v bat >/dev/null 2>&1; then
        bat --language=markdown --style=plain --paging=never "$md_file"
    elif "$PYTHON_WRAPPER" -c "import rich.markdown" >/dev/null 2>&1; then
        "$PYTHON_WRAPPER" -m rich.markdown "$md_file"
    else
        cat "$md_file"
    fi
    echo "================================================================"
}

# Prompt user for Markdown output mode (1=Screen [Default], 2=Export, 3=Both, 0=Cancel)
cyber_select_output_mode() {
    local __var_name="$1"
    if [[ -n "${CYBER_OUTPUT_MODE:-}" ]]; then
        printf -v "$__var_name" '%s' "$CYBER_OUTPUT_MODE"
        return 0
    fi

    if [[ ! -t 0 ]]; then
        printf -v "$__var_name" '%s' "1"
        return 0
    fi

    echo ""
    echo "Kies output-modus voor het Markdown-rapport:"
    echo "  1) Op scherm tonen (met duidelijke Markdown-weergave) [Default]"
    echo "  2) Exporteren als *.md bestand (toont na afloop het exacte bestandspad)"
    echo "  3) Beide (direct op scherm tonen én opslaan als *.md bestand)"
    echo "  0) Annuleren"
    local __choice=""
    read -rp "Keuze [1]: " __choice
    __choice="${__choice#"${__choice%%[![:space:]]*}"}"
    __choice="${__choice%"${__choice##*[![:space:]]}"}"
    [[ -z "$__choice" ]] && __choice="1"
    printf -v "$__var_name" '%s' "$__choice"
}

# Central output dispatcher for all CYBER report actions
# Usage: cyber_output_report <scored_json_file> <target_label> [format] [out_path]
cyber_output_report() {
    local scored_file="$1"
    local target_label="${2:-report}"
    local format="${3:-md}"
    local explicit_out="${4:-}"

    if [[ "$format" != "md" ]]; then
        if [[ -n "$explicit_out" ]]; then
            "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/reporting/reporter.py" --format "$format" --out "$explicit_out" < "$scored_file"
        else
            "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/reporting/reporter.py" --format "$format" < "$scored_file"
        fi
        return $?
    fi

    local mode=""
    cyber_select_output_mode mode
    case "$mode" in
        0|q|Q|cancel|CANCEL)
            echo "[Cancelled] Geen rapport gegenereerd."
            return 0
            ;;
        1|2|3) ;;
        *)
            echo "[warn] Ongeldige keuze '$mode'; terugval op modus 1 (Alleen scherm)." >&2
            mode="1"
            ;;
    esac

    local safe_target="${target_label//\//_}"
    safe_target="${safe_target//\\/_}"
    safe_target="${safe_target// /_}"
    local out_file="${explicit_out:-$PWD/report_${safe_target}.md}"

    case "$mode" in
        1)
            local tmp_md
            tmp_md="$(mktemp "${TMPDIR:-/tmp}/cyber_report.XXXXXX.md")"
            if ! "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/reporting/reporter.py" --format md --out "$tmp_md" < "$scored_file" >/dev/null; then
                rm -f "$tmp_md" 2>/dev/null || true
                return 1
            fi
            _cyber_render_markdown "$tmp_md"
            rm -f "$tmp_md" 2>/dev/null || true
            ;;
        2)
            if ! "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/reporting/reporter.py" --format md --out "$out_file" < "$scored_file"; then
                return 1
            fi
            local abs_out
            abs_out="$(cd "$(dirname "$out_file")" && pwd)/$(basename "$out_file")"
            echo "[OK] Markdown-rapport opgeslagen: $abs_out"
            ;;
        3)
            if ! "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/reporting/reporter.py" --format md --out "$out_file" < "$scored_file"; then
                return 1
            fi
            _cyber_render_markdown "$out_file"
            local abs_out
            abs_out="$(cd "$(dirname "$out_file")" && pwd)/$(basename "$out_file")"
            echo "[OK] Markdown-rapport opgeslagen: $abs_out"
            ;;
    esac
}

# 1. mailtrace: Roept mail_analyzer.py aan en toont de terminal TUI
mailtrace() {
    if [[ -z "${1:-}" ]]; then
        echo "Usage: mailtrace <path_to_eml_file>"
        return 1
    fi
    "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/mail/mail_analyzer.py" "$1"
}

# 1b. mailreport: Analyseert een .eml bestand en genereert een Markdown-rapport via cyber_output_report
mailreport() {
    local eml_file="${1:-}"
    if [[ -z "$eml_file" || ! -f "$eml_file" ]]; then
        echo "Usage: mailreport <path_to_eml_file>"
        return 1
    fi

    local tmp_mail tmp_scored
    tmp_mail="$(mktemp "${TMPDIR:-/tmp}/cyber_mail.XXXXXX")"
    tmp_scored="$(mktemp "${TMPDIR:-/tmp}/cyber_mail_scored.XXXXXX")"

    if ! "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/mail/mail_analyzer.py" "$eml_file" --json > "$tmp_mail"; then
        echo "[error] Mail analyzer is mislukt." >&2
        rm -f "$tmp_mail" "$tmp_scored" 2>/dev/null || true
        return 1
    fi

    if ! "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/scoring/risk_scorer.py" --target "$(basename "$eml_file")" < "$tmp_mail" > "$tmp_scored"; then
        echo "[error] Risk scorer is mislukt." >&2
        rm -f "$tmp_mail" "$tmp_scored" 2>/dev/null || true
        return 1
    fi

    cyber_output_report "$tmp_scored" "$(basename "$eml_file")" "md"
    local rc=$?
    rm -f "$tmp_mail" "$tmp_scored" 2>/dev/null || true
    return $rc
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

    # Stap 3: Rapportage via centrale output-dispatcher
    if ! cyber_output_report "$tmp_scored" "$target" "$format"; then
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

    local temp_file
    temp_file="$(mktemp)"
    cat > "$temp_file"

    "$PYTHON_WRAPPER" "$CYBER_MASTER_DIR/mail/mail_analyzer.py" "$temp_file" --json | \
    jq '{
        "Origin IP": .ioc.originating_ip,
        "SPF": .mail.auth.spf,
        "DKIM": .mail.auth.dkim,
        "Spoof Likelihood / Risk Score": .risk_score
    }'

    rm -f "$temp_file"
}

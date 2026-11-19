#!/usr/bin/env bash

RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

MAX_HOPS=30
WAIT_SEC=2
QUERIES=1
DO_RESOLVE=false
OUTPUT_JSON=false
TARGET=""

show_help() {
    cat <<EOF
Gebruik: $(basename "$0") [OPTIES] <domeinnaam of ip>

Opties:
  -m, --max-hops <N>   Maximaal aantal hops (standaard: 30)
  -w, --wait <sec>     Wachttijd per hop in seconden (standaard: 2)
  -q, --queries <N>    Aantal probes per hop (standaard: 1)
      --resolve        Reverse-DNS hostname tonen per hop
      --json           Output als JSON in plaats van tabel
  -h, --help           Toon deze hulptekst
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--max-hops)
            MAX_HOPS="${2:-30}"
            shift 2
            ;;
        -w|--wait)
            WAIT_SEC="${2:-2}"
            shift 2
            ;;
        -q|--queries)
            QUERIES="${2:-1}"
            shift 2
            ;;
        --resolve)
            DO_RESOLVE=true
            shift
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        -*)
            echo -e "${RED}Onbekende optie: $1${NC}" >&2
            show_help
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "Gebruik: $0 [OPTIES] <domeinnaam of ip>" >&2
    exit 1
fi

AUTHORITARIAN="RU CN KP IR SY BY MM CU AF"
SANCTIONED="IQ LY SD SO YE ZW BI CD ER VE"
PRIVACY="IN BR PK BD"

if [[ "$OUTPUT_JSON" == false ]]; then
    echo -e "${BOLD}Traceroute naar: $TARGET${NC}"
    echo "Max ${MAX_HOPS} hops | Wait: ${WAIT_SEC}s | Queries: ${QUERIES} | DNS resolve: ${DO_RESOLVE}"
fi

TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

HOPS=$(traceroute -n -q "$QUERIES" -w "$WAIT_SEC" -m "$MAX_HOPS" "$TARGET" 2>&1 \
    | grep -vE "^traceroute|Warning:|^$" \
    | awk '{print $1","$2}')

# Resolve eindbestemming
if command -v dig >/dev/null 2>&1; then
    TARGET_IP=$(dig +short A "$TARGET" 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
elif command -v host >/dev/null 2>&1; then
    TARGET_IP=$(host -4 "$TARGET" 2>/dev/null | awk '/has address/{print $4; exit}')
else
    TARGET_IP=""
fi
if [ -z "$TARGET_IP" ] && echo "$TARGET" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    TARGET_IP="$TARGET"
fi

# Forceer eindbestemming als laatste hop indien ontbrekend
if [ -n "$TARGET_IP" ]; then
    LAST_IP=$(echo "$HOPS" | tail -1 | cut -d',' -f2)
    if [ "$LAST_IP" != "$TARGET_IP" ]; then
        LAST_NUM=$(echo "$HOPS" | tail -1 | cut -d',' -f1)
        if [[ "$LAST_NUM" =~ ^[0-9]+$ ]]; then
            NEXT_NUM=$((10#$LAST_NUM + 1))
        else
            NEXT_NUM=1
        fi
        HOPS="${HOPS}
${NEXT_NUM},${TARGET_IP}"
    fi
fi

for line in $HOPS; do
    (
        HOP_NUM=$(echo "$line" | cut -d',' -f1)
        IP=$(echo "$line" | cut -d',' -f2)

        if [ -z "$IP" ] || ! [[ "$HOP_NUM" =~ ^[0-9]+$ ]]; then exit 0; fi

        if [ "$IP" = "*" ]; then
            printf "%02d|%s|%s|%s|%s|%s|%s|%s\n" \
                "$HOP_NUM" "*" "-" "Tijdlimiet" "-" "-" "-" "-" >> "$TEMP_FILE"
            exit 0
        fi

        HOST_NAME="-"
        if [[ "$DO_RESOLVE" == true ]]; then
            if command -v dig >/dev/null 2>&1; then
                HOST_NAME=$(dig +short -x "$IP" 2>/dev/null | head -1 | sed 's/\.$//')
            elif command -v host >/dev/null 2>&1; then
                HOST_NAME=$(host "$IP" 2>/dev/null | awk '/domain name pointer/{print $5; exit}' | sed 's/\.$//')
            fi
            [[ -z "$HOST_NAME" ]] && HOST_NAME="-"
        fi

        if echo "$IP" | grep -qE '^127\.|^10\.|^192\.168\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.'; then
            printf "%02d|%s|%s|%s|%s|%s|%s|%s\n" \
                "$HOP_NUM" "$IP" "Intern Netwerk" "-" "-" "-" "Privé router/gateway" "$HOST_NAME" >> "$TEMP_FILE"
        else
            DATA=$(curl -s --max-time 2 \
                "http://ip-api.com/csv/$IP?fields=status,continentCode,country,countryCode,isp,org,as")

            if [ $? -ne 0 ] || [ -z "$DATA" ]; then
                printf "%02d|%s|%s|%s|%s|%s|%s|%s\n" \
                    "$HOP_NUM" "$IP" "Onbekend" "API fout" "-" "-" "-" "$HOST_NAME" >> "$TEMP_FILE"
            else
                API_STATUS=$(echo "$DATA" | cut -d',' -f1)
                CONT=$(echo "$DATA"       | cut -d',' -f2)
                COUNTRY=$(echo "$DATA"    | cut -d',' -f3)
                CODE=$(echo "$DATA"       | cut -d',' -f4)
                ISP=$(echo "$DATA"        | cut -d',' -f5)
                ORG=$(echo "$DATA"        | cut -d',' -f6)
                AS=$(echo "$DATA"         | cut -d',' -f7)

                if [ "$API_STATUS" = "fail" ]; then
                    printf "%02d|%s|%s|%s|%s|%s|%s|%s\n" \
                        "$HOP_NUM" "$IP" "Onbekend" "Onbekend" "-" "-" "-" "$HOST_NAME" >> "$TEMP_FILE"
                    exit 0
                fi

                STATUS="OK"
                RISICO_TYPE="-"

                if echo " $AUTHORITARIAN " | grep -q " $CODE "; then
                    STATUS="!! RISICO !!"
                    RISICO_TYPE="Autoritair"
                elif echo " $SANCTIONED " | grep -q " $CODE "; then
                    STATUS="!! RISICO !!"
                    RISICO_TYPE="Sanctieland"
                elif echo " $PRIVACY " | grep -q " $CODE "; then
                    STATUS="LET OP"
                    RISICO_TYPE="Privacy-risico"
                elif [ "$CONT" != "EU" ]; then
                    STATUS="BUITEN-EU"
                fi

                ISP_LOWER=$(echo "$ISP $ORG" | tr '[:upper:]' '[:lower:]')
                if echo "$ISP_LOWER" | grep -qE 'hurricane|cogent|lumen|telia|zayo|ntt|level 3|level3|akamai|cloudflare|fastly|amazon|google|microsoft|meta|backbone|transit|peering|core|ix|ixp|exchange'; then
                    ROLE="Transit/Backbone"
                elif echo "$ISP_LOWER" | grep -qE 'telenet|proximus|voo|orange|belgacom|swisscom|kpn|deutsche telekom|bt |british telecom|comcast|at&t|verizon|charter|spectrum'; then
                    ROLE="ISP Netwerk"
                elif echo "$ISP_LOWER" | grep -qE 'federal|guard|gov|government|ministry|state|military|kreml|fsb|fso'; then
                    ROLE="Overheid/Staat"
                elif echo "$ISP_LOWER" | grep -qE 'hosting|datacenter|data center|colocation|colo|cloud|server|vps|dedicated'; then
                    ROLE="Hosting/DC"
                elif echo "$ISP_LOWER" | grep -qE 'university|universit|research|education|school|academic'; then
                    ROLE="Onderwijs"
                else
                    ROLE="$AS"
                fi

                printf "%02d|%s|%s|%s|%s|%s|%s|%s\n" \
                    "$HOP_NUM" "$IP" "$COUNTRY" \
                    "$STATUS" "$RISICO_TYPE" "$ISP" "$ROLE" "$HOST_NAME" >> "$TEMP_FILE"
            fi
        fi
    ) &
done

wait

if [[ "$OUTPUT_JSON" == true ]]; then
    echo "["
    first=true
    if [[ -s "$TEMP_FILE" ]]; then
        while IFS='|' read -r hop ip country status risico isp role host_name; do
            [[ "$first" == true ]] && first=false || echo ","
            printf '  {"hop": %d, "ip": "%s", "host": "%s", "country": "%s", "status": "%s", "risk": "%s", "isp": "%s", "role": "%s"}' \
                "$((10#$hop))" "${ip//\"/\\\"}" "${host_name//\"/\\\"}" "${country//\"/\\\"}" "${status//\"/\\\"}" "${risico//\"/\\\"}" "${isp//\"/\\\"}" "${role//\"/\\\"}"
        done < <(sort "$TEMP_FILE")
    fi
    echo ""
    echo "]"
    exit 0
fi

echo ""
if [[ "$DO_RESOLVE" == true ]]; then
    printf "${BOLD}%-4s %-16s %-26s %-16s %-13s %-15s %-24s %s${NC}\n" \
        "HOP" "IP-ADRES" "HOSTNAME" "LAND" "STATUS" "RISICO-TYPE" "PROVIDER" "ROL"
else
    printf "${BOLD}%-4s %-16s %-18s %-14s %-16s %-28s %s${NC}\n" \
        "HOP" "IP-ADRES" "LAND" "STATUS" "RISICO-TYPE" "PROVIDER" "ROL"
fi
echo "---------------------------------------------------------------------------------------------------------------"

if [ ! -s "$TEMP_FILE" ] || [ -z "$(tr -d '[:space:]' < "$TEMP_FILE")" ]; then
    echo "Geen actieve hops gevonden of doel onbereikbaar."
else
    sort "$TEMP_FILE" | while IFS='|' read -r hop ip country status risico isp role host_name; do
        status=$(echo "$status" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        risico=$(echo "$risico" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        role=$(echo "$role"     | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        COLOR=$(printf '\033[0m')
        RESET=$(printf '\033[0m')

        if [ "$risico" = "Autoritair" ]; then
            COLOR=$(printf '\033[0;31m')
        elif [ "$risico" = "Sanctieland" ]; then
            COLOR=$(printf '\033[0;35m')
        elif [ "$risico" = "Privacy-risico" ]; then
            COLOR=$(printf '\033[0;36m')
        elif [ "$status" = "BUITEN-EU" ]; then
            COLOR=$(printf '\033[1;33m')
        elif [ "$status" = "OK" ]; then
            COLOR=$(printf '\033[0;32m')
        fi

        if [[ "$DO_RESOLVE" == true ]]; then
            printf "%-4s %-16s %-26s %-16s ${COLOR}%-13s${RESET} %-15s %-24s %s\n" \
                "$hop" "$ip" "$host_name" "$country" "$status" "$risico" "$isp" "$role"
        else
            printf "%-4s %-16s %-18s ${COLOR}%-14s${RESET} %-16s %-28s %s\n" \
                "$hop" "$ip" "$country" "$status" "$risico" "$isp" "$role"
        fi
    done
fi

echo "---------------------------------------------------------------------------------------------------------------"
echo -e "${GREEN}EU/Veilig${NC}  ${YELLOW}Niet-EU${NC}  ${CYAN}Privacy-risico${NC}  ${PURPLE}Sanctieland${NC}  ${RED}Autoritair${NC}"

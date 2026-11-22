#!/usr/bin/env bash
set -euo pipefail

# Defaults
LOG_FILE="/var/log/nginx/access.log"
TOP_N=5
STATUS_FILTER=""

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

usage() {
    cat <<EOF >&2
Usage: $(basename "$0") [-f FILE] [-n N] [-s STATUS] [-h]

Analyse an Nginx combined access log and generate a traffic summary.

Options:
  -f FILE     Input log file (default: /var/log/nginx/access.log)
  -n N        Number of top results to display; positive integer (default: 5)
  -s STATUS   Only include requests matching this 3-digit HTTP status code
  -h          Show this help message and exit
EOF
}

parse_args() {
    while getopts ":f:n:s:h" opt; do
        case "$opt" in
            f)
                LOG_FILE="$OPTARG"
                ;;
            n)
                TOP_N="$OPTARG"
                ;;
            s)
                STATUS_FILTER="$OPTARG"
                ;;
            h)
                usage
                exit 0
                ;;
            :)
                log "Error: Option -${OPTARG} requires an argument."
                usage
                exit 2
                ;;
            \?)
                log "Error: Unknown option -${OPTARG}."
                usage
                exit 2
                ;;
        esac
    done

    shift $((OPTIND - 1))
    if [[ $# -gt 0 ]]; then
        log "Error: Unexpected positional arguments: $*"
        usage
        exit 2
    fi
}

validate_inputs() {
    if ! [[ "$TOP_N" =~ ^[1-9][0-9]*$ ]]; then
        log "Error: -n must be a positive integer (got '${TOP_N}')."
        usage
        exit 2
    fi

    if [[ -n "$STATUS_FILTER" ]] && ! [[ "$STATUS_FILTER" =~ ^[1-5][0-9]{2}$ ]]; then
        log "Error: -s must be a valid 3-digit HTTP status code (got '${STATUS_FILTER}')."
        usage
        exit 2
    fi

    if [[ ! -f "$LOG_FILE" ]] || [[ ! -r "$LOG_FILE" ]]; then
        log "Error: Input file '${LOG_FILE}' does not exist or is not readable."
        exit 1
    fi
}

# Extracts normalized "IP|URL|STATUS" records matching standard Nginx combined format:
# $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"
extract_filtered_records() {
    awk -v filter="$STATUS_FILTER" '
    {
        ip = $1

        # Extract the first quoted request string: "METHOD /path HTTP/1.1"
        req_start = index($0, "\"")
        if (req_start == 0) next
        rest = substr($0, req_start + 1)
        req_end = index(rest, "\"")
        if (req_end == 0) next

        request = substr(rest, 1, req_end - 1)
        split(request, req_parts, " ")
        url = (req_parts[2] != "") ? req_parts[2] : "-"

        # Status code is the first field immediately after the closing quote of $request
        after_req = substr(rest, req_end + 1)
        split(after_req, tail_parts, " ")
        status = tail_parts[1]

        if (status !~ /^[0-9]{3}$/) next
        if (filter != "" && status != filter) next

        print ip "\t" url "\t" status
    }' "$LOG_FILE"
}

print_report() {
    local parsed_data
    parsed_data="$(extract_filtered_records)"

    local total_requests
    if [[ -z "$parsed_data" ]]; then
        total_requests=0
    else
        total_requests="$(printf '%s\n' "$parsed_data" | wc -l | tr -d ' ')"
    fi

    printf '==================================================================\n'
    printf ' NGINX ACCESS LOG REPORT\n'
    printf ' File   : %s\n' "$LOG_FILE"
    if [[ -n "$STATUS_FILTER" ]]; then
        printf ' Filter : HTTP Status %s\n' "$STATUS_FILTER"
    else
        printf ' Filter : None (All Statuses)\n'
    fi
    printf '==================================================================\n'

    printf '\n--- 1. TOTAL REQUESTS ---\n'
    printf 'Total Requests: %s\n' "$total_requests"

    printf '\n--- 2. COUNTS BY HTTP STATUS CODE ---\n'
    if [[ "$total_requests" -eq 0 ]]; then
        printf 'No matching requests found.\n'
    else
        printf '%s\n' "$parsed_data" | awk -F'\t' '{counts[$3]++} END {for (s in counts) printf "Status %-5s : %d\n", s, counts[s]}' | sort -k2,2n
    fi

    printf '\n--- 3. TOP %s CLIENT IP ADDRESSES ---\n' "$TOP_N"
    if [[ "$total_requests" -eq 0 ]]; then
        printf 'No matching requests found.\n'
    else
        printf '%s\n' "$parsed_data" | awk -F'\t' '{counts[$1]++} END {for (ip in counts) printf "%d\t%s\n", counts[ip], ip}' | sort -k1,1nr -k2,2 | awk -F'\t' -v n="$TOP_N" 'NR<=n {printf "%-20s %d\n", $2, $1}'
    fi

    printf '\n--- 4. TOP %s REQUESTED URLs ---\n' "$TOP_N"
    if [[ "$total_requests" -eq 0 ]]; then
        printf 'No matching requests found.\n'
    else
        printf '%s\n' "$parsed_data" | awk -F'\t' '{counts[$2]++} END {for (u in counts) printf "%d\t%s\n", counts[u], u}' | sort -k1,1nr -k2,2 | awk -F'\t' -v n="$TOP_N" 'NR<=n {printf "%-40s %d\n", $2, $1}'
    fi

    printf '\n--- 5. 5xx SERVER ERROR RESPONSES ---\n'
    local count_5xx=0
    if [[ "$total_requests" -gt 0 ]]; then
        count_5xx="$(printf '%s\n' "$parsed_data" | awk -F'\t' '$3 ~ /^5[0-9]{2}$/ {c++} END {print c+0}')"
    fi
    printf 'Total 5xx Responses: %s\n' "$count_5xx"
    printf '\n==================================================================\n'
}

main() {
    parse_args "$@"
    validate_inputs
    log "Analysing log file: ${LOG_FILE}"
    print_report
    log "Analysis complete."
}

main "$@"

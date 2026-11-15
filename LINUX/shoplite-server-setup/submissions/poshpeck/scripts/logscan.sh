#!/usr/bin/env bash

set -euo pipefail

# Display usage information
usage() {
    cat <<'USAGE'
Usage: logscan.sh [-f FILE] [-n N] [-s STATUS] [-h]

Options:
  -f FILE    Nginx access log file (default: /var/log/nginx/access.log)
  -n N       Number of top results to display (default: 5)
  -s STATUS  Filter requests by HTTP status code
  -h         Display this help message
USAGE
}

# Timestamped logging function
log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# Default configuration
LOG_FILE="/var/log/nginx/access.log"
TOP_N=5
STATUS_FILTER=""

# Process command-line options
while getopts ":f:n:s:h" option; do
    case "$option" in
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
            echo "Error: Option -$OPTARG requires an argument." >&2
            usage
            exit 2
            ;;
        \?)
            echo "Error: Invalid option -$OPTARG." >&2
            usage
            exit 2
            ;;
    esac
done

# Validate the number of results
if ! [[ "$TOP_N" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: -n must be a positive integer." >&2
    usage
    exit 2
fi

# Validate the HTTP status filter
if [[ -n "$STATUS_FILTER" ]] && ! [[ "$STATUS_FILTER" =~ ^[1-5][0-9][0-9]$ ]]; then
    echo "Error: -s must be a valid three-digit HTTP status code (100-599)." >&2
    usage
    exit 2
fi

# Validate the input log file
if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: Log file does not exist: $LOG_FILE" >&2
    exit 1
fi

if [[ ! -r "$LOG_FILE" ]]; then
    echo "Error: Log file is not readable: $LOG_FILE" >&2
    exit 1
fi

# Display report header
log "=========================================="
log "SHOPLITE NGINX LOG ANALYSIS"
log "=========================================="
log "Log file: $LOG_FILE"
log "Top results limit: $TOP_N"

# Calculate total requests
TOTAL_REQUESTS="$(awk -v status="$STATUS_FILTER" '
{
    if (status == "" || $9 == status) {
        total++
    }
}
END {
    print total+0
}' "$LOG_FILE")"

log "Total requests: $TOTAL_REQUESTS"

# Calculate requests grouped by HTTP status
log ""
log "HTTP STATUS CODE BREAKDOWN"

awk -v status="$STATUS_FILTER" '
{
    if (status == "" || $9 == status) {
        counts[$9]++
    }
}
END {
    for (code in counts) {
        printf "HTTP %s: %d requests\n", code, counts[code]
    }
}' "$LOG_FILE" | sort

# Calculate 5xx server errors
log ""
log "5XX SERVER ERRORS"

SERVER_ERRORS="$(awk -v status="$STATUS_FILTER" '
{
    if ((status == "" || $9 == status) && $9 ~ /^5[0-9][0-9]$/) {
        errors++
    }
}
END {
    print errors+0
}' "$LOG_FILE")"

log "Total 5xx errors: $SERVER_ERRORS"

# Identify top client IP addresses
log ""
log "TOP $TOP_N CLIENT IP ADDRESSES"

awk -v status="$STATUS_FILTER" '
{
    if (status == "" || $9 == status) {
        ips[$1]++
    }
}
END {
    for (ip in ips) {
        printf "%s %d\n", ip, ips[ip]
    }
}' "$LOG_FILE" |
sort -k2,2nr |
awk -v limit="$TOP_N" 'NR <= limit' |
awk '{printf "IP: %-18s Requests: %d\n", $1, $2}'

# Identify top requested URLs
log ""
log "TOP $TOP_N REQUESTED URLS"

awk -v status="$STATUS_FILTER" '
{
    if (status == "" || $9 == status) {
        urls[$7]++
    }
}
END {
    for (url in urls) {
        printf "%s %d\n", url, urls[url]
    }
}' "$LOG_FILE" |
sort -k2,2nr |
awk -v limit="$TOP_N" 'NR <= limit' |
awk '{printf "URL: %-30s Requests: %d\n", $1, $2}'

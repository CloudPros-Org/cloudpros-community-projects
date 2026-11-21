#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: logscan.sh [-f FILE] [-n N] [-s STATUS] [-h]

Options:
  -f FILE    Nginx access log (default: /var/log/nginx/access.log)
  -n N       Number of top IPs and URLs (default: 5)
  -s STATUS  Include only the specified HTTP status (100-599)
  -h         Display this help and exit

Examples:
  logscan.sh
  logscan.sh -n 3
  logscan.sh -f /tmp/access.log -s 404
USAGE
}

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

error() {
    log "ERROR: $*" >&2
}

tmp_file=""

cleanup() {
    if [[ -n "${tmp_file:-}" ]]; then
        rm -f -- "$tmp_file"
    fi
}

trap cleanup EXIT

main() {
    local log_file="/var/log/nginx/access.log"
    local top_n=5
    local status_filter=""
    local option

    while getopts ":f:n:s:h" option; do
        case "$option" in
            f) log_file="$OPTARG" ;;
            n) top_n="$OPTARG" ;;
            s) status_filter="$OPTARG" ;;
            h) usage; return 0 ;;
            :) error "Option -$OPTARG requires an argument."
               usage >&2
               return 2 ;;
            \?) error "Unknown option: -$OPTARG"
                usage >&2
                return 2 ;;
        esac
    done

    shift "$((OPTIND - 1))"

    if [[ $# -ne 0 ]]; then
        error "Unexpected argument: $1"
        usage >&2
        return 2
    fi

    if [[ ! "$top_n" =~ ^[1-9][0-9]*$ ]]; then
        error "-n must be a positive integer."
        usage >&2
        return 2
    fi

    if [[ -n "$status_filter" &&
          ! "$status_filter" =~ ^[1-5][0-9][0-9]$ ]]; then
        error "-s must be an HTTP status code from 100 to 599."
        usage >&2
        return 2
    fi

    if [[ ! -f "$log_file" || ! -r "$log_file" ]]; then
        error "Input file is missing or unreadable: $log_file"
        return 1
    fi

    analyse_log "$log_file" "$top_n" "$status_filter"
}

analyse_log() {
    local log_file="$1"
    local top_n="$2"
    local status_filter="$3"
    local total_requests five_xx_count
    

tmp_file="$(mktemp)"    

    awk -v filter_status="$status_filter" '
    {
        ip = $1
        status = $9

        # Standard Nginx combined format has the status in field 9.
        if (status !~ /^[1-5][0-9][0-9]$/) {
            next
        }

        if (filter_status != "" && status != filter_status) {
            next
        }

        url = "-"
        if (match($0, /"[^"]*"/)) {
            request_line = substr($0, RSTART + 1, RLENGTH - 2)
            parts_count = split(request_line, parts, /[[:space:]]+/)
            if (parts_count >= 2 && parts[2] != "") {
                url = parts[2]
            }
        }

        print ip "\t" status "\t" url
    }
    ' "$log_file" > "$tmp_file"

    total_requests="$(awk 'END { print NR + 0 }' "$tmp_file")"
    five_xx_count="$(awk -F '\t' '$2 ~ /^5[0-9][0-9]$/ { n++ }
        END { print n + 0 }' "$tmp_file")"

    printf '\n========== SHOPLITE NGINX LOG ANALYSIS ==========\n'
    log "Input file: $log_file"
    if [[ -n "$status_filter" ]]; then
        log "Status filter: $status_filter"
    else
        log "Status filter: none"
    fi

    printf '\nTotal requests: %s\n' "$total_requests"

    printf '\n========== COUNTS BY HTTP STATUS ==========\n'
    if [[ "$total_requests" -eq 0 ]]; then
        printf 'No matching requests found.\n'
    else
        awk -F '\t' '{ count[$2]++ }
            END {
                for (status in count) {
                    printf "%s %d\n", status, count[status]
                }
            }' "$tmp_file" | sort -n
    fi

    printf '\n========== TOP %s CLIENT IP ADDRESSES ==========\n' "$top_n"
    if [[ "$total_requests" -eq 0 ]]; then
        printf 'No matching client IPs found.\n'
    else
        cut -f1 "$tmp_file" | sort | uniq -c |
            sort -nr | sed -n "1,${top_n}p"
    fi

    printf '\n========== TOP %s REQUESTED URLS ==========\n' "$top_n"
    if [[ "$total_requests" -eq 0 ]]; then
        printf 'No matching URLs found.\n'
    else
        cut -f3 "$tmp_file" | sort | uniq -c |
            sort -nr | sed -n "1,${top_n}p"
    fi

    printf '\n5xx responses: %s\n' "$five_xx_count"
    log "Log analysis completed"
}

main "$@"

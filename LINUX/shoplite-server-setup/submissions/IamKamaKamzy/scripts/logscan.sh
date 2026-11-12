#!/usr/bin/env bash
set -euo pipefail

input_file="/var/log/nginx/access.log"
top_n=5
status_filter=""
stats_file=""

usage() {
  cat <<EOF
Usage: ${0##*/} [-f FILE] [-n N] [-s STATUS] [-h]
  -f FILE    Nginx combined access log (default: /var/log/nginx/access.log)
  -n N       Number of top IPs and URLs to show (default: 5)
  -s STATUS  Include only this HTTP status code (100-599)
  -h         Show this help
EOF
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

is_positive_integer() {
  [[ $1 =~ ^[0-9]*[1-9][0-9]*$ ]]
}

is_http_status() {
  [[ $1 =~ ^[1-5][0-9][0-9]$ ]]
}

cleanup() {
  if [[ -n "$stats_file" ]]; then
    rm -f -- "$stats_file"
  fi
}

print_top_results() {
  local heading=$1
  local record_type=$2
  local results

  printf '\n== %s (top %s) ==\n' "$heading" "$top_n"
  results=$(awk -F '\t' -v type="$record_type" \
    '$1 == type { print $2 "\t" $3 }' "$stats_file" |
    sort -t $'\t' -k1,1nr -k2,2 |
    awk -F '\t' -v limit="$top_n" '
      NR <= limit {
        printf "  %s: %s\n", $2, $1
        found = 1
      }
      END {
        if (!found) {
          print "  No matching requests."
        }
      }
    ')
  printf '%s\n' "$results"
}

analyze_log() {
  awk -v filter="$status_filter" '
    {
      if (NF < 9 || $1 == "" || $9 !~ /^[1-5][0-9][0-9]$/) {
        next
      }

      status = $9
      if (filter != "" && status != filter) {
        next
      }

      request = $0
      sub(/^[^"]*"/, "", request)
      sub(/".*$/, "", request)
      request_fields = split(request, parts, /[[:space:]]+/)
      if (request_fields < 2 || parts[2] == "") {
        next
      }

      total++
      status_counts[status]++
      ip_counts[$1]++
      url_counts[parts[2]]++
      if (status >= 500 && status <= 599) {
        server_errors++
      }
    }
    END {
      printf "TOTAL\t%d\t-\n", total
      printf "SERVER5XX\t%d\t-\n", server_errors
      for (status in status_counts) {
        printf "STATUS\t%d\t%s\n", status_counts[status], status
      }
      for (ip in ip_counts) {
        printf "IP\t%d\t%s\n", ip_counts[ip], ip
      }
      for (url in url_counts) {
        printf "URL\t%d\t%s\n", url_counts[url], url
      }
    }
  ' < "$input_file" > "$stats_file"
}

main() {
  local option

  while getopts ':f:n:s:h' option; do
    case "$option" in
      f)
        input_file=$OPTARG
        ;;
      n)
        if ! is_positive_integer "$OPTARG"; then
          log "ERROR: -n must be a positive integer."
          usage >&2
          return 2
        fi
        top_n=$OPTARG
        ;;
      s)
        if ! is_http_status "$OPTARG"; then
          log "ERROR: -s must be an HTTP status code from 100 to 599."
          usage >&2
          return 2
        fi
        status_filter=$OPTARG
        ;;
      h)
        usage
        return 0
        ;;
      :)
        log "ERROR: -$OPTARG requires an argument."
        usage >&2
        return 2
        ;;
      \?)
        log "ERROR: unknown option -$OPTARG."
        usage >&2
        return 2
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  if (($# > 0)); then
    log "ERROR: unexpected positional argument: $1"
    usage >&2
    return 2
  fi

  if [[ ! -f "$input_file" || ! -r "$input_file" ]]; then
    log "ERROR: input log is missing or unreadable: $input_file"
    return 1
  fi

  log "Analyzing $input_file"
  stats_file=$(mktemp)
  analyze_log

  local total_requests
  local server_errors
  local status_rows
  total_requests=$(awk -F '\t' '$1 == "TOTAL" { print $2; exit }' "$stats_file")
  server_errors=$(awk -F '\t' '$1 == "SERVER5XX" { print $2; exit }' "$stats_file")

  printf 'Total requests: %s\n' "$total_requests"
  if [[ -n "$status_filter" ]]; then
    printf 'Status filter: %s\n' "$status_filter"
  fi

  printf '\n== Requests by HTTP status ==\n'
  status_rows=$(awk -F '\t' '$1 == "STATUS" { print $2 "\t" $3 }' "$stats_file" |
    sort -t $'\t' -k2,2n)
  if [[ -n "$status_rows" ]]; then
    printf '%s\n' "$status_rows" |
      awk -F '\t' '{ printf "  %s: %s\n", $2, $1 }'
  else
    printf '  No matching requests.\n'
  fi

  print_top_results "Client IP addresses" "IP"
  print_top_results "Requested URLs" "URL"

  printf '\n5xx responses: %s\n' "$server_errors"
}

trap cleanup EXIT
main "$@"

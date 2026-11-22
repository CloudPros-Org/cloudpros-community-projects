#!/usr/bin/env bash
set -euo pipefail

readonly LOG_DIR="/var/log/shoplite"
readonly AUTH_LOG_DIR="${AUTH_LOG_DIR:-/var/log}"
readonly JOURNALCTL_BIN="${JOURNALCTL_BIN:-journalctl}"
readonly SYSTEMCTL_BIN="${SYSTEMCTL_BIN:-systemctl}"

usage() {
  printf 'Usage: %s (this script takes no options)\n' "${0##*/}" >&2
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*"
}

report_memory() {
  awk '
    /^MemTotal:/ { total = $2; have_total = 1 }
    /^MemAvailable:/ { available = $2; have_available = 1 }
    END {
      if (have_total && have_available && total > 0) {
        printf "Memory used: %.1f%% (%d of %d MiB)\n",
          ((total - available) / total) * 100, (total - available) / 1024, total / 1024
      } else {
        print "Memory usage data is unavailable."
      }
    }
  ' /proc/meminfo
}

report_filesystems() {
  df -P -x tmpfs -x devtmpfs -x squashfs |
    awk '
      NR == 1 { next }
      {
        usage = $5
        sub(/%$/, "", usage)
        if (usage + 0 > 80) {
          print
          found = 1
        }
      }
      END {
        if (!found) {
          print "No filesystem is above 80% usage."
        }
      }
    '
}

report_failed_units() {
  if ! command -v systemctl >/dev/null 2>&1; then
    printf 'systemctl is unavailable; failed units cannot be checked.\n'
    return
  fi

  local failed_units
  failed_units=$(systemctl --failed --no-legend --no-pager)
  if [[ -n "$failed_units" ]]; then
    printf '%s\n' "$failed_units"
  else
    printf 'No failed systemd units.\n'
  fi
}

report_ssh_failures() {
  local failures
  local now
  local auth_files=()
  local file

  if [[ -r "${AUTH_LOG_DIR}/auth.log" ]]; then
    auth_files+=("${AUTH_LOG_DIR}/auth.log")
  fi

  shopt -s nullglob
  for file in "${AUTH_LOG_DIR}"/auth.log.[0-9]*; do
    if [[ "$file" == *.gz ]]; then
      if [[ -r "$file" ]] && command -v gzip >/dev/null 2>&1; then
        auth_files+=("$file")
      fi
    elif [[ -r "$file" ]]; then
      auth_files+=("$file")
    fi
  done
  shopt -u nullglob

  if ((${#auth_files[@]} > 0)); then
    now=$(date '+%s')
    failures=$(
      for file in "${auth_files[@]}"; do
        if [[ "$file" == *.gz ]]; then
          gzip -cd -- "$file" 2>/dev/null
        else
          cat -- "$file"
        fi
      done |
        awk -v now="$now" '
          BEGIN {
            split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", names, " ")
            for (i = 1; i <= 12; i++) {
              months[names[i]] = i
            }
            current_year = strftime("%Y", now)
          }
          {
            message = tolower($0)
            if (message !~ /sshd(\[[0-9]+\])?:/) {
              next
            }
            if (message !~ /(failed password|invalid user|authentication failure|failed publickey|maximum authentication attempts exceeded)/) {
              next
            }

            month = months[$1]
            if (!month || $2 !~ /^[0-9]+$/) {
              next
            }
            if (split($3, clock, ":") != 3) {
              next
            }

            timestamp = mktime(sprintf("%d %d %d %d %d %d",
              current_year, month, $2, clock[1], clock[2], clock[3]))
            if (timestamp > now) {
              timestamp = mktime(sprintf("%d %d %d %d %d %d",
                current_year - 1, month, $2, clock[1], clock[2], clock[3]))
            }

            if (timestamp >= now - 86400 && timestamp <= now && !seen[$0]++) {
              print
            }
          }
        '
    )

    if [[ -n "$failures" ]]; then
      printf '%s\n' "$failures"
    else
      printf 'No failed SSH login records found in available authentication logs in the last 24 hours.\n'
    fi
    return
  fi

  if ! command -v "$JOURNALCTL_BIN" >/dev/null 2>&1 ||
    ! command -v "$SYSTEMCTL_BIN" >/dev/null 2>&1; then
    printf 'SSH authentication logs and journal data are unavailable.\n'
    return
  fi

  local ssh_units
  ssh_units=$("$SYSTEMCTL_BIN" list-unit-files --type=service --no-legend --no-pager 2>/dev/null |
    awk '$1 == "ssh.service" || $1 == "sshd.service" { print $1 }') || ssh_units=""

  local ssh_logs
  if ! ssh_logs=$("$JOURNALCTL_BIN" --quiet --since '24 hours ago' --no-pager \
    -u ssh.service -u sshd.service 2>&1); then
    printf 'Unable to read SSH journal data: %s\n' "$ssh_logs"
    return
  fi

  if [[ -z "$ssh_logs" ]]; then
    if [[ -z "$ssh_units" ]]; then
      printf 'No SSH service or SSH journal data is present.\n'
    else
      printf 'No SSH journal records are available for the last 24 hours.\n'
    fi
    return
  fi

  failures=$(printf '%s\n' "$ssh_logs" |
    grep -Ei 'sshd(\[[0-9]+\])?:.*(Failed password|Invalid user|authentication failure|Failed publickey|maximum authentication attempts exceeded)' || true)
  if [[ -n "$failures" ]]; then
    printf '%s\n' "$failures"
  else
    printf 'No failed SSH logins found in available journal records (last 24 hours).\n'
  fi
}

generate_report() {
  log "ShopLite system report"

  printf '\n== Hostname and uptime ==\n'
  log "Collecting hostname and uptime"
  printf 'Hostname: %s\n' "$(hostname)"
  printf 'Uptime: %s\n' "$(uptime --pretty)"

  printf '\n== Load average ==\n'
  log "Collecting load average"
  awk '{ printf "1 minute: %s, 5 minutes: %s, 15 minutes: %s\n", $1, $2, $3 }' /proc/loadavg

  printf '\n== Memory usage ==\n'
  log "Collecting memory usage"
  report_memory

  printf '\n== Filesystems above 80%% usage ==\n'
  log "Checking filesystem usage"
  report_filesystems

  printf '\n== Top five processes by memory ==\n'
  log "Collecting top memory-consuming processes"
  ps -eo pid,comm,%mem --sort=-%mem | awk 'NR <= 6'

  printf '\n== Failed systemd units ==\n'
  log "Checking failed systemd units"
  report_failed_units

  printf '\n== Failed SSH logins in the last 24 hours ==\n'
  log "Checking SSH authentication records"
  report_ssh_failures
}

main() {
  if (($# > 0)); then
    usage
    return 2
  fi

  umask 027
  mkdir -p "$LOG_DIR"

  local report_file
  report_file="$LOG_DIR/sysreport-$(date '+%Y-%m-%d_%H-%M-%S').log"
  generate_report | tee -- "$report_file"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

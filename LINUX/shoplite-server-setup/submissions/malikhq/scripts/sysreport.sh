#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

usage() {
    printf 'Usage: sysreport.sh\n' >&2
    printf 'Generates a timestamped system report in /var/log/shoplite/.\n' >&2
}

main() {
    if [[ $# -ne 0 ]]; then
        usage
        exit 2
    fi

    if [[ $EUID -ne 0 ]]; then
        printf 'Run with sudo: sudo /usr/local/sbin/sysreport.sh\n' >&2
        exit 1
    fi

    local report_file
    report_file="/var/log/shoplite/sysreport-$(date '+%Y%m%d_%H%M%S').log"

    umask 027
    install -d -o root -g shopops -m 0750 /var/log/shoplite
    touch "$report_file"
    chown root:shopops "$report_file"
    chmod 0640 "$report_file"

    exec > >(tee "$report_file") 2>&1

    log "ShopLite system report started"
    printf 'Report file: %s\n' "$report_file"

    printf '\n========== HOSTNAME AND UPTIME ==========\n'
    printf 'Hostname: '
    hostname
    printf 'Uptime: '
    uptime -p

    printf '\n========== LOAD AVERAGE ==========\n'
    awk '{
        printf "1 minute: %s\n5 minutes: %s\n15 minutes: %s\n",
        $1, $2, $3
    }' /proc/loadavg

    printf '\n========== MEMORY USAGE ==========\n'
    free -h
    awk '/^Mem:/ {
        if ($2 > 0) {
            printf "Memory used: %.1f%%\n", ($3 / $2) * 100
        } else {
            print "Memory usage percentage unavailable."
        }
    }' < <(free)

    printf '\n========== FILESYSTEMS OVER 80%% ==========\n'
    df -P -x tmpfs -x devtmpfs |
        awk '
        NR > 1 {
            usage = $5
            gsub(/%/, "", usage)
            if (usage + 0 > 80) {
                print
                found = 1
            }
        }
        END {
            if (!found) {
                print "No filesystems exceed 80% usage."
            }
        }'

    printf '\n========== TOP FIVE PROCESSES BY MEMORY ==========\n'
    ps -eo pid,comm,%mem,rss --sort=-%mem | sed -n '1,6p'

    printf '\n========== FAILED SYSTEMD UNITS ==========\n'
    local failed_units
    failed_units="$(systemctl --failed --no-legend --plain 2>/dev/null || true)"
    if [[ -n "$failed_units" ]]; then
        printf '%s\n' "$failed_units"
    else
        printf 'No failed systemd units reported, or systemd data is unavailable.\n'
    fi

    printf '\n========== FAILED SSH LOGINS: LAST 24 HOURS ==========\n'
    local journal_data ssh_related ssh_failures
    journal_data="$(journalctl --since '24 hours ago' --no-pager -o short-iso 2>/dev/null || true)"
    ssh_related="$(printf '%s\n' "$journal_data" | grep -Ei 'sshd|ssh' || true)"
    ssh_failures="$(printf '%s\n' "$ssh_related" |
        grep -Ei 'Failed password|Invalid user|authentication failure|Failed publickey|maximum authentication attempts' || true)"

    if [[ -n "$ssh_failures" ]]; then
        printf '%s\n' "$ssh_failures"
    elif [[ -n "$ssh_related" ]]; then
        printf 'No failed SSH logins found in the available SSH journal entries.\n'
    else
        printf 'No SSH-related journal entries found in the last 24 hours.\n'
        printf 'SSH may be inactive or authentication logs may be unavailable.\n'
    fi

    log "ShopLite system report completed"
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

# Configuration
LOG_DIR="/var/log/shoplite"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/sysreport-${TIMESTAMP}.log"
DISK_THRESHOLD=80

usage() {
    echo "Usage: $(basename "$0")" >&2
    echo "  Prints a system health report and saves a copy to ${LOG_DIR}/." >&2
    echo "  This script takes no options." >&2
}

# Timestamped message: [YYYY-MM-DD HH:MM:SS] text
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Any argument is an unknown option: usage on stderr, exit 2
parse_args() {
    if [[ $# -gt 0 ]]; then
        log "ERROR: unknown option '$1'" >&2
        usage
        exit 2
    fi
}

# The report is saved to LOG_DIR, so it must exist and be writable
ensure_log_dir() {
    if ! mkdir -p "$LOG_DIR" 2>/dev/null || [[ ! -w "$LOG_DIR" ]]; then
        log "ERROR: cannot write to $LOG_DIR. Please run with sudo or as root." >&2
        exit 1
    fi
}

section_title() {
    printf '\n--- %s ---\n' "$1"
}

print_header() {
    echo "=================================================================="
    echo " SYSTEM HEALTH REPORT - $(date)"
    echo "=================================================================="
}

report_host() {
    section_title "1. HOSTNAME & UPTIME"
    echo "Hostname : $(hostname -f 2>/dev/null || hostname)"
    echo "Uptime   : $(uptime -p 2>/dev/null || uptime)"
}

report_load() {
    section_title "2. LOAD AVERAGE"
    awk '{print "1 min: " $1 " | 5 min: " $2 " | 15 min: " $3}' /proc/loadavg
}

report_memory() {
    section_title "3. MEMORY USAGE"
    free -m | awk '
    NR==2 {
        pct = ($3 / $2) * 100
        printf "Used: %d MB / Total: %d MB (%.2f%%)\n", $3, $2, pct
    }'
}

report_disk() {
    section_title "4. FILESYSTEMS OVER ${DISK_THRESHOLD}% USAGE"
    local over
    over=$(df -hP -x tmpfs -x devtmpfs -x squashfs | awk -v limit="$DISK_THRESHOLD" '
    NR>1 {
        use = $5
        sub(/%/, "", use)
        if (use + 0 > limit) {
            printf "%-25s %-8s %-8s %-8s %-6s %s\n", $1, $2, $3, $4, $5, $6
        }
    }')

    if [[ -n "$over" ]]; then
        printf "%-25s %-8s %-8s %-8s %-6s %s\n" "Filesystem" "Size" "Used" "Avail" "Use%" "Mounted on"
        echo "$over"
    else
        echo "OK: No filesystems are currently over ${DISK_THRESHOLD}% usage."
    fi
}

report_top_processes() {
    section_title "5. TOP 5 PROCESSES BY MEMORY USAGE"
    # sed reads all input, so pipefail never sees a closed pipe (unlike head)
    ps -eo pid,user,%mem,%cpu,comm --sort=-%mem | sed -n '1,6p'
}

report_failed_units() {
    section_title "6. FAILED SYSTEMD UNITS"
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "Notice: systemctl is not available on this system."
        return 0
    fi

    local failed
    failed=$(systemctl --failed --no-legend --plain)
    if [[ -n "$failed" ]]; then
        echo "$failed"
    else
        echo "OK: No failed systemd units found."
    fi
}

# True if an SSH server is installed (small output, so no pipefail/SIGPIPE risk)
ssh_present() {
    command -v sshd >/dev/null 2>&1 && return 0
    systemctl list-unit-files ssh.service sshd.service 2>/dev/null | grep -qE '^ssh(d)?\.service'
}

report_ssh_failures() {
    section_title "7. FAILED SSH LOGINS (LAST 24 HOURS)"
    local pattern="Failed password|Invalid user|authentication failure"
    local failed auth_log

    if ! ssh_present; then
        echo "Notice: No SSH service (ssh/sshd) detected on this system."
    elif command -v journalctl >/dev/null 2>&1 && journalctl -u ssh -u sshd --since "24 hours ago" >/dev/null 2>&1; then
        failed=$(journalctl -u ssh -u sshd --since "24 hours ago" --no-pager 2>/dev/null | grep -iE "$pattern" || true)
        if [[ -n "$failed" ]]; then
            echo "$failed"
        else
            echo "OK: No failed SSH login attempts recorded in the systemd journal over the last 24 hours."
        fi
    elif [[ -r /var/log/auth.log ]] || [[ -r /var/log/secure ]]; then
        auth_log="/var/log/auth.log"
        if [[ -r /var/log/secure ]]; then
            auth_log="/var/log/secure"
        fi

        echo "Using fallback log file: $auth_log (Note: traditional syslog timestamps may lack year data; filtering by recent entries)"
        failed=$(grep -iE "sshd.*($pattern)" "$auth_log" | tail -n 20 || true)
        if [[ -n "$failed" ]]; then
            echo "$failed"
        else
            echo "OK: No failed SSH login attempts found in $auth_log."
        fi
    else
        echo "Notice: SSH service is present, but no readable journal or authentication log (/var/log/auth.log or /var/log/secure) was found."
    fi
}

print_footer() {
    printf '\n'
    echo "=================================================================="
    log "Report saved to: $LOG_FILE"
    echo "=================================================================="
}

build_report() {
    print_header
    report_host
    report_load
    report_memory
    report_disk
    report_top_processes
    report_failed_units
    report_ssh_failures
    print_footer
}

main() {
    parse_args "$@"
    ensure_log_dir
    # tee gives the dual output: screen and log file
    build_report | tee "$LOG_FILE"
}
               
main "$@"

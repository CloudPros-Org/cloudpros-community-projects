#!/usr/bin/env bash

set -euo pipefail

# Display usage information
usage() {
    echo "Usage: sysreport.sh" >&2
}

# Reject unsupported command-line arguments
if (( $# > 0 )); then
    usage
    exit 2
fi

# Report directory
REPORT_DIR="/var/log/shoplite"

# Create the report directory if it does not exist
mkdir -p "$REPORT_DIR"

# Restrict permissions on newly created files
umask 027

# Generate a timestamp for the report filename
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Build the complete report filename
REPORT_FILE="${REPORT_DIR}/sysreport-${TIMESTAMP}.log"

# Timestamped logging function
log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# Display output in the terminal and save it to the report file
exec > >(tee "$REPORT_FILE") 2>&1

# Report header
log "=========================================="
log "SHOPLITE SYSTEM REPORT"
log "=========================================="
log "Report saved to: $REPORT_FILE"

# Hostname and uptime
log ""
log "SYSTEM INFORMATION"
log "Hostname: $(hostname)"
log "Uptime: $(uptime -p)"

# System load average
log ""
log "SYSTEM LOAD AVERAGE"
log "Load average (1, 5, 15 minutes): $(awk '{print $1, $2, $3}' /proc/loadavg)"

# Memory usage
log ""
log "MEMORY USAGE"

MEMORY_USAGE="$(free | awk '/^Mem:/ {printf "%.1f", ($3/$2)*100}')"

log "Memory usage: ${MEMORY_USAGE}%"

# Filesystem usage
log ""
log "FILESYSTEMS ABOVE 80% USAGE"

df -P -x tmpfs -x devtmpfs | awk '
NR == 1 {
    print
    next
}
{
    usage = $5
    gsub(/%/, "", usage)

    if (usage > 80) {
        print
        found = 1
    }
}
END {
    if (!found) {
        print "No filesystems above 80% usage."
    }
}'

# Top 5 memory-consuming processes
log ""
log "TOP 5 MEMORY-CONSUMING PROCESSES"

ps -eo pid,comm,%mem,%cpu --sort=-%mem | awk 'NR <= 6'

# Failed systemd units
log ""
log "FAILED SYSTEMD UNITS"

FAILED_UNITS="$(systemctl --failed --no-legend --plain)"

if [[ -n "$FAILED_UNITS" ]]; then
    printf '%s\n' "$FAILED_UNITS"
else
    log "No failed systemd units."
fi


# SSH authentication activity in the last 24 hours
log ""
log "SSH AUTHENTICATION ACTIVITY IN THE LAST 24 HOURS"

if ! command -v journalctl >/dev/null 2>&1; then
    log "SSH login reporting unavailable: journalctl is not installed."

elif SSH_JOURNAL="$(journalctl --since "24 hours ago" --no-pager 2>&1)"; then

    SSH_AUTH_EVENTS="$(
        printf '%s\n' "$SSH_JOURNAL" |
        grep -Ei 'sshd\[[0-9]+\]:.*(Accepted [^ ]+|Failed password|Invalid user|authentication failure)|pam_unix\(sshd:[^)]+\): authentication failure' || true
    )"

    if [[ -z "$SSH_AUTH_EVENTS" ]]; then
        log "SSH authentication status unknown: no SSH authentication events were found in the system journal during the last 24 hours."

    else
        SSH_FAILURES="$(
            printf '%s\n' "$SSH_AUTH_EVENTS" |
            grep -Ei 'Failed password|Invalid user|authentication failure' || true
        )"

        if [[ -n "$SSH_FAILURES" ]]; then
            log "Failed SSH authentication attempts found:"
            printf '%s\n' "$SSH_FAILURES"
        else
            log "No failed SSH login attempts found in the available authentication records during the last 24 hours."
        fi
    fi

else
    log "SSH login reporting unavailable: unable to access the system journal."
    printf '%s\n' "$SSH_JOURNAL"
fi

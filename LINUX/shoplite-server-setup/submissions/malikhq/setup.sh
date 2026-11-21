#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

if [[ $EUID -ne 0 ]]; then
    printf 'Run with sudo: sudo bash ./setup.sh\n' >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

for script in sysreport.sh logscan.sh; do
    if [[ ! -f "$SCRIPTS_DIR/$script" ]]; then
        printf 'Missing required script: %s\n' "$SCRIPTS_DIR/$script" >&2
        exit 1
    fi
done

log "Updating package lists"
apt-get update

log "Installing required packages"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    acl cron logrotate nginx shellcheck

log "Enabling services"
systemctl enable --now nginx
systemctl enable --now cron

log "Creating shopops group"
if ! getent group shopops >/dev/null; then
    groupadd shopops
fi

for username in ava tom; do
    if ! id "$username" >/dev/null 2>&1; then
        log "Creating user: $username"
        useradd --create-home --shell /bin/bash "$username"
    fi

    log "Adding $username to shopops"
    usermod -aG shopops "$username"
done

log "Configuring shared directory"
install -d -o root -g shopops -m 2770 /srv/shoplite
setfacl -m u::rwx,g::rwx,m::rwx,o::--- /srv/shoplite
setfacl -d -m u::rwx,g::rwx,m::rwx,o::--- /srv/shoplite

log "Preparing report directory"
install -d -o root -g shopops -m 0750 /var/log/shoplite

log "Installing scripts"
install -o root -g root -m 0755 \
    "$SCRIPTS_DIR/sysreport.sh" /usr/local/sbin/sysreport.sh
install -o root -g root -m 0755 \
    "$SCRIPTS_DIR/logscan.sh" /usr/local/sbin/logscan.sh

log "Installing logrotate configuration"
install -o root -g root -m 0644 \
    "$SCRIPT_DIR/logrotate/shoplite" /etc/logrotate.d/shoplite

log "Installing root cron jobs"
install -o root -g root -m 0644 \
    "$SCRIPT_DIR/cron/shoplite.cron" /etc/cron.d/shoplite

log "ShopLite setup completed"
log "Open a new login session before testing group membership"

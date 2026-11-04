#!/bin/bash

# ==============================================================================
# CLOUDPROS AUTOMATED DEPLOYMENT & CONFIGURATION SCRIPT (Ubuntu 24.04)
# Idempotent Execution Profile
# ==============================================================================

set -euo pipefail

# --- Configuration Variables ---
APP_USER="appuser"
APP_DIR="/opt/cloudpros"
BACKUP_DIR="/var/backups/cloudpros"
LOG_DIR="/var/log/cloudpros"
HEALTH_SCRIPT="/usr/local/bin/healthcheck.sh"
BACKUP_SCRIPT="/usr/local/bin/cloudpros-backup.sh"

echo "=== Starting CloudPros Environment Setup ==="

# ------------------------------------------------------------------------------
# 1. Package Installation
# ------------------------------------------------------------------------------
echo "Installing required system packages (socat, nginx, ufw, curl)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y socat nginx ufw curl logrotate

# ------------------------------------------------------------------------------
# 2. Dedicated System User Creation
# ------------------------------------------------------------------------------
echo "Configuring dedicated system user: $APP_USER..."
if ! id "$APP_USER" &>/dev/null; then
    adduser --system --no-create-home --group --shell /usr/sbin/nologin "$APP_USER"
    echo "User $APP_USER created successfully."
else
    echo "User $APP_USER already exists. Skipping creation."
fi

# ------------------------------------------------------------------------------
# 3. Directory Layout and File Initialization
# ------------------------------------------------------------------------------
echo "Initializing directory structures..."
mkdir -p "$APP_DIR" "$BACKUP_DIR" "$LOG_DIR"

# Create application script
echo "Writing application executable script..."
cat << 'EOF' > "$APP_DIR/app.sh"
#!/bin/bash
BODY="CloudPros Server Running"
LEN=$(echo -n "$BODY" | wc -c)

echo -e "HTTP/1.1 200 OK\r"
echo -e "Content-Type: text/plain\r"
echo -e "Content-Length: $LEN\r"
echo -e "Connection: close\r"
echo -e "\r"
echo -n "$BODY"
EOF

chmod +x "$APP_DIR/app.sh"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"
touch "$LOG_DIR/health.log"

# ------------------------------------------------------------------------------
# 4. Health Monitoring Script Deployment
# ------------------------------------------------------------------------------
echo "Writing healthcheck automation script to $HEALTH_SCRIPT..."
cat << 'EOF' > "$HEALTH_SCRIPT"
#!/bin/bash
URL="http://127.0.0.1:8000"
LOG_FILE="/var/log/cloudpros/health.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$URL")

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "[$TIMESTAMP] HEALTH CHECK PASSED: Service is responding with HTTP 200." >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] HEALTH CHECK FAILED: HTTP Status $HTTP_STATUS. Initiating recovery..." >> "$LOG_FILE"
    sudo systemctl restart cloudpros-app.service
    if [ $? -eq 0 ]; then
        # Restart returning 0 only means systemd started the process, not that the app is healthy.
        # Re-checking the endpoint, with a brief delay to give the app time to bind to the port.
        HTTP_STATUS="000"
        for _ in 1 2 3 4 5; do
            sleep 2
            HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$URL")
            [ "$HTTP_STATUS" -eq 200 ] && break
        done

        if [ "$HTTP_STATUS" -eq 200 ]; then
            echo "[$TIMESTAMP] RECOVERY SUCCESSFUL: cloudpros-app.service restarted and responding with HTTP 200." >> "$LOG_FILE"
        else
            echo "[$TIMESTAMP] RECOVERY FAILED: Service restarted but still returning HTTP Status $HTTP_STATUS." >> "$LOG_FILE"
            exit 1
        fi
    else
        echo "[$TIMESTAMP] RECOVERY FAILED: Unable to restart cloudpros-app.service." >> "$LOG_FILE"
        exit 1
    fi
fi
EOF
chmod +x "$HEALTH_SCRIPT"

# ------------------------------------------------------------------------------
# 5. Automated Backup Script Deployment
# ------------------------------------------------------------------------------
echo "Writing daily backup automation script to $BACKUP_SCRIPT..."
cat << 'EOF' > "$BACKUP_SCRIPT"
#!/bin/bash
set -e
SOURCE_DIR="/opt/cloudpros"
BACKUP_DIR="/var/backups/cloudpros"
DATE=$(date "+%Y-%m-%d")
FILENAME="cloudpros-$DATE.tar.gz"
BACKUP_PATH="$BACKUP_DIR/$FILENAME"

tar -czf "$BACKUP_PATH" -C "$SOURCE_DIR" .

if tar -tzf "$BACKUP_PATH" > /dev/null; then
    echo "Backup verification PASSED."
else
    echo "ERROR: Backup verification FAILED!" >&2
    rm -f "$BACKUP_PATH"
    exit 1
fi

find "$BACKUP_DIR" -name "cloudpros-*.tar.gz" -type f -mtime +7 -delete
EOF
chmod +x "$BACKUP_SCRIPT"

# ------------------------------------------------------------------------------
# 6. systemd Units Configuration (App, Health Timer, Backup Timer)
# ------------------------------------------------------------------------------
echo "Configuring systemd service and timer files..."

# Application Service (Self-Healing Enabled)
cat << EOF > /etc/systemd/system/cloudpros-app.service
[Unit]
Description=CloudPros Web Service
After=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/socat TCP-LISTEN:8000,bind=127.0.0.1,reuseaddr,fork EXEC:$APP_DIR/app.sh
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Health Check Service & Timer
cat << EOF > /etc/systemd/system/cloudpros-healthcheck.service
[Unit]
Description=Run CloudPros Health Check Script

[Service]
Type=oneshot
ExecStart=/usr/bin/bash $HEALTH_SCRIPT
EOF

cat << EOF > /etc/systemd/system/cloudpros-healthcheck.timer
[Unit]
Description=Trigger CloudPros Health Check Every Minute

[Timer]
Unit=cloudpros-healthcheck.service
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

# Backup Service & Timer
cat << EOF > /etc/systemd/system/cloudpros-backup.service
[Unit]
Description=Run Daily CloudPros Backup Script

[Service]
Type=oneshot
ExecStart=/usr/bin/bash $BACKUP_SCRIPT
EOF

cat << EOF > /etc/systemd/system/cloudpros-backup.timer
[Unit]
Description=Trigger CloudPros Backup Daily

[Timer]
Unit=cloudpros-backup.service
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Load and cycle systemd changes idempotently
systemctl daemon-reload

systemctl enable cloudpros-app.service
systemctl restart cloudpros-app.service

systemctl reset-failed cloudpros-healthcheck.timer || true
systemctl enable --now cloudpros-healthcheck.timer

systemctl reset-failed cloudpros-backup.timer || true
systemctl enable --now cloudpros-backup.timer

# ------------------------------------------------------------------------------
# 7. Nginx Proxy Configuration
# ------------------------------------------------------------------------------
echo "Configuring Nginx Reverse Proxy block..."
cat << 'EOF' > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

if nginx -t; then
    systemctl restart nginx
else
    echo "WARNING: Nginx configuration test failed. Skipping restart." >&2
fi

# ------------------------------------------------------------------------------
# 8. Log Rotation Configuration
# ------------------------------------------------------------------------------
echo "Configuring logrotate configurations..."
cat << EOF > /etc/logrotate.d/cloudpros
$LOG_DIR/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 $APP_USER $APP_USER
    sharedscripts
}
EOF

# ------------------------------------------------------------------------------
# 9. Firewall Configuration (UFW)
# ------------------------------------------------------------------------------
echo "Configuring firewall settings..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw --force enable

echo "=== Setup Completed Successfully! ==="
echo "Verify configuration with: curl -i http://127.0.0.1"


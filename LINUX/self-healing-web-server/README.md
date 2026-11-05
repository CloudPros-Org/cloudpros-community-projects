# Self-Healing Linux Web Server

## About the project

For this project, I set up a Linux web server that can recover from application failures and handle routine maintenance automatically.

I used Bash and `socat` for the application, systemd to manage the service, and Nginx as a reverse proxy. I also configured UFW, scheduled health checks, daily backups, and log rotation.

The goal was to make the server easier to manage, reduce manual intervention, and keep the application running when a process fails.

## How it works

When a user sends an HTTP request, Nginx receives it on port 80 and forwards it to the application listening on `127.0.0.1:8000`.

Systemd manages the application and restarts it if it exits unexpectedly. A separate timer runs the health-check service every minute, while another schedules daily backups. Old backups are removed after seven days, and logrotate handles log retention.

## Tools used

- **Bash and socat:** Run a simple HTTP server.
- **systemd:** Manage the application and schedule maintenance jobs.
- **Nginx:** Forward incoming HTTP requests to the application.
- **UFW:** Control incoming network traffic.
- **tar and gzip:** Create compressed backups and verify their contents.
- **logrotate:** Rotate and compress logs.

## Project structure

```text
self-healing-web-server/
├── app/
│   └── server.sh
├── systemd/
│   ├── cloudpros-app.service
│   ├── cloudpros-healthcheck.service
│   ├── cloudpros-healthcheck.timer
│   ├── cloudpros-backup.service
│   └── cloudpros-backup.timer
├── nginx/
│   └── cloudpros.conf
├── scripts/
│   ├── healthcheck.sh
│   └── backup.sh
├── logrotate/
│   └── cloudpros
├── evidence/
├── README.md
└── task.md
```

## Setup

These instructions assume you are running Ubuntu and have sudo access.

### 1. Install the required packages

```bash
sudo apt update
sudo apt install -y nginx socat ufw tar gzip logrotate
```

### 2. Create the application user and directories

I used a separate system account for the application instead of running it as root.

```bash
sudo useradd --system --user-group \
  --home-dir /nonexistent \
  --shell /usr/sbin/nologin appuser

sudo install -d -o root -g root -m 0755 /opt/cloudpros
sudo install -d -o root -g root -m 0755 /var/backups/cloudpros
sudo install -d -o root -g root -m 0755 /var/log/cloudpros
```

If `appuser` already exists, check it with `id appuser` rather than creating it again.

### 3. Install the application

```bash
sudo install -o root -g root -m 0755 \
  app/server.sh /opt/cloudpros/server.sh

bash -n app/server.sh
diff -u app/server.sh /opt/cloudpros/server.sh
```

The syntax check should complete without errors, and the comparison should produce no output when the two scripts match.

### 4. Configure systemd

Install the application service:

```bash
sudo install -o root -g root -m 0644 \
  systemd/cloudpros-app.service \
  /etc/systemd/system/cloudpros-app.service
```

Install the maintenance scripts:

```bash
sudo install -o root -g root -m 0755 \
  scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

sudo install -o root -g root -m 0755 \
  scripts/backup.sh /usr/local/bin/cloudpros-backup.sh
```

Install the health-check and backup service and timer files:

```bash
sudo install -m 0644 systemd/cloudpros-healthcheck.service \
  /etc/systemd/system/cloudpros-healthcheck.service

sudo install -m 0644 systemd/cloudpros-healthcheck.timer \
  /etc/systemd/system/cloudpros-healthcheck.timer

sudo install -m 0644 systemd/cloudpros-backup.service \
  /etc/systemd/system/cloudpros-backup.service

sudo install -m 0644 systemd/cloudpros-backup.timer \
  /etc/systemd/system/cloudpros-backup.timer

sudo systemctl daemon-reload
sudo systemctl enable --now cloudpros-app
sudo systemctl enable --now cloudpros-healthcheck.timer
sudo systemctl enable --now cloudpros-backup.timer
```

Before starting the timers, check that the `ExecStart` paths in the service files match where the scripts were installed.

### 5. Configure Nginx

```bash
sudo install -m 0644 nginx/cloudpros.conf \
  /etc/nginx/sites-available/cloudpros

sudo ln -sfn /etc/nginx/sites-available/cloudpros \
  /etc/nginx/sites-enabled/cloudpros

sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx
```

Nginx should listen on port 80 and forward requests to `127.0.0.1:8000`.

### 6. Configure UFW

I configured the firewall to deny incoming connections by default and allow outgoing connections.

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw enable
sudo ufw status verbose
```

Only SSH and HTTP should be externally accessible. Port 8000 is intended for local application traffic, so it should not have an external allow rule.

### 7. Harden SSH

The SSH configuration should allow public-key authentication and disable password authentication, keyboard-interactive authentication, and root login.

The settings in `/etc/ssh/sshd_config.d/99-cloudpros.conf` are:

```text
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
```

Validate the configuration before reloading SSH:

```bash
sudo sshd -t

sudo sshd -T | grep -E \
  'pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin'

sudo systemctl reload ssh
```

Keep your current SSH session open until you have confirmed that a new key-based login works.

### 8. Configure log rotation

```bash
sudo install -m 0644 logrotate/cloudpros \
  /etc/logrotate.d/cloudpros

sudo logrotate -d /etc/logrotate.d/cloudpros
```

The intended configuration rotates logs daily, keeps seven rotations, and compresses older logs.

## Testing

I used the following commands to check the application, reverse proxy, firewall, timers, and backup process.

### Check the application and Nginx

```bash
sudo systemctl status cloudpros-app --no-pager
sudo systemctl status nginx --no-pager

curl -i http://127.0.0.1:8000
curl -i http://127.0.0.1

sudo ss -ltnp
```

The expected result is an HTTP `200 OK` response with the body `CloudPros Server Running`. The application should listen on `127.0.0.1:8000`, while Nginx handles requests on port 80.

### Test automatic recovery

First, record the running process ID and make sure it is valid before stopping the process:

```bash
OLD_PID=$(sudo systemctl show cloudpros-app -p MainPID --value)
echo "Original PID: $OLD_PID"

if [[ "$OLD_PID" =~ ^[1-9][0-9]*$ ]]; then
  sudo kill -9 "$OLD_PID"
else
  echo "No valid application PID. Check the service first."
  exit 1
fi

sleep 5

sudo systemctl is-active cloudpros-app
NEW_PID=$(sudo systemctl show cloudpros-app -p MainPID --value)

echo "Original PID: $OLD_PID"
echo "New PID: $NEW_PID"

sudo journalctl -u cloudpros-app -n 30 --no-pager
curl -i http://127.0.0.1:8000
```

For this test to pass, the service must become active again, the new PID must differ from the original PID, and the application must respond successfully.

### Test backup creation and verification

```bash
sudo /usr/local/bin/cloudpros-backup.sh

BACKUP_FILE="/var/backups/cloudpros/cloudpros-$(date +%F).tar.gz"

sudo test -s "$BACKUP_FILE"
sudo tar -tzf "$BACKUP_FILE"
```

The archive listing should complete without errors and show files under `cloudpros/`. The backup script also needs to return a non-zero exit status if archive creation or verification fails.

### Check the timers, logs, and firewall

```bash
sudo systemctl list-timers --all

sudo systemctl start cloudpros-healthcheck.service
sudo systemctl status cloudpros-healthcheck.service --no-pager
sudo journalctl -u cloudpros-healthcheck.service -n 30 --no-pager

sudo ls -lah /var/log/cloudpros/
sudo ufw status verbose
sudo ufw status numbered
```

## Issues I encountered

One issue I ran into was the application service failing to start with systemd error `203/EXEC`. The service was configured to execute the application script, but systemd could not execute it. This prevented the application from listening on port 8000.

I also received a `502 Bad Gateway` response from Nginx while the application was unavailable. This helped me understand the importance of checking the upstream service before assuming the reverse proxy itself is broken.

These issues reinforced the need to validate scripts, inspect systemd logs, and test the application directly before testing the full request path through Nginx.

## What I learned

This project gave me more practice with Linux service management, SSH hardening, firewall rules, and systemd timers.

It also reinforced a few important lessons:

- Automatic restarts are useful, but they cannot fix a persistent application configuration or execution error.
- A working Nginx configuration does not guarantee that the application behind it is healthy.
- A backup should be verified, not just created. Running `tar -tzf` checks that the archive can be read.
- Testing each component separately makes troubleshooting easier.
- Evidence should show actual command output and results, rather than just the configuration.

## Evidence

The `evidence/` directory contains the test outputs and screenshots collected for the project. It should demonstrate:

- SSH and firewall configuration
- Successful application and Nginx responses
- Application recovery with the original and new PIDs
- Backup creation and archive verification
- Health-check and timer execution
- Logrotate validation

## Conclusion

The project brings together several practical Linux administration tasks in one setup. It combines a reverse-proxied application with service recovery, scheduled health checks, backup verification, and log management.

The final validation results and evidence should be reviewed alongside the configuration to confirm that each component works as expected.

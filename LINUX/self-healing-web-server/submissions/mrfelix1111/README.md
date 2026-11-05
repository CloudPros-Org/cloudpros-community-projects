# CloudPros Self-Healing Linux Web Server

## 1. Project Overview

This project deploys a secure, self-healing web server on Ubuntu 24.04 LTS. It uses Nginx as a reverse proxy, a Bash-based HTTP application using socat, and systemd to manage application recovery, health checks and automated backups.

The application runs under a dedicated, non-login `appuser` account and listens only on `127.0.0.1:8000`. Nginx accepts incoming HTTP requests on port 80 and forwards them to the application.

The application returns the following response:

`CloudPros Server Running`

## 2. Architecture

- **Nginx:** Accepts HTTP requests on port 80 and forwards them to the application.
- **Application:** Bash-based HTTP server using socat.
- **appuser:** Dedicated, unprivileged account running the application.
- **deploy:** Deployment account with sudo privileges.
- **systemd:** Manages the application and scheduled tasks.
- **Health check:** Runs every minute and restarts the application if unhealthy.
- **Backup:** Creates daily compressed archives and removes older backups.
- **Log rotation:** Rotates application and health-check logs daily, retaining seven rotations.

## 3. Security Configuration

### User Accounts

- `appuser` runs the application with a non-login shell.
- `deploy` has sudo privileges.
- Application files are stored in `/opt/cloudpros`.

### SSH Hardening

SSH security settings:

- Public-key authentication enabled.
- Password authentication disabled.
- Keyboard-interactive authentication disabled.
- Direct root login disabled.

Configuration file:

`/etc/ssh/sshd_config.d/99-hardening.conf`

Validate SSH configuration:

    sudo sshd -t

    sudo sshd -T | grep -E 'permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication'

### Firewall

UFW is configured with:

- Default incoming traffic denied.
- Default outgoing traffic allowed.
- SSH (port 22) allowed.
- HTTP (port 80) allowed.
- Application port 8000 not exposed externally.

Check firewall status:

    sudo ufw status verbose

The application listens on `127.0.0.1:8000`, so requests to the application are handled locally through Nginx.

## 4. Application and Nginx

The application uses Bash and socat to provide a lightweight HTTP service.

Application files:

- `app/server.sh`
- `app/respond.sh`

Installed application directory:

`/opt/cloudpros/`

The application is managed by:

`cloudpros-app.service`

It runs as `appuser` and listens on:

`127.0.0.1:8000`

Nginx accepts incoming HTTP requests on port 80 and forwards them to:

`http://127.0.0.1:8000`

Useful commands:

    sudo systemctl status cloudpros-app
    sudo systemctl restart cloudpros-app
    sudo systemctl status nginx
    sudo nginx -t

Test the application:

    curl -i http://127.0.0.1:8000

Test through Nginx:

    curl -i http://localhost

Expected response:

    CloudPros Server Running

## 5. Automatic Application Recovery

The application is managed by systemd with the following restart settings:

- `Restart=always`
- `RestartSec=5`

If the application process terminates unexpectedly, systemd automatically attempts to restart it.

The health check is implemented in:

- `scripts/healthcheck.sh`
- `systemd/cloudpros-healthcheck.service`
- `systemd/cloudpros-healthcheck.timer`

The installed health-check script is:

`/usr/local/bin/healthcheck.sh`

The health-check timer runs every minute. It checks the application at `127.0.0.1:8000`. If the application does not respond successfully, the script attempts to restart `cloudpros-app.service`.

Timestamped health-check results are written to:

`/var/log/cloudpros/healthcheck.log`

Check the timer:

    systemctl list-timers --all | grep cloudpros-healthcheck

Inspect health-check logs:

    sudo tail -n 20 /var/log/cloudpros/healthcheck.log

Inspect the systemd journal:

    sudo journalctl -u cloudpros-healthcheck.service

## 6. Automated Backups

The backup script is located at:

`scripts/backup.sh`

Backups are stored in:

`/var/backups/cloudpros/`

A compressed archive is created daily with a date-based filename, for example:

`cloudpros-2026-11-04.tar.gz`

The backup contains the application directory `/opt/cloudpros`.

The script removes matching backup archives older than seven days.

The backup is scheduled using:

- `systemd/cloudpros-backup.service`
- `systemd/cloudpros-backup.timer`

Check the backup timer:

    systemctl list-timers --all | grep cloudpros-backup

Run a backup manually:

    sudo systemctl start cloudpros-backup.service

Check backup files:

    sudo ls -lh /var/backups/cloudpros/

Inspect a backup archive:

    sudo tar -tzf /var/backups/cloudpros/cloudpros-YYYY-MM-DD.tar.gz

Replace `YYYY-MM-DD` with the actual backup date.

## 7. Log Rotation

Application and health-check logs are stored in:

`/var/log/cloudpros/`

The log rotation configuration is:

`/etc/logrotate.d/cloudpros`

It applies to:

`/var/log/cloudpros/*.log`

The configuration:

- Rotates logs daily.
- Retains seven rotations.
- Compresses older rotated logs.
- Handles missing and empty log files.
- Uses `copytruncate` so services can continue writing without restarting.

Check the configuration:

    sudo logrotate -d /etc/logrotate.d/cloudpros

Force a rotation for testing:

    sudo logrotate -vf /etc/logrotate.d/cloudpros

Inspect logs:

    sudo ls -lah /var/log/cloudpros/
    sudo tail -n 20 /var/log/cloudpros/app.log
    sudo tail -n 20 /var/log/cloudpros/healthcheck.log

## 8. Verification and Recovery Tests

### Application and Nginx

Check service status:

    sudo systemctl is-active cloudpros-app nginx

Test HTTP access:

    curl -i http://localhost

Expected HTTP status:

`200 OK`

Expected response body:

`CloudPros Server Running`

### Listening Ports

Check listening ports:

    sudo ss -lntp | grep -E ':80|:8000'

Expected configuration:

- Nginx listens on port 80.
- The application listens only on `127.0.0.1:8000`.

### Automatic systemd Recovery

The application was deliberately terminated using SIGKILL to test systemd recovery.

Test command:

    sudo systemctl kill --signal=SIGKILL cloudpros-app.service

The application was checked after five seconds.

Observed recovery:

- Original PID: `15839`
- New PID: `16075`
- New process: `socat`
- Service status: `active (running)`

This confirmed that systemd automatically restarted the application after the original process was killed.

### Health-check Recovery

The health-check recovery mechanism was also tested by stopping the application service and allowing the scheduled health check to detect the failure and restart it.

Verify:

    sudo systemctl is-active cloudpros-app
    sudo journalctl -u cloudpros-healthcheck.service
    sudo tail -n 20 /var/log/cloudpros/healthcheck.log

### Backup Verification

A manual backup was successfully created using:

    sudo systemctl start cloudpros-backup.service

The resulting archive was inspected using `tar -tzf` to verify its contents.

## 9. Project Structure

    self-healing-web-server/
    ├── README.md
    ├── app/
    │   ├── server.sh
    │   └── respond.sh
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
    └── logrotate/
        └── cloudpros

## 10. Environment Notes

This project was configured and tested using Ubuntu 24.04 LTS under Windows Subsystem for Linux (WSL).

Application availability, systemd recovery, scheduled health checks, backups and log rotation were tested locally.

WSL networking and firewall behaviour can differ from a standalone Linux server. UFW configuration should therefore be independently validated when deploying to a production Linux host.

The application binds to localhost port 8000, while Nginx handles incoming HTTP requests on port 80.

## 11. Challenges and Lessons Learned

### Application implementation

The initial application used Python's built-in HTTP server. The implementation was changed to Bash and socat to meet the project requirement for a lightweight Bash-based HTTP service.

### Service recovery

The application was deliberately terminated using SIGKILL. Systemd successfully detected the process failure and started a replacement process.

### Health monitoring

The health-check script was updated to use the required installation path and write timestamped results to a dedicated log file.

### Log management

Log rotation was expanded from a single application log to all `.log` files in `/var/log/cloudpros/`, covering both application and health-check logs.

### WSL environment

The project was tested in WSL. Networking and firewall behaviour may differ from a standalone Linux deployment, so these should be independently validated on a production host.

## 12. Conclusion

This project demonstrates a secure Linux web server with dedicated user permissions, SSH hardening, firewall rules, an Nginx reverse proxy, a Bash and socat application, systemd-managed automatic recovery, scheduled health monitoring, automated backups, backup retention and log rotation.

## 13. Test Evidence

The `evidence/` directory contains the results of the implementation and verification tests.

| Evidence file | What it demonstrates |
|---|---|
| `evidence/security.txt` | UFW firewall rules, SSH hardening and service accounts |
| `evidence/application.txt` | HTTP 200 response, Nginx and application listening ports |
| `evidence/systemd-recovery.txt` | SIGKILL test and automatic systemd recovery with a new PID |
| `evidence/recovery.txt` | Health-check recovery and application health logs |
| `evidence/timers.txt` | Scheduled health-check and backup timers |
| `evidence/backup-restore-retention.txt` | Backup archive, restoration, script validation and retention |
| `evidence/logrotate.txt` | Log rotation configuration and validation |

All tests were performed locally in Ubuntu 24.04 under WSL. External networking and firewall behaviour should be independently validated on a production Linux host.

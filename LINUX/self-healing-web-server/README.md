# CloudPros Self‑Healing Web Server
A fully automated, self‑healing Linux web service featuring:

- Nginx reverse proxy

- systemd‑managed backend

- automatic crash recovery

- health monitoring

- daily backups

- log rotation

- clean, reproducible setup

This project demonstrates how to build a resilient, production‑grade service using only standard Linux tools.

## 📦 Project Overview
CloudPros is a lightweight HTTP service running on port 8000, fronted by Nginx on port 80.
The backend is powered by socat and a simple response script, while systemd ensures the service automatically restarts after crashes.

Additional components include:

- Health monitoring (systemd timer + Bash script)

- Automated backups (systemd timer + tar archives)

- Log rotation (logrotate)

The result is a fully self‑healing Linux web server.

## 🚀 Project Setup
1.    Install project files
Place your application under:

```bash
/opt/cloudpros/
```
This directory contains:

- server.sh — launches socat

- response.sh — returns HTTP responses

- any supporting files

### Ensure scripts are executable:

```bash
sudo chmod +x /opt/cloudpros/*.sh
```

## 🌐 How Nginx Works With the Application
Nginx listens on port 80 and proxies all incoming HTTP traffic to the backend service on 127.0.0.1:8000.

Example Nginx configuration:

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```
This ensures:

- The backend is never exposed directly

- Nginx handles connection management

- The service behaves like a standard web server

## 🔁 How systemd Handles Application Recovery
The backend is managed by a systemd service:

```bash
/etc/systemd/system/cloudpros-app.service
```
Key directives:

```Code
Restart=always
RestartSec=10
StartLimitIntervalSec=0
```
This ensures:

- The service restarts automatically after crashes

- Recovery happens within 10 seconds

- kill -9 triggers a restart

- A new PID is assigned after recovery

This is the core of the self‑healing behavior.

## ❤️ Health Monitoring
A health check script runs every minute:

```Code
/usr/local/bin/healthcheck.sh
```
It:

- Sends an HTTP request to 127.0.0.1:8000

- Logs the result to /var/log/cloudpros/health.log

- Restarts the service if the response is not 200 OK

Systemd timer:

```Code
/etc/systemd/system/cloudpros-health.timer
```
Runs the health check every minute:

```Code
OnUnitActiveSec=60s
Unit=cloudpros-health.service
```
This ensures the service recovers even if systemd fails to detect a crash.

## 🗄 Automated Backups
Daily backups are created using:

```Code
/usr/local/bin/cloudpros-backup.sh
```
Backups are stored in:

```Code
/var/backups/cloudpros/
```
Backup filenames include the date:

```Code
cloudpros-YYYY-MM-DD.tar.gz
```
The script:

- Creates a compressed tarball

- Verifies the archive

- Deletes backups older than 7 days

- Logs results to /var/log/cloudpros/backup.log

A systemd timer runs the backup daily:

```Code
OnCalendar=daily
```

## 🌀 Log Rotation
Log rotation is configured via:

```Code
/etc/logrotate.d/cloudpros
```

It rotates:

```Code
/var/log/cloudpros/*.log
```
Settings:

- Rotate daily

- Keep 7 days

- Compress old logs

- Skip empty or missing logs

This prevents uncontrolled log growth.

## 🔧 Reproducing the Setup
Anyone can reproduce this environment by following these steps:

- Install project files into /opt/cloudpros/

- Create the systemd service (cloudpros-app.service)

- Enable and start the service

- Install Nginx and configure the reverse proxy

- Create the health check script + timer

- Create the backup script + timer

- Configure logrotate

- Reload systemd and enable all timers

Commands:

```bash
sudo systemctl daemon-reload
sudo systemctl enable cloudpros-app
sudo systemctl start cloudpros-app

sudo systemctl enable cloudpros-health.timer
sudo systemctl start cloudpros-health.timer

sudo systemctl enable cloudpros-backup.timer
sudo systemctl start cloudpros-backup.timer
```
After this, the system becomes fully self‑healing.

## ⚠️ Challenges & How They Were Solved
1. socat restart storm
Systemd kept spawning socat repeatedly, causing:

- Port 8000 to stay locked

- Nginx to hang

- Multiple socat processes

Solution:
Stop the service, kill all socat processes, fix the systemd restart configuration.

2. Nginx hanging with no response
Curl showed:

```Code
Connected... but no response
```
Cause:
Backend was failing, so Nginx had nothing to proxy.

Solution:
Fix backend stability + systemd restart loop.

3. Health checks not triggering
Early versions didn’t restart the service correctly.

Solution:
Use ```systemctl restart cloudpros-app``` inside the health script.

4. Log growth
Logs grew indefinitely.

Solution:
Add logrotate with daily rotation + compression.

🔐 Security Notice
This project does not include:

Passwords

Private SSH keys

API tokens

Secrets of any kind

Never commit sensitive information to version control.

## 🎉 Final Result
A fully automated, self‑healing Linux web server with:

- Reverse proxy

- Crash recovery

- Health monitoring

- Daily backups

- Log rotation

- Reproducible setup

This is a real production‑grade architecture built entirely from standard Linux tools.

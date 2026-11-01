
# Self-Healing Linux Web Server

## Overview

This project implements a self-healing Linux web server on Ubuntu 24.04 using WSL. It uses Bash, socat, systemd, Nginx, UFW, curl, and logrotate.

The application runs locally on 127.0.0.1:8000, while Nginx exposes it through HTTP on port 80.

## Architecture

Client -> Nginx:80 -> Bash application:8000

systemd restarts the application after unexpected failures.
A systemd timer runs health checks every minute.
Another systemd timer runs daily backups.

## Project Structure

- `app/`: Application script
- `systemd/`: Application service and automation timers
- `nginx/`: Reverse proxy configuration
- `scripts/`: Health-check and backup scripts
- `logrotate/`: Log rotation configuration
- `evidence/`: Test outputs and screenshots

## Requirements

- Ubuntu 24.04
- Bash
- systemd
- Nginx
- socat
- UFW
- curl
- logrotate

## Setup

Install the required packages, create the `deploy` and `appuser` accounts, configure SSH, and apply the service and Nginx configurations.

Follow the setup commands documented in this repository.

## How It Works

### Application

The Bash script uses socat to listen on 127.0.0.1:8000 and return an HTTP 200 response.

### Reverse Proxy

Nginx listens on port 80 and forwards requests to the local application.

### Self-Healing

The cloudpros-app systemd service uses Restart=on-failure and RestartSec=2 to recover from unexpected failures.

### Health Monitoring

A Bash script checks the application's HTTP response and restarts the service if the check fails. A systemd timer runs the check every minute.

### Backups

The backup script creates a dated tar.gz archive of /opt/cloudpros and removes matching backups older than seven days. A systemd timer schedules daily backups.

### Log Rotation

Logrotate rotates /var/log/cloudpros/*.log daily, retains seven rotated logs, and compresses rotated files.

### Security

The application runs as appuser and binds to 127.0.0.1:8000. Nginx provides the HTTP entry point. UFW is configured to allow SSH and HTTP.

## Testing

Document the actual results of:

- HTTP response through Nginx
- Application recovery after killing its process
- Health-check execution
- Backup creation and extraction
- Logrotate validation
- Firewall and listening-port checks
- SSH key authentication

## Environment Notes

This project was tested in Ubuntu 24.04 on WSL. Document any networking or firewall differences encountered.

## Challenges and Lessons Learnt

Add the challenges you actually encountered and how you resolved them.

## Evidence

See the `evidence/` directory for test results.

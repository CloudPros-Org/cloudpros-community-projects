# CloudPros Self-Healing Linux Web Service Deployment

Automated, secure, resilient and self-healing Bash-based HTTP web service infrastructure running on Ubuntu 24.04. This repository contains configuration and automation assets designed to host a lightweight HTTP daemon via `socat`, fronted by an Nginx reverse proxy, and fully automated using native systemd structures.

## Infrastructure Architecture Overview
The service operates under a highly secure, layered environment:
*   **Edge Proxy:** Nginx listens on public port 80 and proxies traffic internally.
*   **Application Daemon:** A lightweight Bash script executed via `socat` on `127.0.0.1:8000`.
*   **Security Sandboxing:** The daemon runs under an unprivileged system isolation profile (`appuser`), and the network layer is constrained via UFW to drop all external port 8000 connections.
*   **Lifecycle Management:** System processes, timers, backups, health checks, and log lifecycles are orchestrated completely through native `systemd` and `logrotate` integrations.

---

## What Was Completed
1.  **Privilege Separation & Hardening:** Provisions a passwordless automation account (`deploy`) and builds a non-root, shell-less isolation identity (`appuser`) for runtime operations.
2.  **Reverse Proxy Infrastructure:** Configured Nginx to act as an edge interface, maps standard request headers (`Host`, `X-Real-IP`), and shields the upstream back-end.
3.  **Self-Healing Application Core:** Wraps the `socat` listener in a `systemd` monitor that guarantees automatic runtime environment recovery under 10 seconds following sudden exceptions or crashes.
4.  **Health Telemetry Loop:** Deploys a chronological checker that hits local sockets every 60 seconds via `systemd` timers, recording timestamped execution summaries inside `/var/log/cloudpros/health.log`.
5.  **Automated Daily Backups:** Orchestrates automated daily file state consolidation (`tar.gz`) into `/var/backups/cloudpros/`, featuring integrated verification loops and a strict rolling 7-day retention prune.
6.  **Optimised Log Lifecycle:** Integrates a custom `logrotate` definition that performs daily rotation, conditional skipping for empty files, and transparent gzip historical compression.
7.  **Idempotent Provisioning Blueprint:** Engineers a fully encapsulated `setup.sh` automation script that securely provisions the comprehensive architecture on any fresh Ubuntu 24.04 instance.

---

## Deployment & Usage

### Prerequisites
*   A clean instance running **Ubuntu 24.04 LTS**.
*   Active root or `sudo` privilege access during execution.
*   Internet connectivity to pull standard distribution mirror packages.

### Automated Installation
To execute the idempotent environmental build, clone this asset collection to your machine and run:
```bash
chmod +x setup.sh
sudo ./setup.sh
```

---

## Verification & Testing Manifest

### 1. Reverse Proxy Traffic Routing
Verify that public edge connections successfully handshake with the internal daemon framework:
```bash
curl -i http://127.0.0.1
```
*Expected Response:*
```text
HTTP/1.1 200 OK
Server: nginx/...
Content-Type: text/plain

CloudPros Server Running
```
![Curl_results](./evidence/Screenshot%202026-11-02%20at%2021.42.13.png)

Result when testing port 8000 from using public IP
![public-access](./evidence/Screenshot%202026-11-02%20at%2021.43.53.png)

### 2. Network Isolation Verification
Ensure that port 8000 is securely contained and strictly unexposed to outer network boundaries:
```bash
sudo ufw status verbose
sudo ss -tulpn | grep :8000
```
*Verification Profile:* UFW default incoming will match `deny`, and the application bind point will target localhost interfaces (`127.0.0.1`) explicitly.

![ufw](./evidence/Screenshot%202026-11-02%20at%2021.32.41.png)

![ss -tulpn](./evidence/Screenshot%202026-11-02%20at%2021.44.50.png)

### 3. Recovery Test
Simulate a catastrophic application runtime failure by forcefully killing the application wrapper's process ID:
```bash
# Locate active MainPID
systemctl show --property=MainPID cloudpros-app.service

# Forcefully kill the active process
sudo kill -9 <MainPID>

# Check application recovery status 5 seconds later
sudo systemctl status cloudpros-app.service
```
*Verification Profile:* The service immediately transitions back into an `active (running)` state under a completely new, clean Process ID (PID).

![pid](./evidence/Screenshot%202026-11-02%20at%2021.27.40.png)

![recovery](./evidence/Screenshot%202026-11-02%20at%2021.31.48.png)

### 4. Scheduler Automation Status
Verify that background infrastructure monitors are active, tracking accurately, and waiting for upcoming triggers:
```bash
sudo systemctl list-timers --all | grep cloudpros
```
![Cloudpros-timer](./evidence/Screenshot%202026-11-02%20at%2021.38.44.png)

### 4. Log Rotation check
Ensure logrotate is configured correctly
```bash
sudo logrotate -d /etc/logrotate.d/cloudpros
```
*Verification Profile:* Log rotation configuration should be displayed correctly.

![logrotate](./evidence/Screenshot%202026-11-02%20at%2021.55.36.png)

---

## Challenges & Core Takeaways
*   **Systemd Timer Synchronization Patterns:** Systemd timer units require careful architecture alignment; they rely on an explicitly structured name association with their target `.service` unit or definitive `Unit=` attribute assignments to execute tasks reliably.
*   **Sequential Sudoers Parsing Topologies:** Linux processes `sudoers` rule structures strictly from top to bottom. Specific override privileges (such as `NOPASSWD` entries) must always reside at the absolute bottom of configuration definitions to prevent generic system group mappings from overriding individual access profiles.

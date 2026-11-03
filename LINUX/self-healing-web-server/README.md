# Self-Healing Linux Web Server

A Bash web service (`socat`) on Ubuntu 24.04, fronted by Nginx and managed by systemd. If the app crashes it restarts itself, a timer checks its health every minute, and backups and log rotation run automatically. Built and tested on an AWS EC2 instance.

## How it fits together

```text
Internet -> AWS security group (22, 80) -> UFW (22, 80) -> Nginx :80 -> socat 127.0.0.1:8000 -> app.sh
```

| Component | Role |
|---|---|
| Nginx | Public entry point on port 80. Forwards requests to the app. |
| socat + `app.sh` | The web service. Listens on `127.0.0.1:8000` and returns `CloudPros Server Running`. |
| systemd | Runs the app, restarts it on failure, and schedules the health check and backups. |
| UFW and AWS security group | Allow only SSH (22) and HTTP (80). Port 8000 is never opened. |
| logrotate | Rotates `/var/log/cloudpros/*.log`. |

## Repository layout

```text
self-healing-web-server/
├── README.md
├── setup.sh                         # installs and configures everything below
├── app/
│   └── server.sh                    # HTTP response script
├── systemd/
│   ├── cloudpros-app.service
│   ├── cloudpros-healthcheck.service
│   ├── cloudpros-healthcheck.timer
│   ├── cloudpros-backup.service
│   └── cloudpros-backup.timer
├── nginx/
│   └── cloudpros.conf               # reverse proxy config
├── scripts/
│   ├── healthcheck.sh
│   └── cloudpros-backup.sh
├── logrotate/
│   └── cloudpros                    # log rotation config
└── evidence/                        # screenshots
```

`setup.sh` writes the app, scripts, units and configs itself, so the other files are readable copies of what it installs. If you change one, change the other.

## Setup and reproduction

### 1. Launch the instance

- Ubuntu Server 24.04 LTS AMI, with a key pair.
- Security group: inbound **22** and **80** only. Do not add 8000.

### 2. Create the `deploy` user (manual)

`setup.sh` does not touch users that log in over SSH. Create `deploy` by hand while logged in as `ubuntu`:

```bash
# Create the user with a home directory and bash shell
sudo useradd -m -s /bin/bash deploy

# Reuse the ubuntu user's SSH key
sudo mkdir /home/deploy/.ssh
sudo cp -r /home/ubuntu/.ssh /home/deploy/
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys

# Grant sudo
sudo usermod -aG sudo deploy
```

Then verify:

```bash
sudo su - deploy      # switch to deploy
id deploy             # confirms membership of the sudo group
sudo -l -U deploy     # lists deploy's sudo privileges
```

In a **second terminal**, confirm `ssh -i <key>.pem deploy@<EC2_PUBLIC_IP>` works before closing your original session.

`sudo visudo` was used to edit sudoers rules for `deploy` (see Challenges). `id deploy` in the evidence below confirms `deploy` exists and is in the `sudo` group.

### 3. Deploy

```bash
git clone -b feat/self-healing-web-server-ko git@github.com:kevlar2/cloudpros-community-projects.git
cd cloudpros-community-projects/LINUX/self-healing-web-server
sudo ./setup.sh
```

`setup.sh` is safe to re-run. It:

1. Installs `socat`, `nginx`, `ufw`, `curl`, `logrotate`.
2. Creates `appuser`, a system user with no home and no login shell.
3. Creates `/opt/cloudpros`, `/var/backups/cloudpros`, `/var/log/cloudpros` and writes `app.sh`.
4. Installs `/usr/local/bin/healthcheck.sh` and `/usr/local/bin/cloudpros-backup.sh`.
5. Writes the systemd units, then enables and starts the app service and both timers.
6. Writes the Nginx site config, tests it with `nginx -t`, and restarts Nginx.
7. Writes `/etc/logrotate.d/cloudpros`.
8. Configures UFW: deny incoming, allow outgoing, allow ssh, allow http, enable.

## How the app and Nginx work together

`socat` listens on `127.0.0.1:8000` and runs `app.sh` for each connection (`fork`). The script prints a valid HTTP/1.1 `200 OK` with a `Content-Length`, then closes the connection. The service runs as `appuser`, not root.

Nginx listens on port 80 and `proxy_pass`es everything to `http://127.0.0.1:8000`. It passes `Host`, `X-Real-IP`, `X-Forwarded-For` and `X-Forwarded-Proto` so the app can see the original request details. Because the app is bound to localhost, the only way in from outside is through Nginx.

## How systemd handles recovery

`cloudpros-app.service` sets:

```ini
Restart=always
RestartSec=5s
```

If the process dies for any reason, including `kill -9`, systemd waits 5 seconds and starts it again with a new PID. That is inside the 10-second requirement. The service is enabled, so it also starts on boot.

## How health monitoring works

`cloudpros-healthcheck.timer` runs `cloudpros-healthcheck.service` one minute after boot and then every minute (`OnUnitActiveSec=1min`). The service runs `/usr/local/bin/healthcheck.sh`, which:

1. Requests `http://127.0.0.1:8000` with `curl` and a 5-second timeout.
2. If the status is 200, logs `HEALTH CHECK PASSED`.
3. Otherwise logs `HEALTH CHECK FAILED`, runs `systemctl restart cloudpros-app.service`, and logs whether recovery succeeded.

Every line is timestamped in `/var/log/cloudpros/health.log`. The check runs as a systemd service (root), so it can restart the app without a sudoers rule. No cron is used.

The two recovery paths are complementary. `Restart=always` handles a crashed process in about 5 seconds. The health check handles a process that is running but not answering correctly.

## How backups and log rotation are configured

### Backups

`cloudpros-backup.timer` runs daily (`OnCalendar=daily`, `Persistent=true` so a missed run happens after boot). It runs `/usr/local/bin/cloudpros-backup.sh`, which:

1. Creates `/var/backups/cloudpros/cloudpros-YYYY-MM-DD.tar.gz` from `/opt/cloudpros`.
2. Verifies it with `tar -tzf`. On failure it deletes the archive and exits non-zero.
3. Deletes backups older than 7 days (`find ... -mtime +7 -delete`).

### Log rotation

`/etc/logrotate.d/cloudpros` applies to `/var/log/cloudpros/*.log`:

| Setting | Effect |
|---|---|
| `daily` | Rotate every day |
| `rotate 7` | Keep seven rotated logs |
| `compress`, `delaycompress` | Gzip old logs, leaving the most recent rotation uncompressed |
| `missingok` | No error if the log is missing |
| `notifempty` | Skip empty logs |
| `create 0640 appuser appuser` | Recreate the log with these permissions |

## Verification and evidence

### Secure access

`deploy` has sudo and `appuser` has no login shell:

![users](./evidence/Screenshot%202026-11-02%20at%2022.01.43.png)

Commands used to create `deploy`:

![deploy-commands](./evidence/Image%2031-10-2026%20at%2016.24.PNG)

Logged in as `deploy`, in the `sudo` group, and `sudo` works:

![deploy-sudo](./evidence/Screenshot%202026-11-03%20at%2000.21.35.png)

### HTTP through Nginx

```bash
curl -i http://127.0.0.1
```

![curl](./evidence/Screenshot%202026-11-02%20at%2021.42.13.png)

### Port 8000 is not reachable from outside

From a machine outside the instance, `curl --connect-timeout 5 http://<EC2_PUBLIC_IP>:8000` fails:

![public-access](./evidence/Screenshot%202026-11-02%20at%2021.43.53.png)

### Firewall and listening address

```bash
sudo ufw status verbose
sudo ss -ltnp | grep :8000
```

The app is bound to `127.0.0.1:8000`, not `0.0.0.0`.

![ufw](./evidence/Screenshot%202026-11-02%20at%2021.32.41.png)

![ss](./evidence/Screenshot%202026-11-02%20at%2021.44.50.png)

### Recovery test

```bash
systemctl show --property=MainPID cloudpros-app.service
sudo kill -9 <MainPID>
sudo systemctl status cloudpros-app.service
```

Original PID:

![pid](./evidence/Screenshot%202026-11-02%20at%2021.27.40.png)

New PID, service active again:

![recovery](./evidence/Screenshot%202026-11-02%20at%2021.31.48.png)

### Timers

```bash
sudo systemctl list-timers --all | grep cloudpros
```

![timers](./evidence/Screenshot%202026-11-02%20at%2021.38.44.png)

### Log rotation

```bash
sudo logrotate -d /etc/logrotate.d/cloudpros
```

![logrotate](./evidence/Screenshot%202026-11-02%20at%2021.55.36.png)

The installed configuration:

![logrotate-config](./evidence/Screenshot%202026-11-03%20at%2000.28.59.png)

### Backups

```bash
sudo systemctl start cloudpros-backup.service
ls -l /var/backups/cloudpros/                      # dated filename
tar -tzf /var/backups/cloudpros/cloudpros-$(date +%F).tar.gz   # extraction test
```

![backups](./evidence/Screenshot%202026-11-02%20at%2023.55.18.png)

Extraction test: `tar -tzf` lists the archive contents without error.

![backup-extraction-test](./evidence/Screenshot%202026-11-03%20at%2000.29.43.png)

## Challenges and how I resolved them

- **Timer did not run its task.** A `.timer` only triggers a unit it is linked to. I linked each timer to its service with `Unit=` and matching names, then confirmed with `systemctl list-timers`.
- **Sudo rule ignored.** sudoers is read top to bottom and the last match wins, so a `NOPASSWD` line placed above a generic group rule was overridden. Moving it to the bottom fixed it.
- **Port 8000 exposure.** Rather than relying only on UFW, I bound socat to `127.0.0.1` and left 8000 out of the security group, so it is blocked at three levels.

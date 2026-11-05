# Self-Healing Linux Web Server

Environment: Ubuntu 24.04 on WSL (Windows)

A small web service on Ubuntu that is secure, reachable through Nginx, recovers by itself after a crash, checks its own health every minute, backs itself up daily, and rotates its logs.

## Project structure

```text
app/server.sh                         the web application (Bash + socat)
systemd/cloudpros-app.service         runs the app as appuser, restarts it on failure
systemd/cloudpros-healthcheck.*       health check service and timer (every minute)
systemd/cloudpros-backup.*            backup service and timer (daily)
nginx/cloudpros.conf                  reverse proxy on port 80
scripts/healthcheck.sh                health check script
scripts/backup.sh                     backup script
logrotate/cloudpros                   log rotation rules
evidence/                             screenshots
```

## 1. Secure the server

- Created the `deploy` user and added it to the `sudo` group.
- Created an SSH key pair with `ssh-keygen -t ed25519` and put the public key in `/home/deploy/.ssh/authorized_keys` (folder mode 700, file mode 600).
- Tested key login first, then disabled password login and root login in `/etc/ssh/sshd_config.d/00-hardening.conf`:
  `PasswordAuthentication no`, `KbdInteractiveAuthentication no`, `PermitRootLogin no`, `PubkeyAuthentication yes`.
  The file name starts with `00` so SSH reads it first.
- Verified with `sudo sshd -T`, and by testing that key login works while password-only login and root login fail with `Permission denied (publickey)`.

Evidence: `evidence/02-deploy-key-login.png`, `evidence/03-ssh-hardening.png`

## 2. Firewall (UFW)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw deny 8000/tcp
sudo ufw enable
```

Only SSH (22) and HTTP (80) are allowed in. Port 8000 is denied. UFW creates each rule for IPv4 and IPv6, which is why `(v6)` lines appear.

Evidence: `evidence/firewallconfigured.png`

## 3. The web application

`app/server.sh` is a small HTTP server written in Bash and socat. socat listens on `127.0.0.1:8000` and starts the script in `handle` mode for each connection. The script reads the request and replies `HTTP/1.1 200 OK` with the text `CloudPros Server Running`.

- Files are in `/opt/cloudpros`, owned by the system user `appuser` (no login shell).
- `cloudpros-app.service` runs the app as `appuser`, not root, and is enabled to start at boot.
- The app listens only on `127.0.0.1`, so it cannot be reached from outside.

Evidence: `evidence/application-response-systemd.png`
 
## 4. Nginx reverse proxy

Nginx listens on port 80 and forwards every request to `127.0.0.1:8000` (`proxy_pass`). Visitors only talk to Nginx. The config is at `/etc/nginx/conf.d/cloudpros.conf`

Evidence: `evidence/http-access-ss-ltnp.png`

### Note about WSL

On WSL, a request from inside Ubuntu to its own IP address stays inside the machine and does not pass through the firewall. The proof that port 8000 is not externally reachable is that the app is bound to `127.0.0.1:8000` (shown by `sudo ss -ltnp`), not `0.0.0.0:8000`.

## 5. Self-healing

`cloudpros-app.service` contains `Restart=always`. If the process stops unexpectedly, systemd starts it again. The service uses `exec socat ...`, so socat is the main process that systemd watches.

Test: I read the Main PID with `systemctl status`, ran `sudo kill -9 <PID>`, and checked again. The service came back as `active (running)` with a new PID within about 1 second.

| | PID |
| --- | --- |
| Before the kill | 129504 |
| After the kill | 130671 |

Evidence: `evidence/original-PID.png`, `evidence/PID-restarted.png`

## 6. Health monitoring

`/usr/local/bin/healthcheck.sh` requests `http://127.0.0.1:8000` with `curl`. If the HTTP status is not `200` (or there is no answer), it logs `FAIL` and runs `systemctl restart cloudpros-app`. Every run appends a timestamped line to `/var/log/cloudpros/healthcheck.log`.

`cloudpros-healthcheck.timer` (`OnCalendar=minutely`) starts `cloudpros-healthcheck.service` every minute. I used a systemd timer, not cron.

Evidence: `evidence/healthcheck-and-timer.png`

## 7. Backups

`/usr/local/bin/backup.sh` creates `/var/backups/cloudpros/cloudpros-YYYY-MM-DD.tar.gz` from `/opt/cloudpros`, then deletes backups older than seven days with `find ... -mtime +7 -delete`. The script stops on any error (`set -e`), so old backups are not deleted if a new backup fails. `cloudpros-backup.timer` runs it daily at midnight.

Extraction test: I extracted the backup into `/tmp/restore-test` and confirmed `cloudpros/server.sh` was restored.

Evidence: `evidence/backup-created.png`, `evidence/Backup-extracted.png`, `evidence/backup-retention-config.png` `evidence/backdated-files.png` evidence/`backupfiles-deleted-after7days.png`

## 8. Log rotation

`/etc/logrotate.d/cloudpros` rotates `/var/log/cloudpros/*.log` daily, keeps 7 rotated logs, compresses them, ignores missing files (`missingok`) and does not rotate empty files (`notifempty`). Validated with `sudo logrotate -d /etc/logrotate.d/cloudpros`.

Evidence:  `evidence/logrotate-config.png`

## How to reproduce

1. Install the tools: `sudo apt install -y nginx socat ufw openssh-server`.
2. Create the users, SSH key and SSH settings (section 1), then the firewall rules (section 2).
3. Create `appuser`, copy `app/server.sh` to `/opt/cloudpros/` (owner `appuser`), and install `systemd/cloudpros-app.service` into `/etc/systemd/system/`.
4. Copy `nginx/cloudpros.conf` to `/etc/nginx/conf.d/`, remove `/etc/nginx/sites-enabled/default`, run `sudo nginx -t` and reload Nginx.
5. Copy `scripts/healthcheck.sh` and `scripts/backup.sh` to `/usr/local/bin/` (mode 755), and create `/var/log/cloudpros`.
6. Install the health check and backup `.service` and `.timer` files, then `sudo systemctl daemon-reload` and `sudo systemctl enable --now cloudpros-app cloudpros-healthcheck.timer cloudpros-backup.timer`.
7. Copy `logrotate/cloudpros` to `/etc/logrotate.d/`.

## Challenges and how I solved them

- **Port 8000 rule:** my first firewall run showed `8000/tcp ALLOW IN`. I removed it with `sudo ufw delete allow 8000/tcp` and added `sudo ufw deny 8000/tcp`.
- **Wrong app folder:** I first copied the script to `/opt/app`, but the task requires `/opt/cloudpros`. I renamed the folder with `sudo mv /opt/app /opt/cloudpros` and checked the files with `diff`.
- **SSH tests from the wrong user:** inside the `deploy` session, `~/.ssh` is deploy's home, so my key was not found. I ran the tests from my own user.
- **Backup extraction:** the first extraction listing showed an empty folder, even though `tar -tzvf` listed `server.sh`. I removed the test folder and extracted again, and the file was restored.
- **WSL networking:** an external network test is not possible from inside WSL, so I used the `127.0.0.1:8000` binding as the equivalent evidence.

# Week 1: Self-Healing Linux Web Server (anjolaoluwa100)

A small Ubuntu web server that restarts its own app when it crashes, checks its own health every minute, backs itself up daily and keeps its logs tidy. Only SSH (22) and HTTP (80) are open to the outside.

## Setup
I used **Multipass** on my Mac to run an **Ubuntu 24.04** virtual machine named `cloudpros` (IP `192.168.252.3`), created with:

    multipass launch 24.04 --name cloudpros --cpus 1 --memory 1G --disk 10G

The "from outside" tests were run from my Mac's terminal against the VM's IP.

## What's in this folder
| Folder | Contents |
| --- | --- |
| `app/` | `server.sh`: Bash + socat web app on 127.0.0.1:8000 |
| `systemd/` | App service, health check service + timer, backup service + timer |
| `nginx/` | Reverse proxy config: port 80 to 127.0.0.1:8000 |
| `scripts/` | `healthcheck.sh`, `backup.sh` |
| `logrotate/` | Rotation rule for `/var/log/cloudpros/*.log` |
| `ssh/` | SSH hardening: keys only, no root login |
| `evidence/` | Command outputs proving each requirement |

## Securing the server
- Created a `deploy` user and added it to the `sudo` group.
- Put my Mac's public SSH key in `/home/deploy/.ssh/authorized_keys` and tested key login **before** changing anything.
- Added `/etc/ssh/sshd_config.d/00-hardening.conf` with `PasswordAuthentication no`, `KbdInteractiveAuthentication no` and `PermitRootLogin no`. The `00` prefix makes Ubuntu read it first, so these values win.
- Firewall (ufw): deny all incoming by default, allow outgoing, allow only `22/tcp` and `80/tcp`. Port 22 was allowed before enabling ufw so I wasn't locked out.

## How the app and Nginx work together
The app is `server.sh`. It starts **socat**, which listens on `127.0.0.1:8000` and, for every request, runs the same script to send back `HTTP/1.1 200 OK` with the text `CloudPros Server Running`. It runs as `appuser`, a system user with no login shell and no sudo rights.

Because the app binds to `127.0.0.1`, it only accepts connections from inside the VM. **Nginx** listens on port 80 and forwards every request to `http://127.0.0.1:8000` (`proxy_pass`). So visitors only ever talk to Nginx, and port 8000 is unreachable from outside. It's blocked twice: by the localhost bind and by ufw.

## How systemd recovers the app
`cloudpros-app.service` runs the app with `Restart=always` and `RestartSec=3`. Whenever the process dies for any reason, including `kill -9`, systemd starts it again after 3 seconds.

Test result (`evidence/01-recovery.txt`): PID **265362** was killed at 20:42:32 (`status=9/KILL`). systemd started a new process, PID **383952**, at 20:42:35, **3 seconds later**, and the service was `active (running)` again.

## How health monitoring works
`/usr/local/bin/healthcheck.sh` requests `http://127.0.0.1/` (through Nginx) with `curl -f` and a 5-second limit.
- If the request succeeds, it writes `<timestamp> OK site is up` to `/var/log/cloudpros/healthcheck.log`.
- If it fails, it writes a `DOWN` line and runs `systemctl restart cloudpros-app`.

`cloudpros-healthcheck.timer` runs it every minute (`OnCalendar=minutely`) through `cloudpros-healthcheck.service` (`Type=oneshot`). No cron is used.

## Backups and log rotation
`/usr/local/bin/backup.sh` creates `/var/backups/cloudpros/cloudpros-YYYY-MM-DD.tar.gz` from `/opt/cloudpros`, then deletes backups that are 7 or more days old (`find ... -mtime +6 -delete`). `cloudpros-backup.timer` runs it daily (`OnCalendar=daily`, `Persistent=true` so missed runs catch up).

Restore test: I extracted the backup into `/tmp/restore-test` and `server.sh` was there (`evidence/06-backups.txt`).

`/etc/logrotate.d/cloudpros` rotates `/var/log/cloudpros/*.log` **daily**, keeps **7**, **compresses** old logs, ignores missing (`missingok`) and empty (`notifempty`) logs, and uses `copytruncate` so the app can keep writing without a restart.

## How to reproduce this setup
On a fresh Ubuntu 24.04 machine:
1. Create `deploy`, add it to sudo, add your public key, test key login, then copy `ssh/00-hardening.conf` to `/etc/ssh/sshd_config.d/`, run `sudo sshd -t` and `sudo systemctl restart ssh`.
2. `sudo ufw default deny incoming`, `sudo ufw default allow outgoing`, `sudo ufw allow 22/tcp`, `sudo ufw allow 80/tcp`, `sudo ufw enable`.
3. `sudo apt install -y socat nginx`, `sudo useradd --system --no-create-home --shell /usr/sbin/nologin appuser`, `sudo mkdir -p /opt/cloudpros /var/log/cloudpros`. Copy `app/server.sh` to `/opt/cloudpros/` and run `chmod 755` on it.
4. Copy `scripts/*.sh` to `/usr/local/bin/` and run `chmod +x` on them.
5. Copy `systemd/*` to `/etc/systemd/system/`, run `sudo systemctl daemon-reload`, then `sudo systemctl enable --now cloudpros-app cloudpros-healthcheck.timer cloudpros-backup.timer`.
6. Copy `nginx/cloudpros.conf` to `/etc/nginx/sites-available/cloudpros`, link it into `sites-enabled`, remove `sites-enabled/default`, then `sudo nginx -t` and `sudo systemctl reload nginx`.
7. Copy `logrotate/cloudpros` to `/etc/logrotate.d/` and check it with `sudo logrotate -d /etc/logrotate.d/cloudpros`.

## Evidence
- [Recovery after kill -9](evidence/01-recovery.txt)
- [Firewall](evidence/02-firewall.txt)
- [Timers](evidence/03-timers.txt)
- [HTTP via Nginx, inside VM](evidence/04-http-via-nginx.txt)
- [Listening ports: app on 127.0.0.1:8000 only](evidence/05-listening-ports.txt)
- [Backups and restore test](evidence/06-backups.txt)
- [Logrotate check](evidence/07-logrotate-check.txt)
- [Health check log](evidence/08-healthcheck-log.txt)
- [HTTP 200 from my Mac](evidence/09-http-from-mac.txt)
- [Port 8000 times out from my Mac](evidence/10-port8000-from-mac.txt)

## Challenges and what I learned
- **Knowing which machine I was on.** I ran some commands on my Mac when I meant the VM. I learned to read the prompt first: `fatoluanjola@Mac` is my Mac and `ubuntu@cloudpros` is the VM.
- **How multipass shell gets in.** It uses SSH with a key Multipass creates itself. To use my own key for `deploy`, I had to add it to `authorized_keys` by hand.
- **Testing that passwords are refused.** Testing from inside the VM gave a confusing "broken pipe" once. Running `ssh -o PubkeyAuthentication=no` showed `Permission denied (publickey)`, which proved password login is off.
- **Timer would not start.** `systemctl enable --now cloudpros-healthcheck.timer` failed. `systemctl status` showed "unit cloudpros-healthcheck.service to trigger not loaded": I had skipped creating the `.service` file. I created it, ran `daemon-reload` and started the timer.
- I built this with step-by-step guidance from an AI assistant and ran and checked every step myself.

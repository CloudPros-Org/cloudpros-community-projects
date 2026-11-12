# ShopLite Server Toolkit

This submission configures a shared Linux operations workspace, installs Nginx,
and provides Bash tools for a system report and access-log analysis. It was
implemented and tested in Ubuntu 24.04.4 under WSL2.

## Environment and dependencies

The assignment uses Linux-specific features, so run these commands inside
Ubuntu 24.04 (not Windows PowerShell):

```bash
cat /etc/os-release
bash --version
sudo apt update
sudo apt install -y acl nginx cron logrotate shellcheck
```

In this environment, package downloads required forcing IPv4 because the WSL
network could not reach the Ubuntu mirrors over IPv6.

## Shared team directory

Create a group and two local accounts, then make `/srv/shoplite` private to the
group:

```bash
sudo groupadd shopops
sudo useradd --create-home --shell /bin/bash --groups shopops ava
sudo useradd --create-home --shell /bin/bash --groups shopops tom
sudo install -d --owner=root --group=shopops --mode=2770 /srv/shoplite
sudo setfacl --default --modify=u::rwx,g::rwx,m::rwx,o::--- /srv/shoplite
```

The setgid bit (`2` in mode `2770`) makes new content inherit the `shopops`
group. The default ACL gives new content group write access while denying all
access to other users. With a default ACL, the creating program's requested
mode can still restrict inherited permissions, so verify the effective ACL
for files created by the tools your team uses.

Inspect the setup:

```bash
id ava
id tom
ls -ld /srv/shoplite
getfacl /srv/shoplite
```

Test collaboration and isolation:

```bash
sudo -u ava bash -c 'printf "created by ava\n" > /srv/shoplite/team-test.txt'
sudo -u tom bash -c 'printf "edited by tom\n" >> /srv/shoplite/team-test.txt'
sudo cat /srv/shoplite/team-test.txt
sudo -u nobody ls /srv/shoplite
sudo rm /srv/shoplite/team-test.txt
```

The `nobody` command should fail with `Permission denied`. Remove the test file
after verifying the result.

## Nginx

Install and start Nginx:

```bash
sudo apt install -y nginx
sudo systemctl enable --now nginx
sudo systemctl status nginx --no-pager
curl -I http://127.0.0.1
```

Nginx should be active and return `HTTP/1.1 200 OK` for its default page.

## Install and run the scripts

From this submission directory:

```bash
sudo install -d --owner=root --group=adm --mode=2750 /var/log/shoplite
sudo install --owner=root --group=root --mode=0755 \
  scripts/sysreport.sh /usr/local/sbin/sysreport.sh
sudo install --owner=root --group=root --mode=0755 \
  scripts/logscan.sh /usr/local/bin/logscan.sh
```

`/var/log/shoplite` is owned by `root:adm` with mode `2750` and setgid enabled.
The report runs as root, and new report files inherit the `adm` group. The
script's `umask 027` creates reports with mode `0640`. Nginx access logs are
typically readable only by root and the `adm` group, so run the analyzer with
`sudo` unless the invoking account has suitable access.

### System report

Run the report as root so it can write under `/var/log/shoplite` and inspect
system journals:

```bash
sudo /usr/local/sbin/sysreport.sh
```

It prints each section to the terminal and saves the same output in a file
named `sysreport-<date>_<time>.log`. It covers hostname/uptime, load, memory,
filesystems above 80%, the five highest-memory processes, failed systemd units,
and failed SSH logins from the previous 24 hours. If SSH service or journal
data is unavailable, the report says so explicitly.

### Nginx access-log analyzer

```bash
sudo /usr/local/bin/logscan.sh
sudo /usr/local/bin/logscan.sh -n 3
sudo /usr/local/bin/logscan.sh -f /path/to/access.log -n 10
sudo /usr/local/bin/logscan.sh -s 404
sudo /usr/local/bin/logscan.sh -h
```

Options:

- `-f FILE`: input log (default `/var/log/nginx/access.log`)
- `-n N`: number of top IPs and URLs (default `5`, must be positive)
- `-s STATUS`: filter all metrics to one HTTP status code (`100`–`599`)
- `-h`: display help and exit successfully

Unknown options and invalid option values print usage to standard error and
exit `2`. A missing or unreadable input file exits `1`. The parser expects the
standard Nginx combined access-log format.

## Cron scheduling and cleanup

The supplied [`cron/shoplite`](cron/shoplite) file is a `/etc/cron.d` entry.
Install it with:

```bash
sudo install --owner=root --group=root --mode=0644 cron/shoplite /etc/cron.d/shoplite
sudo systemctl status cron --no-pager
sudo cat /etc/cron.d/shoplite
```

The system cron entry runs as root: the report runs every six hours, and a
separate daily job removes only timestamped ShopLite report files and their
numeric logrotate archives when their modification time is more than 14 days
old. It does not target arbitrary files in `/var/log/shoplite`.

The root account can write reports and remove old ones. Because this uses
`/etc/cron.d`, inspect that file with `sudo cat /etc/cron.d/shoplite`; it is not
stored in the output of `sudo crontab -l`.

## Log rotation

Install and validate the supplied [`logrotate/shoplite`](logrotate/shoplite)
rule:

```bash
sudo install --owner=root --group=root --mode=0644 \
  logrotate/shoplite /etc/logrotate.d/shoplite
sudo logrotate -d /etc/logrotate.d/shoplite
```

The rule matches `/var/log/shoplite/*.log`, rotates weekly, retains four
rotations per log, compresses them, skips missing or empty files, and creates
new files as `root:adm` mode `0640`.

Reports are timestamped, so each run creates a new pathname instead of
appending to one permanent file. Logrotate tracks and rotates each matching
pathname independently; its `rotate 4` setting is per pathname, not a global
cap on the number of reports. The separate 14-day cleanup bounds the age of
both timestamped reports and their numeric rotation archives.

## Validation and observed evidence

The following checks were run in Ubuntu 24.04.4 WSL2:

- **Accounts and directory:** `ava` and `tom` were members of `shopops`.
  `/srv/shoplite` was `drwxrws--- root:shopops` with default ACL entries
  granting group access and denying `other`.
- **Collaboration:** `ava` created a test file and `tom` appended to it. The
  resulting file was `-rw-rw---- ava:shopops`. The non-member `nobody` received
  `Permission denied` when listing the directory.
- **Nginx:** the service was active and `curl -I http://127.0.0.1` returned
  `HTTP/1.1 200 OK`.
- **System report:** the report printed successfully and was saved under
  `/var/log/shoplite` with mode `0640`, owner `root:adm`. In this WSL
  environment it reported the existing `getty@tty1.service` failure and
  checked `/var/log/auth.log`; no failed SSH logins were recorded in the last
  24 hours.
- **Access-log analyzer:** five requests returned `200` and three returned
  `404` in the analyzed real Nginx log; total requests were `8`, client IP
  `127.0.0.1` had `8`, and 5xx responses were `0`. Filtering to `404` showed
  only three requests; filtering to `200` showed only five.
- **Exit codes:** `logscan.sh -h` returned `0`; `-x`, `-n 0`, and `-s 600`
  returned `2`; a nonexistent input file returned `1`. `sysreport.sh -x`
  returned `2`.
- **ShellCheck:** `shellcheck -s bash scripts/sysreport.sh scripts/logscan.sh`
  completed without findings.
- **Cron:** the cron service was active. The installed `/etc/cron.d/shoplite`
  runs the report as root every six hours and performs selective cleanup daily.
- **Logrotate:** `logrotate -d /etc/logrotate.d/shoplite` parsed the rule and
  reported weekly rotation with four rotations. Debug mode did not rotate or
  delete files.
- **Cleanup selection:** a synthetic old timestamped report was removed while
  an unrelated old file was preserved.

Selected terminal results:

```text
$ id ava
uid=1001(ava) gid=1002(ava) groups=1002(ava),1001(shopops)
$ id tom
uid=1002(tom) gid=1003(tom) groups=1003(tom),1001(shopops)
$ stat -c '%A %U:%G %n' /srv/shoplite
drwxrws--- root:shopops /srv/shoplite

Created by ava
Edited by tom
ls: cannot open directory '/srv/shoplite': Permission denied

$ curl -I http://127.0.0.1
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)

Total requests: 8
200: 5
404: 3
127.0.0.1: 8
5xx responses: 0

$ logscan.sh -h
Exit status: 0
$ logscan.sh -x
Exit status: 2
$ logscan.sh -f /nonexistent/shoplite-logscan-test.log
Exit status: 1

$ shellcheck -s bash scripts/sysreport.sh scripts/logscan.sh
(no output; exit status 0)
```

The latest corrected report printed `Memory used: 13.4%`, included the
`getty@tty1.service` failure, and stated `No failed SSH login records found in
/var/log/auth.log in the last 24 hours.` Its output file was owned by
`root:adm` with mode `0640`. The WSL environment has no SSH service or SSH
journal data, so the authentication-log path was exercised and the journal
fallback was not.

The WSL instance showed `systemctl is-system-running` as `degraded` because
`getty@tty1.service` was failed before this work began. This was not changed.
The ShopLite report intentionally includes failed systemd units as required.

## Files

```text
.
├── .gitattributes
├── README.md
├── cron/shoplite
├── logrotate/shoplite
└── scripts/
    ├── logscan.sh
    └── sysreport.sh
```

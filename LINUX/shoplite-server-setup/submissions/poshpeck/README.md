# Week 3: ShopLite Server Toolkit

## 1. Project Overview

This project sets up a shared Ubuntu server environment for ShopLite, a small retail business.

The solution includes:

- A secure shared workspace for the `ava` and `tom` users.
- Nginx web server installation and verification.
- A Bash system reporting tool.
- A Bash Nginx access-log analyser.
- Automated report generation and cleanup using cron.
- Log rotation and compression using logrotate.

## 2. Environment

- Operating system: Ubuntu 24.04.5 LTS
- Environment: Ubuntu on Windows Subsystem for Linux 2 (WSL2)
- Shell: Bash
- Web server: Nginx
- Automation: cron
- Log management: logrotate
- Script validation: ShellCheck

## 3. Shared Directory and Permissions

### Configuration

Created the `shopops` group and added `ava` and `tom`:

```bash
sudo groupadd shopops
sudo useradd -m -s /bin/bash -G shopops ava
sudo useradd -m -s /bin/bash -G shopops tom
```

Created the shared directory:

```bash
sudo install -d -o root -g shopops -m 2770 /srv/shoplite
```

Configured default ACL permissions:

```bash
sudo setfacl -d -m u::rwx,g::rwx,m::rwx,o::--- /srv/shoplite
```

### Design decisions

- The `shopops` group allows both users to collaborate.
- Setgid (`2` in `2770`) ensures newly created files inherit the directory's group.
- The default ACL ensures group members receive the required permissions on newly created files and directories.
- Other users have no access to the shared directory.

### Verification

Tested that:
- Ava can create files.
- Tom can edit files created by Ava.
- Tom can create files that Ava can edit.
- A non-member receives `Permission denied` when attempting to access the directory.

## 4. Nginx Installation and Verification

Nginx was enabled and started using:

```bash
sudo systemctl enable --now nginx
```

Verification commands:

```bash
sudo systemctl status nginx --no-pager
systemctl is-active nginx
systemctl is-enabled nginx
curl -i http://localhost
```

The HTTP request returned status `200 OK`.

The configured local web page returned:

```text
CloudPros Server Running
```

## 5. System Reporting Tool: sysreport.sh

Location:

```text
scripts/sysreport.sh
```

The script generates a timestamped system report in:

```text
/var/log/shoplite/
```

Example filename:

```text
sysreport-2026-11-14_07-34-10.log
```

### Information collected

- Hostname and system uptime.
- System load average.
- Memory usage percentage.
- Filesystems above 80% utilisation.
- Top five memory-consuming processes.
- Failed systemd units.
- SSH authentication activity and failed login attempts within the last 24 hours, where available in the system journal.

The report is displayed in the terminal and saved to a timestamped file.

### Running the script

```bash
sudo ./LINUX/shoplite-server-setup/submissions/poshpeck/scripts/sysreport.sh
```

The script requires root privileges to access the protected report directory and relevant system information.

Unsupported arguments display usage information and return exit status `2`.

## 6. Nginx Access Log Analyser: logscan.sh

Location:

```text
scripts/logscan.sh
```

The script analyses Nginx combined access-log files.

### Information reported

- Total requests.
- Requests grouped by HTTP status code.
- Top N client IP addresses.
- Top N requested URLs.
- Total 5xx server errors.

### Command-line options

| Option | Description | Default |
|---|---|---|
| `-f FILE` | Specify the access-log file | `/var/log/nginx/access.log` |
| `-n N` | Number of top IP addresses and URLs | `5` |
| `-s STATUS` | Filter analysis by HTTP status | No filter |
| `-h` | Display usage information | N/A |

### Usage examples

Analyse the default Nginx access log:

```bash
./LINUX/shoplite-server-setup/submissions/poshpeck/scripts/logscan.sh
```

Display the top three IP addresses and URLs:

```bash
./LINUX/shoplite-server-setup/submissions/poshpeck/scripts/logscan.sh -n 3
```

Use a custom log file:

```bash
./LINUX/shoplite-server-setup/submissions/poshpeck/scripts/logscan.sh -f /tmp/shoplite-test-access.log
```

Filter requests by HTTP status:

```bash
./LINUX/shoplite-server-setup/submissions/poshpeck/scripts/logscan.sh -s 500
```

Display help:

```bash
./LINUX/shoplite-server-setup/submissions/poshpeck/scripts/logscan.sh -h
```

### Error handling

- Invalid or unsupported options return exit status `2`.
- Invalid `-n` or `-s` values return exit status `2`.
- Missing or unreadable input files return exit status `1`.
- The help option returns exit status `0`.

Testing included actual Nginx requests and a temporary test log containing successful responses, client errors and server errors.

## 7. Automated Report Generation and Cleanup

Cron configuration:

```text
cron/shoplite.cron
```

Installed system-wide at:

```text
/etc/cron.d/shoplite
```

### Installation

From the ShopLite submission directory, install the scripts and cron configuration:

```bash
sudo install -d -o root -g root -m 755 /usr/local/sbin/shoplite

sudo install -o root -g root -m 755 \
scripts/sysreport.sh \
/usr/local/sbin/shoplite/sysreport.sh

sudo install -o root -g root -m 755 \
scripts/cleanup-reports.sh \
/usr/local/sbin/shoplite/cleanup-reports.sh

sudo install -o root -g root -m 644 \
cron/shoplite.cron \
/etc/cron.d/shoplite
```

### Scheduled tasks

| Schedule | Task | Account |
|---|---|---|
| Every six hours | Generate system report | root |
| Daily at 02:15 | Remove reports older than 14 days | root |

Cron configuration:

```cron
0 */6 * * * root /usr/local/sbin/shoplite/sysreport.sh

15 2 * * * root /usr/local/sbin/shoplite/cleanup-reports.sh
```

Root runs both jobs because the report directory is protected and owned by root.

### Cleanup script

Location:

```text
scripts/cleanup-reports.sh
```

The cleanup script selectively removes regular files matching:

```text
sysreport-*.log*
```

It removes matching files older than 14 days from `/var/log/shoplite/`.

The wildcard also matches rotated report archives, including files ending in `.log.1` and `.log.2.gz`.

The script uses `find` with the following restrictions:

- `-maxdepth 1`: only checks the report directory itself.
- `-type f`: only targets regular files.
- `-mmin +20160`: selects files older than 14 days.
- `-delete`: removes matching files.

This ensures that recent reports and unrelated files are preserved.

The cleanup script was tested using temporary files representing old reports, rotated archives, recent reports and unrelated files. The test confirmed that only the three old report files were deleted.

Evidence: `evidence/cleanup-verification.txt`.

## 8. Logrotate Configuration

Configuration file:

```text
logrotate/shoplite
```

Installed system-wide at:

```text
/etc/logrotate.d/shoplite
```

Configuration:

```text
/var/log/shoplite/*.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0640 root root
}
```

### Configuration explanation

- `weekly`: rotate eligible log files weekly.
- `rotate 4`: retain up to four rotated versions of each log.
- `compress`: compress rotated files immediately.
- `missingok`: do not report an error if a matching file is missing.
- `notifempty`: skip empty log files.
- `create 0640 root root`: create replacement files with restricted permissions and root ownership.

### Interaction with timestamped reports

Because the system report creates a separate timestamped file each time, logrotate treats each matching report as an individual log file.

The cleanup script removes matching original reports and rotated archives older than 14 days. This includes files ending in `.log`, `.log.1` and `.log.2.gz`.

Logrotate manages weekly rotation and compression, while the cleanup script enforces the 14-day retention period across both original reports and their rotated archives.

### Verification

```bash
sudo logrotate -d /etc/logrotate.d/shoplite
```

Debug mode checks the configuration without performing rotation.

## 9. Script Validation

Both Bash scripts were checked using:

```bash
bash -n scripts/sysreport.sh
bash -n scripts/logscan.sh
shellcheck scripts/sysreport.sh
shellcheck scripts/logscan.sh
```

The cleanup script was also checked using Bash syntax validation and ShellCheck.

## 10. Evidence

The `evidence/` directory contains terminal output demonstrating the project configuration and tests.

| Evidence file | What it demonstrates |
|---|---|
| `nginx-verification.txt` | Nginx service and HTTP response |
| `sysreport-verification.txt` | System report execution and output |
| `logscan-verification.txt` | Log analysis and error handling |
| `cron-verification.txt` | Cron service and installed schedules |
| `logrotate-verification.txt` | Logrotate configuration and debug test |
| `permissions-verification.txt` | Group membership, directory ACL and collaboration tests |
| `cleanup-verification.txt` | Verification of 14-day report and archive cleanup |



## 11. Conclusion

This project demonstrates Linux user and group administration, shared directory permissions, ACLs, web server management, Bash scripting, log analysis, cron scheduling and log rotation.

It also provides practical experience with troubleshooting and validating Linux administration tasks in an Ubuntu WSL2 environment.

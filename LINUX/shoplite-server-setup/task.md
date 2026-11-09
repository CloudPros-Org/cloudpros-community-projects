# CloudPros Weekly Community Project

## Week 3: ShopLite Server Toolkit

**Deadline:** Sunday, 15 November 2026, 11:59 PM (GMT)  
**Submission:** GitHub Pull Request  
**Difficulty:** Linux administration and Bash scripting

---

## The Scenario

ShopLite has its first Ubuntu server, and you're the engineer on call. Set up secure shared access for the team, install Nginx, and build two Bash tools: a system report and an Nginx access-log analyser. Schedule reporting and manage the resulting logs.

**You can do this for free on your own computer.** Windows users can run Ubuntu 24.04 in **WSL2**; Mac users can work from **macOS Terminal** and use an **Ubuntu 24.04 virtual machine** (such as Multipass) for Linux-specific tasks; Ubuntu Linux users can work directly in their terminal. You do not need a cloud server. **macOS Terminal alone cannot run Ubuntu-specific tools such as apt, systemd/journalctl or Linux ACLs**, so use an Ubuntu VM when testing these requirements. See the environment guide below.

## Tools

Ubuntu 24.04, Bash, Nginx, cron, journalctl, logrotate, shellcheck, ACL utilities, Git and GitHub.

## What You Must Build

### 1. Shared ShopLite directory and permissions

- Create a group called `shopops` and users `ava` and `tom`.
- Create the shared directory `/srv/shoplite`.
- Both users must be able to create files there **and edit each other's files**, including newly created files.
- Users outside the group must not be able to list or access the directory.
- Use appropriate ownership, group permissions, setgid and/or default ACLs so the behaviour works for new files too.
- Test as both group members and a non-member. Do not rely on making the directory world-writable.

### 2. Install Nginx

Install Nginx with `apt`, start it and serve the default page. Show that the service is running and HTTP requests succeed.

### 3. Write `sysreport.sh`

The script must print **to the screen and to a timestamped file** under `/var/log/shoplite/`, named `sysreport-<date>_<time>.log`. Include:

- Hostname and uptime
- Load average
- Memory usage percentage
- Any filesystem over 80% usage (clearly report if none)
- Top five processes by memory usage
- Failed systemd units
- Failed SSH logins within the last 24 hours (using available authentication logs/journal; explain if no SSH service/log data is present)

Use clear section headings so another engineer can read the report.

### 4. Write `logscan.sh`

Analyse an Nginx-style access log and report:

- Total requests
- Counts by HTTP status code
- Top N client IP addresses
- Top N requested URLs
- Number of 5xx responses

Implement these options:

| Option | Behaviour |
| --- | --- |
| `-f FILE` | Input log file; default `/var/log/nginx/access.log` |
| `-n N` | Number of top results; default `5` |
| `-s STATUS` | Only include requests with that HTTP status in the analysis |
| `-h` | Show usage/help |

For `-s`, apply the filter consistently to the displayed totals, rankings and 5xx count. Validate `-n` as a positive integer and `-s` as an HTTP status code. Support standard Nginx combined access-log format. Use actual requests to Nginx to generate test data.

### 5. Requirements for both Bash scripts

- Start with `set -euo pipefail`.
- Organise logic into functions.
- Include a `log()` function that adds timestamps to its messages.
- Invalid/unknown options print usage to **stderr** and exit with status **2**.
- A missing required input file exits with status **1**.
- `shellcheck` must report no findings.

**Clarification:** `sysreport.sh` does not need command-line options, but any unsupported option must produce the same usage/error behaviour. `logscan.sh -h` is successful and should exit 0. A valid `-f` path that does not exist must exit 1.

### 6. Schedule reporting and cleanup

Configure cron to run `sysreport.sh` every six hours. Add a separate cleanup job that removes report files **older than 14 days** from `/var/log/shoplite/`. Make the cleanup selective: do not delete unrelated files. Document which account runs the jobs and ensure it has the necessary permissions.

### 7. Configure logrotate

Create a logrotate rule for `/var/log/shoplite/*.log` that:

- Rotates weekly
- Keeps four rotations
- Compresses rotated logs

Account for the fact that `sysreport.sh` creates **timestamped files**, rather than appending to one fixed filename. Explain how your rotation rule applies to these files and how the 14-day cleanup interacts with rotation. Include appropriate `missingok`/`notifempty` behaviour and safe ownership/permissions.

---

## Evidence Required

Include terminal outputs or screenshots, with short explanations, in your submission README or an `evidence/` folder.

1. **Users and permissions:** `id ava`, `id tom`, `ls -ld /srv/shoplite`, `getfacl /srv/shoplite`. Show `tom` editing a file created by `ava`, and a **non-member** receiving `Permission denied` when attempting to list the directory. (The slide's names `tunde` and `ada` are illustrative; use the required `ava` and `tom` consistently.)
2. **Nginx:** Show the service running and the default page responding to HTTP.
3. **System report:** Include output from `sysreport.sh`, both on screen and in a correctly named log file.
4. **Log analyser:** Include `logscan.sh -n 3` on a real Nginx access log, showing request totals, codes, IPs, URLs and 5xx counts. Generate requests if the log is initially empty.
5. **Error handling:** Show `logscan.sh -x` printing usage and `echo $?` showing `2`; also demonstrate a missing input file returning `1`.
6. **Automation and validation:** Show `sudo crontab -l` (or the relevant account's crontab), `sudo logrotate -d /etc/logrotate.d/shoplite`, and a clean `shellcheck` run for **both** scripts.

**Note:** The original slide uses inconsistent example names (`tunde`/`ada`); this written task is authoritative: use **ava** and **tom**.

## Stretch Challenge (Optional)

- Add `-j` to `logscan.sh` to output valid JSON.
- Make `sysreport.sh` send a notification to a Discord webhook when it detects a problem. Never commit webhook URLs or tokens; load secrets from an ignored environment file. Do not send real alerts during ordinary testing.

---

## Suggested Submission Layout

```text
LINUX/shoplite-server-setup/
├── task.md
├── README.md
└── submissions/
    └── <your-github-handle>/
        ├── README.md
        ├── scripts/
        │   ├── sysreport.sh
        │   └── logscan.sh
        ├── cron/
        │   └── shoplite.cron
        ├── logrotate/
        │   └── shoplite
        └── evidence/
```

You may organise files differently **inside your own submission folder**. Include the configuration needed to reproduce user/group permissions and Nginx setup, either as scripts or documented commands. Do not commit secrets, passwords or private keys.

## How to Submit

1. Fork `CloudPros-Org/cloudpros-community-projects` and create a working branch in your fork.
2. Put your files under `LINUX/shoplite-server-setup/submissions/<your-github-handle>/`. **Do not edit other people's submissions or the task brief.**
3. Include a README explaining setup, design decisions, how to run and test both scripts, cron/logrotate configuration, proof of requirements and any troubleshooting.
4. Open a PR into **`week3-shoplite-server-setup`** in the CloudPros repository, **not `main`**.
5. Title your PR `[Week 3] ShopLite Server Toolkit - Your Name`.
6. Describe what you built, how you tested it, what you learnt and anything you struggled with.
7. Request review from **@joincloudpros**, or mention that account in a PR comment if you cannot request it directly.
8. **Leave your PR open. Do not merge your own submission.**

## Submission Checklist

- [ ] Ubuntu 24.04 environment documented
- [ ] `shopops`, `ava`, `tom` and private shared directory work as required
- [ ] Nginx installed via apt and serving its default page
- [ ] `sysreport.sh` produces all required fields and writes timestamped logs
- [ ] `logscan.sh` reports all requested metrics and supports `-f`, `-n`, `-s`, `-h`
- [ ] Both scripts use strict Bash mode, functions, timestamped `log()` and correct exit codes
- [ ] Both scripts pass shellcheck
- [ ] Cron runs the report every six hours and removes reports older than 14 days
- [ ] Weekly logrotate rule retains four compressed rotations
- [ ] README and requested evidence included
- [ ] PR targets `week3-shoplite-server-setup` and is left open

---

## Environment Setup Guide

**Windows:** Open PowerShell as administrator, run `wsl --install -d Ubuntu-24.04`, then launch Ubuntu. Use its terminal (or VS Code's WSL terminal) for the work. See https://learn.microsoft.com/windows/wsl/install. For systemd/journalctl, ensure WSL systemd support is enabled. Nginx and Linux permissions must be tested inside Ubuntu.

**macOS:** Use the normal Mac **Terminal** to edit scripts, run Git and connect to Ubuntu. For this challenge's `apt`, Linux ACLs, `journalctl` and other Ubuntu-specific behaviour, run Ubuntu 24.04 in Multipass or another VM. For example: `multipass launch 24.04 --name shoplite` then `multipass shell shoplite`. See https://canonical.com/multipass.

**Linux:** If you use Ubuntu 24.04, work directly in Terminal. On other Linux distributions, an Ubuntu 24.04 VM is recommended for consistent results.

**Check your environment:**

```bash
cat /etc/os-release
bash --version
command -v systemctl
sudo apt update
sudo apt install -y nginx acl cron logrotate shellcheck
```

For testing SSH login failures, you may need an SSH service and authentication logs. Avoid deliberately exposing SSH to the internet. Document any WSL/VM differences in your README.

## Getting Help

Ask in the CloudPros **Ask for Help** group. Share the command, expected result, actual output and what you tried.

The goal is not just to make the scripts run. Understand Linux permissions, log formats, error handling and how the scheduled tools would help someone on call.

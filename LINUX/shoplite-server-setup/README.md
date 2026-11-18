# ShopLite Server Toolkit

## Overview

This project implements a basic Linux administration toolkit for ShopLite on Ubuntu 24.04.

It provides secure shared directory access, Nginx installation, system health reporting, Nginx access-log analysis, scheduled report generation, and log rotation.

## Components

- `setup.sh` — installs dependencies, creates the required users and group, configures permissions, installs scripts, and registers cron and logrotate configuration.
- `scripts/sysreport.sh` — generates a timestamped system report and displays it on screen.
- `scripts/logscan.sh` — analyses Nginx access logs, including request totals, HTTP status counts, top client IPs, top URLs, and 5xx responses.
- `cron/shoplite.cron` — schedules reporting every six hours and selectively cleans up old report files.
- `logrotate/shoplite` — configures weekly rotation, four rotations, compression, and safe ownership.
- `evidence/` — contains captured test results and validation output.

## Requirements

- Ubuntu 24.04
- Bash
- Nginx
- cron
- logrotate
- ACL utilities
- ShellCheck
- Git

## Setup

From this submission directory, run:

```bash
sudo bash ./setup.sh
```

Open a new login session after setup so the new supplementary group membership is applied.

## Usage

Generate a system report:

```bash
sudo /usr/local/sbin/sysreport.sh
```

Analyse the default Nginx access log:

```bash
sudo /usr/local/sbin/logscan.sh -n 3
```

Filter by HTTP status:

```bash
sudo /usr/local/sbin/logscan.sh -s 404
```

Analyse another file:

```bash
sudo /usr/local/sbin/logscan.sh -f /path/to/access.log
```

Display help:

```bash
sudo /usr/local/sbin/logscan.sh -h
```

## Permissions design

The `shopops` group provides shared access for `ava` and `tom`. The `/srv/shoplite` directory uses group ownership, setgid, and a default ACL. Access for users outside the group is denied.

## Scheduling and log management

The root cron configuration runs system reporting every six hours. A separate job removes matching original ShopLite report files older than 14 days.

Logrotate checks `/var/log/shoplite/*.log` weekly and retains four rotations. Because each report has its own timestamped filename, logrotate tracks individual files rather than combining all reports into a single file. The cleanup job operates separately and does not delete unrelated files or compressed archives.

## Validation

See the `evidence/` directory for captured results covering:

- User and group membership
- Shared-directory permissions
- Nginx HTTP responses
- System report output
- Log analysis and error handling
- ShellCheck
- Cron and logrotate configuration

## Environment notes

Record the actual Ubuntu version and any WSL-specific limitations observed during testing. Systemd status and SSH authentication logs depend on the environment and available services.

## Lessons learned

This project demonstrates Linux permissions and ACLs, Bash argument validation, log parsing, error handling, cron scheduling, logrotate configuration, and evidence-based testing.
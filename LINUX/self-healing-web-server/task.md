
# CloudPros Weekly Community Project

## Self-Healing Linux Web Server

**Deadline:** Sunday Nov 1st 2026, 11:59 PM (GMT)  
**Submission:** GitHub Pull Request  
**Operating System:** Ubuntu 24.04

---

## Table of Contents

- [CloudPros Weekly Community Project](#cloudpros-weekly-community-project)
  - [Self-Healing Linux Web Server](#self-healing-linux-web-server)
  - [Table of Contents](#table-of-contents)
  - [Problem Statement](#problem-statement)
  - [Project Objectives](#project-objectives)
  - [Tools and Technologies](#tools-and-technologies)
  - [Project Requirements](#project-requirements)
    - [Secure the Server](#secure-the-server)
    - [Configure the Firewall](#configure-the-firewall)
    - [Deploy a Web Service](#deploy-a-web-service)
    - [Configure Nginx](#configure-nginx)
    - [Implement Self-Healing](#implement-self-healing)
    - [Implement Health Monitoring](#implement-health-monitoring)
    - [Configure Automated Backups](#configure-automated-backups)
    - [Configure Log Rotation](#configure-log-rotation)
  - [Evidence Required](#evidence-required)
    - [Application Recovery](#application-recovery)
    - [Firewall Configuration](#firewall-configuration)
    - [systemd Timers](#systemd-timers)
    - [External Access](#external-access)
    - [Backups and Log Rotation](#backups-and-log-rotation)
    - [GitHub Repository](#github-repository)
  - [Stretch Challenge](#stretch-challenge)
  - [Submission Instructions](#submission-instructions)
    - [Prepare Your Repository](#prepare-your-repository)
    - [Create a Pull Request](#create-a-pull-request)
    - [Pull Request Title](#pull-request-title)
    - [Pull Request Description](#pull-request-description)
    - [Request a Review](#request-a-review)
    - [Do Not Merge](#do-not-merge)
  - [Submission Checklist](#submission-checklist)
- [System Setup Guide](#system-setup-guide)
  - [Visual Studio Code](#visual-studio-code)
  - [Windows Users](#windows-users)
    - [Install WSL and Ubuntu](#install-wsl-and-ubuntu)
    - [Configure VS Code for WSL](#configure-vs-code-for-wsl)
    - [Important: Use the Ubuntu Terminal](#important-use-the-ubuntu-terminal)
  - [macOS Users](#macos-users)
    - [Prepare Your Environment](#prepare-your-environment)
    - [Install Multipass](#install-multipass)
  - [Linux Users](#linux-users)
    - [Prepare Your Environment](#prepare-your-environment-1)
  - [Verify Your Environment](#verify-your-environment)
    - [Check Your Operating System](#check-your-operating-system)
    - [Check Your Shell](#check-your-shell)
    - [Check systemd](#check-systemd)
    - [Update Your Packages](#update-your-packages)
    - [Install Basic Tools](#install-basic-tools)
    - [Configure Git](#configure-git)
    - [Confirm Git Installation](#confirm-git-installation)
  - [Getting Help](#getting-help)
  - [Final Note](#final-note)

---

## Problem Statement

Imagine you're responsible for managing your company's web server.

Everything works perfectly during the day, but at 3 AM, the application suddenly crashes. Nobody is available to investigate or restart it, leaving the website unavailable until someone notices the problem.

Your challenge is to build a **self-healing Linux web server** that can automatically recover from application failures without manual intervention.

The server must be secure, accessible over HTTP, and configured to handle automatic recovery, health monitoring, backups, and log management.

By the end of this project, you should have a working Linux server that can recover from unexpected failures and demonstrate how its components work together.

---

## Project Objectives

By completing this project, you should gain practical experience with:

- Linux server administration
- SSH authentication and security
- Firewall configuration
- Bash scripting
- systemd services and timers
- Nginx reverse proxy configuration
- Automated application recovery
- Health monitoring
- Automated backups and retention
- Log rotation
- Git and GitHub collaboration

The focus is on understanding how these tools work together to create a reliable and maintainable server.

---

## Tools and Technologies

You will use the following:

| Tool | Purpose |
|------|---------|
| Ubuntu 24.04 | Linux operating system |
| Bash | Scripting and automation |
| systemd | Service management and scheduling |
| Nginx | Reverse proxy |
| UFW | Firewall configuration |
| socat | Lightweight HTTP service |
| logrotate | Log management |
| Git | Version control |
| GitHub | Project submission |
| VS Code | Code editing |

No Python, Flask, or application framework is required.

---

## Project Requirements

Complete all the requirements below.

### Secure the Server

Configure your Ubuntu server for secure administrative access.

**Requirements:**

- Create a user named `deploy`.
- Grant the user sudo privileges.
- Configure SSH key-based authentication.
- Disable SSH password authentication.
- Disable direct root SSH login.

**Expected Outcome:**

The `deploy` user can securely access the server using SSH keys, while password-based authentication and direct root SSH access are disabled.

> **Important:** Confirm that SSH key authentication works before disabling password authentication to avoid locking yourself out.

### Configure the Firewall

Install and configure UFW to protect your server.

**Requirements:**

- Deny incoming traffic by default.
- Allow incoming SSH traffic on port 22.
- Allow incoming HTTP traffic on port 80.
- Block unnecessary incoming connections.
- Ensure port 8000 is not publicly accessible.
- Enable UFW.

**Expected Outcome:**

Only the required services are accessible from outside the server.

### Deploy a Web Service

Create a simple HTTP service using Bash and a lightweight networking utility such as `socat`.

The service should display a basic response:

```text
CloudPros Server Running
```

**Requirements:**

- Create a dedicated system user named `appuser`.
- Store the service files in `/opt/cloudpros`.
- Configure the service to listen on `127.0.0.1:8000`.
- Create a systemd service named `cloudpros-app`.
- Run the service as `appuser`, not root.
- Enable the service to start automatically on boot.
- Return a valid HTTP `200 OK` response.

**Expected Outcome:**

The application runs successfully under systemd and is accessible locally on port 8000.

### Configure Nginx

Install and configure Nginx as a reverse proxy.

**Requirements:**

- Configure Nginx to listen on port 80.
- Forward incoming HTTP requests to `127.0.0.1:8000`.
- Ensure the application is accessible through Nginx.
- Ensure port 8000 is not externally accessible.

**Expected Outcome:**

Accessing the server through port 80 displays the application response.

Direct external connections to port 8000 must fail.

### Implement Self-Healing

Configure automatic recovery using systemd.

**Requirements:**

- Configure `cloudpros-app` to restart automatically after an unexpected failure.
- Ensure the application recovers within 10 seconds.
- Terminating the application process using `kill -9` must trigger automatic recovery.
- The restarted application must have a different process ID.

**Expected Outcome:**

The application automatically restarts after an unexpected crash without manual intervention.

### Implement Health Monitoring

Create a Bash script at:

```text
/usr/local/bin/healthcheck.sh
```

**Requirements:**

- Check whether the application responds successfully over HTTP.
- Detect failed or unhealthy responses.
- Restart `cloudpros-app` when the application is unhealthy.
- Record timestamped health check results in a log file.
- Run the script every minute using a systemd timer.

**Do not use cron.**

**Expected Outcome:**

The health check runs automatically every minute and attempts to recover the application when it becomes unhealthy.

### Configure Automated Backups

Implement automated backups for your application directory.

**Requirements:**

- Back up `/opt/cloudpros` daily.
- Store backups in `/var/backups/cloudpros/`.
- Include the date in each backup filename.
- Automatically remove backups older than seven days.
- Use a systemd timer to schedule the backups.
- Ensure backup files can be successfully extracted.

**Example:**

```text
/var/backups/cloudpros/
├── cloudpros-2026-10-26.tar.gz
├── cloudpros-2026-10-27.tar.gz
└── cloudpros-2026-10-28.tar.gz
```

**Expected Outcome:**

The application directory is backed up daily, and backups older than seven days are automatically removed.

### Configure Log Rotation

Configure logrotate for application logs stored in:

```text
/var/log/cloudpros/
```

**Requirements:**

- Create a logrotate configuration for `/var/log/cloudpros/*.log`.
- Rotate logs daily.
- Retain seven rotated logs.
- Compress rotated logs.
- Handle missing or empty log files gracefully.

**Expected Outcome:**

Application logs are managed automatically to prevent uncontrolled growth.

---

## Evidence Required

Your submission must include evidence demonstrating that your implementation meets the project requirements.

Screenshots, terminal outputs, and explanations should be included in your repository's README or linked from an `evidence/` directory.

### Application Recovery

Show the application status before and after terminating its process.

Check the service:

```bash
sudo systemctl status cloudpros-app
```

Identify the main application PID, then terminate it:

```bash
sudo kill -9 <APP_PID>
```

Check the service again:

```bash
sudo systemctl status cloudpros-app
```

Your evidence must demonstrate:

- The original process ID.
- The new process ID.
- The service returning to an active state.
- Recovery within 10 seconds.

### Firewall Configuration

Run:

```bash
sudo ufw status verbose
```

Your evidence should show that only the required incoming ports are allowed.

### systemd Timers

Run:

```bash
sudo systemctl list-timers --all | grep cloudpros
```

Your evidence must show the configured health check and backup timers.

### External Access

From outside the Ubuntu server, verify that the application is accessible through Nginx.

```bash
curl -I http://<SERVER_IP>
```

Replace `<SERVER_IP>` with your server's actual reachable IP address.

**Expected Result:**

```text
HTTP/1.1 200 OK
```

Next, verify that port 8000 is not externally accessible:

```bash
curl --connect-timeout 5 http://<SERVER_IP>:8000
```

**Expected Result:**

The connection must fail.

> These tests must be performed from outside the Ubuntu server. If you're using WSL or a local VM, use a separate reachable network context and document how you verified the isolation.

### Backups and Log Rotation

Include evidence showing:

- Successful backup creation.
- Backup filenames containing dates.
- A successful backup extraction test.
- The configured backup retention policy.
- A valid logrotate configuration.

You can test your logrotate configuration using:

```bash
sudo logrotate -d /etc/logrotate.d/cloudpros
```

### GitHub Repository

Your repository must contain:

- Application files.
- Bash scripts.
- systemd service and timer files.
- Nginx configuration.
- Logrotate configuration.
- A README documenting your implementation.
- Evidence demonstrating that the requirements have been met.

Do not commit passwords, private SSH keys, access tokens, or other sensitive information.

---

## Stretch Challenge

Create a Bash script named:

```text
setup.sh
```

The script should automatically configure a fresh Ubuntu 24.04 server to meet the project requirements.

It should automate:

- Package installation.
- User creation.
- Firewall configuration.
- Application deployment.
- systemd service configuration.
- Nginx configuration.
- Health monitoring.
- Automated backups.
- Log rotation.

**Additional Requirement:**

Your script must be **idempotent**.

This means running the script multiple times should not break existing configurations, create duplicate resources, or cause unnecessary failures.

Document any manual prerequisites, including SSH key provisioning.

---

## Submission Instructions

All submissions must be made through a GitHub Pull Request.

### Prepare Your Repository

Your repository must contain your implementation files, scripts, configurations, README, and supporting evidence.

A suggested structure is:

```text
linux-self-healing-web-server/
├── README.md
├── app/
│   └── server.sh
├── systemd/
│   ├── cloudpros-app.service
│   ├── cloudpros-healthcheck.service
│   ├── cloudpros-healthcheck.timer
│   ├── cloudpros-backup.service
│   └── cloudpros-backup.timer
├── nginx/
│   └── cloudpros.conf
├── scripts/
│   ├── healthcheck.sh
│   └── backup.sh
├── logrotate/
│   └── cloudpros
├── evidence/
│   ├── service-status.png
│   ├── firewall-status.png
│   ├── recovery-test.png
│   ├── timer-status.png
│   └── external-access-test.png
└── setup.sh
```

The structure is a recommendation, not a strict requirement.

`setup.sh` is optional unless you attempt the stretch challenge.

### Create a Pull Request

Push your implementation to GitHub and create a Pull Request targeting the following branch:

```text
linux-self-healing-web-server-submissions
```

**Important:** Your Pull Request must target this branch, not `main`.

If you're working from a fork, select the CloudPros repository and the required submissions branch as the base.

### Pull Request Title

Use the following format:

```text
[Week 1] Self-Healing Linux Web Server - Your Name
```

### Pull Request Description

Include:

- A summary of your implementation.
- The requirements you completed.
- How you tested your solution.
- A link to your README and supporting evidence.
- Any challenges you encountered.
- Whether you completed the stretch challenge.

### Request a Review

Add the following GitHub account as a reviewer:

**@joincloudpros**

If GitHub does not allow you to request a review from this account, mention `@joincloudpros` in a Pull Request comment.

### Do Not Merge

**Do not merge your Pull Request.**

Leave it open for review.

The CloudPros team will review submissions and provide feedback where appropriate.

---

## Submission Checklist

Before submitting, confirm that:

- [ ] SSH key-based authentication is configured.
- [ ] SSH password authentication is disabled.
- [ ] Root SSH login is disabled.
- [ ] UFW is configured correctly.
- [ ] The web service runs under `appuser`.
- [ ] Nginx forwards requests to the application.
- [ ] Port 8000 is not externally accessible.
- [ ] The application automatically recovers from crashes.
- [ ] The health check runs every minute.
- [ ] Automated daily backups are configured.
- [ ] Backup retention is configured.
- [ ] Log rotation is configured.
- [ ] Your README explains the implementation.
- [ ] Required evidence is included.
- [ ] No secrets or credentials are committed.
- [ ] Your PR targets `linux-self-healing-web-server-submissions`.
- [ ] `joincloudpros` has been requested as a reviewer or mentioned.
- [ ] Your Pull Request remains open and unmerged.

---

# System Setup Guide

This section explains how to prepare your development environment before starting the project.

You will need access to an Ubuntu 24.04 environment, a terminal, and a code editor.

The setup depends on your operating system.

## Visual Studio Code

We recommend using **Visual Studio Code (VS Code)** to write Bash scripts, manage configuration files, and work with GitHub.

If you don't already have VS Code installed, download it from:

https://code.visualstudio.com/

VS Code is available for Windows, macOS, and Linux.

Once installed, you can use its integrated terminal to run commands directly from your project workspace.

VS Code is recommended but not mandatory. You may use another editor if you prefer.

---

## Windows Users

If you're using Windows, install **Windows Subsystem for Linux (WSL)**.

WSL allows you to run an Ubuntu environment directly on Windows without installing a separate operating system.

### Install WSL and Ubuntu

Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu-24.04
```

Restart your computer if prompted.

After installation:

1. Launch Ubuntu from the Start menu.
2. Create your Linux username and password.
3. Complete the initial Ubuntu setup.
4. Update your packages:

```bash
sudo apt update && sudo apt upgrade -y
```

### Configure VS Code for WSL

1. Open VS Code.
2. Go to Extensions.
3. Search for **WSL** by Microsoft.
4. Install the extension.
5. Open your Ubuntu terminal.
6. Navigate to your project directory.

For example:

```bash
mkdir -p ~/cloudpros-project
cd ~/cloudpros-project
```

Then run:

```bash
code .
```

This opens your project in VS Code using the WSL environment.

### Important: Use the Ubuntu Terminal

When working in VS Code, ensure you're using the **Ubuntu (WSL) terminal**, not PowerShell or Command Prompt.

You can check your environment using:

```bash
uname -a
```

You should see Linux in the output.

You can also run:

```bash
cat /etc/os-release
```

This should identify your Ubuntu installation.

**Note:** WSL is suitable for development and many local tests. Some networking and SSH scenarios may require additional configuration or a separate Ubuntu VM.

Official WSL documentation:

https://learn.microsoft.com/en-us/windows/wsl/install

---

## macOS Users

If you're using macOS, you can use the built-in Terminal application.

You do not need WSL.

### Prepare Your Environment

1. Open Terminal.
2. Install VS Code if you haven't already.
3. Create a project directory:

```bash
mkdir -p ~/cloudpros-project
cd ~/cloudpros-project
```

You can write your Bash scripts and manage Git directly from your Mac.

However, **macOS is not Ubuntu**.

The project requires Linux-specific tools such as systemd and UFW, so you'll need an Ubuntu 24.04 environment for the actual server configuration.

### Install Multipass

You can use Multipass to create an Ubuntu virtual machine.

Download Multipass:

https://canonical.com/multipass

After installing Multipass, create an Ubuntu 24.04 VM:

```bash
multipass launch 24.04 --name cloudpros-server
```

Access the VM:

```bash
multipass shell cloudpros-server
```

You can now configure your Ubuntu server.

Use your Mac's Terminal or VS Code for development, and your Ubuntu VM for testing the project requirements.

---

## Linux Users

If you're already using Linux, you can use your existing terminal.

### Prepare Your Environment

1. Open your terminal.
2. Install VS Code if needed.
3. Create a project directory:

```bash
mkdir -p ~/cloudpros-project
cd ~/cloudpros-project
```

If you're running Ubuntu 24.04, you can use your existing environment for development.

However, we recommend using a separate Ubuntu VM for this project, particularly because you'll be modifying SSH settings, firewall rules, and system services.

This helps avoid disrupting your main computer.

If you're using another Linux distribution, create an Ubuntu 24.04 VM to ensure compatibility.

Multipass is one option:

https://canonical.com/multipass

---

## Verify Your Environment

Before starting the project, confirm that your Ubuntu environment is working correctly.

### Check Your Operating System

Run:

```bash
cat /etc/os-release
```

Confirm that you're using Ubuntu 24.04.

### Check Your Shell

Run:

```bash
echo $SHELL
```

You should have access to Bash.

### Check systemd

Run:

```bash
systemctl --version
```

This confirms that systemd is installed.

You can also verify that systemd is running as the system manager:

```bash
ps -p 1 -o comm=
```

For the project, the output should be:

```text
systemd
```

### Update Your Packages

Run:

```bash
sudo apt update && sudo apt upgrade -y
```

### Install Basic Tools

Install Git, curl, and other useful utilities:

```bash
sudo apt install -y git curl
```

Other packages required by the project can be installed as you work through the requirements.

### Configure Git

If you haven't configured Git before, run:

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

Replace the example values with your own details.

### Confirm Git Installation

```bash
git --version
```

You should see the installed Git version.

---

## Getting Help

If you encounter any challenges, ask your questions in the appropriate CloudPros WhatsApp Community discussion group.

When asking for help, please include:

- What you're trying to achieve.
- What you've attempted so far.
- Any error messages you've encountered.
- What you've already tried to resolve the issue.

Please avoid sharing passwords, private keys, or sensitive information.

We encourage everyone to support one another while making an effort to understand and implement their own solutions.

---

## Final Note

This project is designed to help you develop practical Linux administration and DevOps skills.

Focus on understanding what you're configuring, why it matters, and how to verify that it works.

Your implementation doesn't need to be unnecessarily complex. It needs to be secure, functional, well-documented, and capable of recovering from failures.

**Build it. Break it. Fix it. Document it.**

Happy building!

**CloudPros Tech Community**


# CloudPros Weekly Community Project

## Week 1: Self-Healing Linux Web Server

**Deadline:** Sunday Nov 1st 2026, 11:59 PM (GMT)  
**Submission:** GitHub Pull Request

---

## Table of Contents

- [CloudPros Weekly Community Project](#cloudpros-weekly-community-project)
  - [Week 1: Self-Healing Linux Web Server](#week-1-self-healing-linux-web-server)
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
    - [HTTP Access](#http-access)
    - [Backups and Log Rotation](#backups-and-log-rotation)
    - [Documentation](#documentation)
  - [Stretch Challenge](#stretch-challenge)
  - [Submission Instructions](#submission-instructions)
    - [Prepare Your Project](#prepare-your-project)
    - [Create a Pull Request](#create-a-pull-request)
    - [Pull Request Title](#pull-request-title)
    - [Pull Request Description](#pull-request-description)
    - [Request a Review](#request-a-review)
    - [Do Not Merge](#do-not-merge)
  - [Submission Checklist](#submission-checklist)
- [System Setup Guide](#system-setup-guide)
  - [Windows Users](#windows-users)
    - [Install WSL and Ubuntu](#install-wsl-and-ubuntu)
    - [Use Ubuntu in VS Code](#use-ubuntu-in-vs-code)
  - [macOS Users](#macos-users)
    - [Install Multipass](#install-multipass)
  - [Linux Users](#linux-users)
  - [Visual Studio Code](#visual-studio-code)
  - [Verify Your Ubuntu Environment](#verify-your-ubuntu-environment)
    - [Check Your Operating System](#check-your-operating-system)
    - [Check Bash](#check-bash)
    - [Check systemd](#check-systemd)
    - [Update Your Packages](#update-your-packages)
    - [Install Basic Utilities](#install-basic-utilities)
  - [Install and Configure Git](#install-and-configure-git)
    - [Check Whether Git Is Installed](#check-whether-git-is-installed)
    - [Configure Your Git Identity](#configure-your-git-identity)
    - [Verify Your Git Configuration](#verify-your-git-configuration)
    - [Create a GitHub Account](#create-a-github-account)
    - [Set Up GitHub Authentication](#set-up-github-authentication)
  - [Prepare Your Project Workspace](#prepare-your-project-workspace)
    - [A Note About Working Locally](#a-note-about-working-locally)
  - [Getting Help](#getting-help)
  - [Final Note](#final-note)

---

## Problem Statement

Imagine you're responsible for managing your company's website.

Everything works perfectly during the day, but at 3 AM, the application suddenly crashes. Nobody is available to restart it, leaving the website unavailable until someone notices the problem.

Your challenge is to build a **self-healing Linux web server** that can automatically recover from application failures without manual intervention.

The server must be secure, accessible over HTTP, and configured to handle automatic recovery, health monitoring, backups, and log management.

The aim is to build a working solution, test it, and document how it works.

---

## Project Objectives

By completing this project, you should gain practical experience with:

- Linux administration and server security
- SSH authentication and firewall configuration
- Bash scripting
- systemd services and timers
- Nginx reverse proxy configuration
- Automatic service recovery
- Health monitoring
- Backup automation and retention
- Log rotation
- Git and GitHub collaboration

The focus is on understanding how these technologies work together, rather than building a complex application.

---

## Tools and Technologies

| Tool | Purpose |
|------|---------|
| Ubuntu 24.04 | Linux environment |
| Bash | Scripting and automation |
| systemd | Service management and scheduling |
| Nginx | Reverse proxy |
| UFW | Firewall configuration |
| socat | Lightweight HTTP service |
| curl | HTTP testing and health checks |
| logrotate | Log management |
| Git | Version control |
| GitHub | Project submission |
| VS Code | Code editing |

**You do not need Python, Flask, or any application framework for this project.**

---

## Project Requirements

Complete the following requirements using your Ubuntu environment.

### Secure the Server

Configure secure administrative access.

**Requirements:**

- Create a user named `deploy`.
- Grant `deploy` sudo privileges.
- Configure SSH key-based authentication for `deploy`.
- Disable SSH password authentication.
- Disable direct root SSH login.
- Verify that SSH key authentication works.

**Expected Outcome:**

The `deploy` user can authenticate using SSH keys, while password authentication and direct root SSH login are disabled.

> **Important:** Confirm that key-based SSH access works before disabling password authentication. If you're working on your personal Linux computer, take care not to disrupt your existing access.

### Configure the Firewall

Install and configure UFW.

**Requirements:**

- Deny incoming connections by default.
- Allow SSH traffic on port 22.
- Allow HTTP traffic on port 80.
- Block unnecessary incoming connections.
- Ensure port 8000 is not externally accessible.
- Enable UFW.

**Expected Outcome:**

Only the required services are accessible from outside the Ubuntu environment.

### Deploy a Web Service

Create a basic HTTP service using Bash and a lightweight utility such as `socat`.

The service should return:

```text
CloudPros Server Running
```

**Requirements:**

- Create a dedicated system user named `appuser`.
- Store the application files in `/opt/cloudpros`.
- Configure the application to listen on `127.0.0.1:8000`.
- Create a systemd service named `cloudpros-app`.
- Run the application as `appuser`, not root.
- Enable the service to start automatically on boot.
- Return a valid HTTP `200 OK` response.

**Expected Outcome:**

The application runs successfully under systemd and responds to HTTP requests on the local interface.

### Configure Nginx

Install and configure Nginx as a reverse proxy.

**Requirements:**

- Configure Nginx to listen on port 80.
- Forward incoming HTTP requests to `127.0.0.1:8000`.
- Ensure the application is accessible through Nginx.
- Ensure port 8000 cannot be accessed directly from outside the Ubuntu environment.

**Expected Outcome:**

Accessing the server through port 80 displays the application's response.

### Implement Self-Healing

Configure automatic application recovery using systemd.

**Requirements:**

- Configure `cloudpros-app` to restart automatically after an unexpected failure.
- Ensure the application recovers within 10 seconds.
- Terminating the application process using `kill -9` must trigger automatic recovery.
- The restarted application must have a different process ID.

**Expected Outcome:**

The application automatically recovers from an unexpected crash without manual intervention.

### Implement Health Monitoring

Create a Bash script at:

```text
/usr/local/bin/healthcheck.sh
```

**Requirements:**

- Check whether the application responds successfully over HTTP.
- Detect failed or unhealthy responses.
- Restart `cloudpros-app` if the health check fails.
- Record timestamped health check results in a log file under `/var/log/cloudpros/`.
- Run the health check every minute using a systemd timer.

**Do not use cron.**

**Expected Outcome:**

The health check runs automatically every minute and attempts to restore the application if it becomes unhealthy.

### Configure Automated Backups

Create an automated backup solution.

**Requirements:**

- Back up `/opt/cloudpros` daily.
- Store backups in `/var/backups/cloudpros/`.
- Include the date in each backup filename.
- Automatically delete backups older than seven days.
- Schedule backups using a systemd timer.
- Verify that a backup can be extracted successfully.

**Example backup filename:**

```text
cloudpros-2026-10-26.tar.gz
```

**Expected Outcome:**

The application directory is backed up automatically each day, and outdated backups are removed.

### Configure Log Rotation

Configure logrotate for:

```text
/var/log/cloudpros/*.log
```

**Requirements:**

- Rotate logs daily.
- Keep seven rotated logs.
- Compress rotated logs.
- Handle missing and empty log files appropriately.

**Expected Outcome:**

Application logs are rotated automatically to prevent uncontrolled growth.

---

## Evidence Required

Your repository must include evidence demonstrating that the project requirements have been completed.

You can provide screenshots, terminal output, and explanations in your README or an `evidence/` directory.

### Application Recovery

Check the application service:

```bash
sudo systemctl status cloudpros-app
```

Identify its main PID, then terminate the application process:

```bash
sudo kill -9 <APP_PID>
```

Replace `<APP_PID>` with the actual process ID.

Check the service again:

```bash
sudo systemctl status cloudpros-app
```

Your evidence must show:

- The original process ID.
- The new process ID.
- The service returning to an active state.
- Recovery within 10 seconds.

### Firewall Configuration

Run:

```bash
sudo ufw status verbose
```

Show that the firewall is enabled and the required rules are configured.

### systemd Timers

Run:

```bash
sudo systemctl list-timers --all | grep cloudpros
```

Show that the health check and backup timers are configured.

### HTTP Access

First, verify that the application responds through Nginx:

```bash
curl -I http://127.0.0.1
```

**Expected Response:**

```text
HTTP/1.1 200 OK
```

Next, where your Ubuntu environment is reachable from another network context, test its IP address:

```bash
curl -I http://<SERVER_IP>
```

Replace `<SERVER_IP>` with the actual reachable IP address.

Then verify that port 8000 is not externally accessible:

```bash
curl --connect-timeout 5 http://<SERVER_IP>:8000
```

**Expected Result:**

The connection fails.

> **Note:** The external access tests should be performed from outside the Ubuntu environment. If you're using WSL or another local setup where networking behaves differently, explain your setup and provide equivalent evidence that the application listens only on `127.0.0.1:8000`.

You can verify the listening address using:

```bash
sudo ss -ltnp
```

Your evidence should show the application bound to `127.0.0.1:8000`, rather than `0.0.0.0:8000`.

### Backups and Log Rotation

Include evidence showing:

- Successful backup creation.
- Dated backup filenames.
- A successful backup extraction test.
- The backup retention configuration.
- The logrotate configuration.

You can validate your logrotate configuration with:

```bash
sudo logrotate -d /etc/logrotate.d/cloudpros
```

### Documentation

Your README must explain:

- How you set up the project.
- How the application and Nginx work together.
- How systemd handles application recovery.
- How health monitoring works.
- How backups and log rotation are configured.
- How someone else can reproduce your setup.
- Any challenges you encountered and how you resolved them.

Do not commit passwords, private SSH keys, access tokens, or other secrets.

---

## Stretch Challenge

Create a Bash script named:

```text
setup.sh
```

The script should automate the configuration of a fresh Ubuntu 24.04 environment.

It should handle:

- Required package installation.
- User creation.
- Firewall configuration.
- Application deployment.
- systemd services and timers.
- Nginx configuration.
- Health monitoring.
- Automated backups.
- Log rotation.

**Your script must be idempotent.**

This means it should be safe to run multiple times without breaking the environment or creating duplicate configurations.

Document any prerequisites that still require manual setup.

---

## Submission Instructions

Submit your project through a GitHub Pull Request.

### Prepare Your Project

Your repository must contain your application files, scripts, configuration files, README, and evidence.

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
└── setup.sh
```

This structure is a recommendation, not a strict requirement.

`setup.sh` is optional unless you attempt the stretch challenge.

### Create a Pull Request

Push your work to GitHub and create a Pull Request targeting the following branch in the CloudPros repository:

```text
linux-self-healing-web-server-submissions
```

**Do not target `main`.**

If you're working from a fork, select the CloudPros repository and the submissions branch as the base for your Pull Request.

### Pull Request Title

Use this format:

```text
[Week 1] Self-Healing Linux Web Server - Your Name
```

### Pull Request Description

Include:

- A brief summary of your implementation.
- What you completed.
- How you tested the solution.
- A link to your README and evidence.
- Any challenges or lessons learnt.
- Whether you completed the stretch challenge.

### Request a Review

Request a review from:

**@joincloudpros**

If GitHub does not allow you to select this account as a reviewer, mention `@joincloudpros` in a Pull Request comment.

### Do Not Merge

**Leave your Pull Request open. Do not merge it.**

Submissions will be reviewed by the CloudPros team.

---

## Submission Checklist

Before submitting, confirm that:

- [ ] The `deploy` user has sudo access.
- [ ] SSH key authentication is configured.
- [ ] SSH password authentication is disabled.
- [ ] Direct root SSH login is disabled.
- [ ] UFW is configured correctly.
- [ ] The application runs as `appuser`.
- [ ] The application is managed by systemd.
- [ ] Nginx forwards HTTP requests to the application.
- [ ] Port 8000 is not externally accessible.
- [ ] The application automatically recovers after a crash.
- [ ] The health check runs every minute.
- [ ] Daily automated backups are configured.
- [ ] Backup retention is configured.
- [ ] Log rotation is configured.
- [ ] Your README explains how everything works.
- [ ] Required evidence is included.
- [ ] No credentials or private keys are committed.
- [ ] The Pull Request targets the correct submissions branch.
- [ ] `joincloudpros` has been requested as a reviewer or mentioned.
- [ ] The Pull Request remains open and unmerged.

---

# System Setup Guide

You can complete this project using your own computer. You do not need to purchase or deploy a cloud server.

The important thing is to have access to an **Ubuntu 24.04 environment** where you can run the Linux commands and configure the required services.

Follow the instructions for your operating system below.

## Windows Users

If you're using Windows, you'll need **Windows Subsystem for Linux (WSL)**.

WSL allows you to run Ubuntu directly on your Windows computer.

### Install WSL and Ubuntu

Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu-24.04
```

Restart your computer if prompted.

Once the installation is complete:

1. Launch Ubuntu from the Start menu.
2. Create your Linux username and password.
3. Complete the initial setup.
4. Open the Ubuntu terminal.

Update your packages:

```bash
sudo apt update && sudo apt upgrade -y
```

### Use Ubuntu in VS Code

Install VS Code and the **WSL extension** by Microsoft.

Open your Ubuntu terminal and create a project folder:

```bash
mkdir -p ~/cloudpros-project
cd ~/cloudpros-project
```

Then run:

```bash
code .
```

This opens VS Code connected to your Ubuntu environment.

**Important:** When using the terminal inside VS Code, make sure you're working in **Ubuntu (WSL)**, not PowerShell or Command Prompt.

You can confirm this by running:

```bash
uname -a
```

The output should identify Linux.

**WSL documentation:**

https://learn.microsoft.com/en-us/windows/wsl/install

> **Note:** WSL supports systemd on current versions, but networking and firewall behaviour can differ from a standard Ubuntu installation. Make sure systemd is running and document any networking differences you encounter.

---

## macOS Users

If you're using macOS, you can use the built-in **Terminal** application and VS Code to write scripts, manage files, and work with Git.

However, macOS does not use systemd or UFW, so you'll need an Ubuntu environment to complete the Linux-specific requirements.

### Install Multipass

Multipass allows you to run an Ubuntu virtual machine on your Mac.

Download Multipass:

https://canonical.com/multipass

After installing it, open Terminal and run:

```bash
multipass launch 24.04 --name cloudpros-server
```

Once the VM is created, access it with:

```bash
multipass shell cloudpros-server
```

You now have an Ubuntu environment where you can work on the project.

Update your packages:

```bash
sudo apt update && sudo apt upgrade -y
```

You can continue using your Mac's Terminal and VS Code for editing, while running and testing the Linux services inside Ubuntu.

---

## Linux Users

If you're already using Linux, you can use your existing terminal.

If your computer runs **Ubuntu 24.04**, you can complete the project directly on your computer.

Open your terminal and update your packages:

```bash
sudo apt update && sudo apt upgrade -y
```

If you're using another Linux distribution, an Ubuntu 24.04 environment is recommended so that the commands and configurations match the project requirements.

You can use an Ubuntu VM if needed.

> **Important:** If you're working directly on your main Linux installation, be careful when changing SSH settings, firewall rules, and system services. These changes can affect your computer's existing configuration.

---

## Visual Studio Code

We recommend using **Visual Studio Code (VS Code)** for this project.

You can use it to:

- Write and edit Bash scripts.
- Manage configuration files.
- Open an integrated terminal.
- Work with Git and GitHub.
- Organise your project files.

If you don't already have VS Code, download it here:

https://code.visualstudio.com/

VS Code is available for Windows, macOS, and Linux.

**Windows users:** Install the Microsoft WSL extension and open your project through Ubuntu.

**macOS and Linux users:** You can use your existing terminal alongside VS Code.

You're welcome to use another editor if you prefer.

---

## Verify Your Ubuntu Environment

Before starting, make sure your Ubuntu environment is ready.

### Check Your Operating System

Run:

```bash
cat /etc/os-release
```

Confirm that the output identifies Ubuntu 24.04.

### Check Bash

Run:

```bash
bash --version
```

This confirms that Bash is installed.

### Check systemd

Run:

```bash
systemctl --version
```

Then run:

```bash
ps -p 1 -o comm=
```

The expected output is:

```text
systemd
```

If systemd is not running, resolve that before continuing with the project.

### Update Your Packages

Run:

```bash
sudo apt update && sudo apt upgrade -y
```

### Install Basic Utilities

Run:

```bash
sudo apt install -y git curl
```

You'll install the other tools required by the assignment as part of your implementation.

---

## Install and Configure Git

You'll use Git to track your work and GitHub to submit your project.

### Check Whether Git Is Installed

Run:

```bash
git --version
```

If Git is installed, you'll see its version number.

If it isn't installed in Ubuntu, run:

```bash
sudo apt install -y git
```

**Windows users:** Run these commands in the Ubuntu (WSL) terminal.

**macOS users:** You can use Git from your Mac's Terminal. If Git is not installed, running `git --version` may prompt you to install Apple's Command Line Tools.

**Linux users:** Use your distribution's package manager if Git isn't already installed.

### Configure Your Git Identity

Set your name:

```bash
git config --global user.name "Your Name"
```

Set your email address:

```bash
git config --global user.email "your-email@example.com"
```

Replace the examples with your own details.

Ideally, use an email address associated with your GitHub account.

### Verify Your Git Configuration

Run:

```bash
git config --global --list
```

Confirm that your name and email address appear correctly.

### Create a GitHub Account

If you don't already have a GitHub account, create one here:

https://github.com/

You'll use GitHub to host your work and submit your Pull Request.

### Set Up GitHub Authentication

Before pushing your code, make sure you can authenticate with GitHub.

You can use either:

- SSH authentication.
- HTTPS authentication using an appropriate GitHub credential method.

GitHub no longer accepts account passwords for Git operations over HTTPS.

You can follow GitHub's official authentication guidance:

https://docs.github.com/en/authentication

> **Note:** SSH authentication for GitHub is separate from the SSH configuration required for your Ubuntu server. You may use different SSH keys for each purpose.

---

## Prepare Your Project Workspace

Create a folder for your project.

In your development terminal, run:

```bash
mkdir -p ~/cloudpros-project
cd ~/cloudpros-project
```

You can organise your scripts, configuration files, documentation, and evidence here.

If you're using VS Code in an environment where the `code` command is available, open the folder with:

```bash
code .
```

You can now begin working on the project requirements.

### A Note About Working Locally

You can use your personal computer for this project.

- **Windows:** Use Ubuntu through WSL.
- **macOS:** Use your Terminal and an Ubuntu environment through Multipass.
- **Linux:** Use your existing Ubuntu 24.04 installation or an Ubuntu environment.

You do not need a publicly accessible server.

For network isolation testing, use the checks appropriate to your environment and document what you tested.

The goal is to demonstrate that Nginx exposes the website on port 80 while the application itself remains bound to the local interface on port 8000.

---

## Getting Help

If you get stuck, ask your questions in the **Ask for Help** group within the CloudPros WhatsApp Community.

When asking for help, explain:

- What you're trying to achieve.
- What you've attempted.
- Any errors you're encountering.
- What you've already tried to resolve the problem.

Please avoid sharing passwords, private keys, or other sensitive information.

Everyone is encouraged to ask questions, share useful findings, and support one another.

---

## Final Note

This project is about building practical Linux and DevOps skills.

Your solution doesn't need to be unnecessarily complicated. Focus on making it functional, secure, reliable, and well-documented.

Take the time to understand your configurations and test that they behave as expected.

**Build it. Break it. Fix it. Document it.**

Happy building!

**CloudPros Tech Community**

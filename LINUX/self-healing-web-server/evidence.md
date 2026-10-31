# Project Evidence

This directory contains evidence demonstrating the functionality, testing and successful implementation of the Linux Self-Healing Web Server.

## Application Recovery
The evidence shows the original process ID and the new process ID after the former has been terminated. It also shows the service returning to an active state.

```bash
sudo systemctl status cloudpros-app
```
<img width="925" height="345" alt="image" src="https://github.com/user-attachments/assets/d50d76b3-d5bc-4f53-a41e-f567e75fb5db" />

```bash
sudo kill -9 1556
```

<img width="780" height="202" alt="image" src="https://github.com/user-attachments/assets/a557d0aa-24ec-44dd-827a-1922408ef3cb" />

## Firewall Configuration
```bash
sudo ufw status verbose
```
<img width="775" height="222" alt="image" src="https://github.com/user-attachments/assets/2d0d4ccb-62eb-4504-8f52-41e41573a10a" />

## Systemd Timers
```
sudo systemctl list-timers --all | grep cloudpros
```
<img width="927" height="37" alt="image" src="https://github.com/user-attachments/assets/a99b0795-806a-4204-9f1a-8d43be7cc1ba" />

## HTTP Access
```bash
curl -I http://127.0.0.1
```

<img width="790" height="105" alt="image" src="https://github.com/user-attachments/assets/8080b24b-7be4-4467-83f0-decb1b6af129" />

```bash
curl --connect-timeout 5 http://172.25.247.180:8000
```
<img width="682" height="20" alt="image" src="https://github.com/user-attachments/assets/2560c33a-ca27-4001-8ea8-6ba40c647611" />

```bash
sudo ss -ltnp
```
<img width="1297" height="347" alt="image" src="https://github.com/user-attachments/assets/298ab318-dacc-41c1-acf0-3497e876e438" />


## Backup and Log Rotation
### Successful backup creation
```bash
ls -l /var/backups/cloudpros/
```
<img width="492" height="37" alt="image" src="https://github.com/user-attachments/assets/f70da1f0-7cc3-4e67-bc2e-294a40ad09fd" />
The image, shows backup exists and filenames include dates.

### A successful backup extraction test
```bash
sudo tar -xzf /var/backups/cloudpros/cloudpros-2026-10-31.tar.gz -C /tmp
```
```bash
ls /tmp/opt/cloudpros
```
<img width="200" height="20" alt="image" src="https://github.com/user-attachments/assets/17d57ceb-fbc1-4dd4-bd19-7ae2955405c0" />

### The backup retention configuration
```bash
find /var/backups/cloudpros -type f -mtime +7
```
“Backups older than 7 days are automatically removed using find -mtime +7.”

### Show logrotate configuration
```bash
cat /etc/logrotate.d/cloudpros
```
<img width="460" height="112" alt="image" src="https://github.com/user-attachments/assets/c86b9a0b-89d9-4fcc-8fc5-2ec0a7772a18" />

### Validate logrotation configuration
```bash
sudo logrotate -d /etc/logrotate.d/cloudpros
```
<img width="965" height="335" alt="image" src="https://github.com/user-attachments/assets/094af67d-08f0-4244-bbd5-1137e7c79779" />
<img width="875" height="210" alt="image" src="https://github.com/user-attachments/assets/6c6d2c32-ef62-469b-829f-8a67fca07e36" />

### Force a rotation to show evidence
```bash
sudo logrotate -f /etc/logrotate.d/cloudpros
```
```bash
ls -l /var/log/cloudpros/
```
<img width="705" height="135" alt="image" src="https://github.com/user-attachments/assets/76c11817-4c59-4a50-841d-c6f0726a16de" />

## Purpose

The evidence provided here validates the self-healing capabilities of the web server and demonstrates its ability to detect failures and automatically recover services.

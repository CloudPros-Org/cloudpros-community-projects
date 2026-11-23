# Incident 1: Service Discovery Failure

### Problem
The gateway returned `502 Bad Gateway` because the API hostname resolved to the wrong IP address.

### Investigation
I compared `config/hosts.json` with `config/defaults/hosts.json` and found that `api.projecthub.test` pointed to `127.0.0.9` instead of `127.0.0.3`.

### Root Cause
An incorrect DNS mapping prevented the gateway and background worker from reaching the API at its intended address.

### Resolution
I updated `config/hosts.json` to map `api.projecthub.test` to `127.0.0.3`.

### Verification
I restarted the lab and checked DNS resolution, service status, and application endpoints using `sh scripts/status.sh` and `sh scripts/verify.sh`.

### Prevention
Add automated DNS resolution and service connectivity checks to detect incorrect mappings early.
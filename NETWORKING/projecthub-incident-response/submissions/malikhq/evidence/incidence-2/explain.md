# Incident 2: API Service Reachability Failure

### Problem
The gateway returned `502 Bad Gateway` because it could not connect to the API at its intended address.

### Investigation
I inspected `config/api.json`, compared it with `config/defaults/api.json`, and checked listening sockets using `ss -ltnp`. The API was listening on `127.0.0.1:18081` instead of `127.0.0.3:18081`. A direct request to `127.0.0.1:18081/health` returned HTTP 200, while a request to `127.0.0.3:18081/health` failed with connection refused.

### Root Cause
The API was bound to the wrong loopback address, preventing the gateway from reaching it at the expected address.

### Resolution
I updated `config/api.json` to set `bind_host` to `127.0.0.3`, matching the default configuration.

### Verification
I restarted the lab and tested the API directly and through the gateway. I used `sh scripts/status.sh` and `sh scripts/verify.sh` to check service health and confirm that `/health` and `/projects` returned HTTP 200.

### Prevention
Add automated checks to verify service bind addresses and test connectivity between the gateway and API before declaring a deployment healthy.
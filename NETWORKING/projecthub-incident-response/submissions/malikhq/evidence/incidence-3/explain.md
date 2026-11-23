# Incident 3: Upstream Connection Failure

### Problem
The gateway returned `502 Bad Gateway` when requests were forwarded to the API.

### Investigation
I inspected `config/gateway.json`, compared it with `config/defaults/gateway.json`, and reviewed `logs/gateway.log`. The gateway logs showed `ConnectionRefusedError` for `/health` and `/projects`. The active configuration used upstream port `18099`, while the default configuration specified port `18081`.

### Root Cause
The gateway was configured to connect to the wrong upstream port, preventing it from reaching the API.

### Resolution
I corrected `config/gateway.json` by changing `upstream_port` from `18099` to `18081`.

### Verification
I restarted the services and tested `/health` and `/projects` through the gateway. I also ran `sh scripts/verify.sh` and checked the listening ports.

### Exposure and Impact Check
I checked that the gateway and API remained bound to their intended loopback addresses and that no unnecessary listener was introduced on port `18099`.

### Prevention
Add automated checks to validate upstream host and port settings and test gateway-to-API connectivity before deployment.
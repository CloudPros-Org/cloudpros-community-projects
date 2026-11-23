# Incident 4: Application Routing Failure

### Problem
The gateway's `/health` endpoint worked, but `/projects` returned HTTP 404 Not Found.

### Investigation
I compared `config/gateway.json` with `config/defaults/gateway.json` and inspected `logs/gateway.log`. The active configuration used `/internal` as the API prefix instead of `/api`. The logs confirmed that the gateway forwarded `/projects` to `/internal/projects`, which the API did not recognise.

### Root Cause
An incorrect API prefix caused the gateway to forward project requests to the wrong API path.

### Resolution
I corrected `config/gateway.json` by changing `api_prefix` from `/internal` to `/api`.

### Verification
I restarted the services and ran `sh scripts/verify.sh` to confirm that `/health` and `/projects` returned HTTP 200.

### Exposure and Impact Check
I checked the gateway and API listening addresses and verified that the correction did not introduce additional listening ports or expose the API beyond its intended loopback address.

### Prevention
Add automated endpoint tests to validate gateway routing and API path prefixes before deployment.
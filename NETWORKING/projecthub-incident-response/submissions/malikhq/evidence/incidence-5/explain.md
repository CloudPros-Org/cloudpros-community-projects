# Incident 5: Background Worker Processing Failure

### Problem
The background worker repeatedly failed to connect to the API, reporting `Connection refused` errors in `logs/worker.log`. Although the API and gateway were reachable, the worker could not communicate with the API using its configured endpoint.

### Investigation
I inspected `logs/worker.log` and found repeated API connection failures. I compared `config/worker.json` with `config/defaults/worker.json` and discovered that the active worker configuration used port `18099`, while the expected API port was `18081`. I also checked the API health endpoint directly.

### Root Cause
The worker was configured to connect to the wrong API port. The API listened on port `18081`, but the worker attempted to connect to port `18099`, causing connection failures.

### Resolution
I updated `config/worker.json` to use API port `18081` and restarted the lab services so the worker could use the corrected endpoint.

### Verification
I confirmed that the API health endpoint at `http://127.0.0.3:18081/health` returned HTTP `200 OK` and reported that the database was reachable. The worker log subsequently recorded that it started with `api.projecthub.test:18081`. However, successful background task processing has not yet been confirmed.

### Prevention
Add automated checks to validate worker API configuration, verify API connectivity, and monitor worker processing activity. Alert on repeated connection failures and test background task processing as part of incident verification.
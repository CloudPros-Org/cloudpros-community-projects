# ProjectHub — Network Operations and Incident Response

**Contributor:** poshpeck  
**Project:** CloudPros Week 4 Networking Challenge

## Overview

This project investigates and resolves five progressive network incidents affecting a simulated production environment called ProjectHub.

The investigation covers service discovery, API connectivity, upstream TCP communication, HTTP routing and background worker communication.

## Environment and Architecture

ProjectHub consists of four main processes:

- DNS service: `127.0.0.4:15353`
- API service: `127.0.0.3:18081`
- Edge gateway: `127.0.0.2:18080`
- Background worker: communicates directly with the API

The gateway receives client requests and forwards them to the API using internal DNS resolution.

## Incident Reports

### Incident 1 — Service Discovery and DNS Resolution

**Status:** Resolved

#### Impact
The gateway returned HTTP 502 because it could not connect to the backend API.

#### Investigation
The API hostname resolved to `127.0.0.9` instead of the API's actual address, `127.0.0.3`.

The API and gateway processes were running, and their TCP ports were reachable.

#### Root Cause
An incorrect DNS mapping in the active hosts configuration caused the gateway to attempt a connection to the wrong IP address.

#### Resolution
The API hostname mapping was restored to `127.0.0.3`.

#### Verification
- API hostname resolved to `127.0.0.3`.
- Edge hostname resolved to `127.0.0.2`.
- Gateway health returned HTTP 200.
- `/health` and `/projects` verification checks passed.
- Database connectivity was confirmed.

#### Evidence
- `evidence/incident-1/initial-investigation.txt`
- `evidence/incident-1/resolution-verification.txt`

#### Prevention
- Monitor internal DNS resolution.
- Validate service hostname mappings.
- Maintain version-controlled DNS configuration
- Alert on gateway upstream connection failures.

### Incident 2 — API Reachability and Service Binding

**Status:** Resolved

**Status:** Resolved

#### Impact
The ProjectHub gateway returned HTTP 502 because it could not establish a TCP connection to the backend API. Although the API process was running, it was listening on an unexpected loopback address.

#### Investigation
The initial service status showed:

- API listening on `127.0.0.1:18081` instead of `127.0.0.3:18081`.
- Gateway listening on `127.0.0.2:18080`.
- All four processes (DNS, API, gateway and worker) were running.
- HTTP health checks through the gateway returned HTTP 502 with a connection-refused error.

The active API configuration contained:

```json
{
  "bind_host": "127.0.0.1",
  "port": 18081
}
```

The default API configuration specified:

```json
{
  "bind_host": "127.0.0.3",
  "port": 18081
}
```

The gateway configuration expected the API at `api.projecthub.test:18081`. The DNS configuration correctly mapped `api.projecthub.test` to `127.0.0.3`, ruling out DNS as the cause.

#### Root Cause
An incorrect API bind address caused the API to listen on `127.0.0.1` instead of the expected `127.0.0.3`.

Consequently, the gateway's connection to the API's expected address was refused.

#### Resolution
Updated the active API configuration to use `127.0.0.3` as its bind address.

Stopped and restarted the ProjectHub processes using the supplied `stop.sh` and `start.sh` scripts so that the API loaded the corrected configuration.

#### Verification
- API TCP connectivity confirmed at `127.0.0.3:18081`.
- Gateway TCP connectivity confirmed at `127.0.0.2:18080`.
- All four processes confirmed running.
- Gateway health endpoint returned HTTP 200.
- Database connectivity confirmed.
- `/health` verification passed with HTTP 200.
- `/projects` verification passed with HTTP 200.

#### Evidence
- `evidence/incident-2/resolution-verification.txt`

#### Prevention
- Validate service bind addresses against gateway upstream configurations.
- Monitor API listening addresses and TCP connectivity.
- Include service binding checks in deployment validation.
- Alert on gateway upstream connection failures.
- Maintain consistent, version-controlled service configurations.

## Lessons Learnt

This project demonstrates the importance of investigating network communication layer by layer. Key lessons include:

- DNS resolution must point to the correct service address.
- A running process does not necessarily mean its service is reachable.
- Correct IP binding is essential for communication between services.
- TCP connectivity and HTTP application health must be tested separately.
- Configuration comparison helps identify differences between active and default settings.
- Evidence should be captured before and after applying a fix.

### Incident 3 — Upstream TCP Connectivity

**Status:** Resolved




#### Impact

The ProjectHub gateway was reachable, and the API process was running. However, requests forwarded through the gateway failed with HTTP 502 Bad Gateway errors.

The gateway returned a connection-refused error when attempting to communicate with the API. This prevented clients from accessing API endpoints through the gateway.

#### Investigation

The initial status check showed:

- API TCP connection at `127.0.0.3:18081` was reachable.
- Gateway TCP connection at `127.0.0.2:18080` was reachable.
- HTTP health checks through the gateway returned 502.
- DNS, API, gateway and worker processes were running.

The active API configuration showed that the API was listening on port `18081`.

The gateway configuration showed:

- Upstream hostname: `api.projecthub.test`
- Upstream port: `18099`

The DNS configuration correctly resolved `api.projecthub.test` to `127.0.0.3`.

Comparing the active gateway configuration with `config/defaults/gateway.json` confirmed that the expected upstream port was `18081`.

#### Root Cause

The gateway's `upstream_port` was incorrectly configured as `18099` instead of `18081`.

The API was listening on port `18081`, so the gateway attempted to connect to the wrong destination port. This resulted in a TCP connection refusal and HTTP 502 responses.

#### Resolution

Corrected the active gateway configuration in `config/gateway.json` by changing:

- Incorrect upstream port: `18099`
- Correct upstream port: `18081`

Stopped and restarted the ProjectHub processes to ensure the gateway loaded the corrected configuration.

#### Verification

After restarting the services:

- API TCP connectivity was successful.
- Gateway TCP connectivity was successful.
- HTTP health check through the gateway returned 200 OK.
- Database connectivity was confirmed.
- DNS, API, gateway and worker processes were running.
- `/health` returned HTTP 200.
- `/projects` returned HTTP 200.

All formal verification checks passed.

#### Evidence

Resolution evidence is stored in:

`evidence/incident-3/resolution-verification.txt`

#### Prevention

- Validate gateway upstream hostnames and ports against the actual API listening configuration.
- Keep active service configurations consistent with their default configurations.
- Include upstream connectivity checks in deployment and health-check procedures.
- Monitor gateway 502 responses and connection-refused errors.
- Test end-to-end communication between services after configuration changes.


### Incident 4 — Application Routing and Reverse Proxy

**Status:** Resolved

#### Impact

The ProjectHub gateway and API services were running and reachable. However, requests to the `/projects` endpoint returned HTTP 404 Not Found.

The `/health` endpoint continued to return HTTP 200, which initially made the system appear healthy. However, normal application functionality was affected because the gateway was forwarding requests using an incorrect API path prefix.

#### Investigation

The initial service status check confirmed:

- API TCP connectivity at `127.0.0.3:18081` was successful.
- Gateway TCP connectivity at `127.0.0.2:18080` was successful.
- HTTP health checks returned 200 OK.
- DNS, API, gateway and worker processes were running.

Formal verification revealed:

- `/health` returned HTTP 200.
- `/projects` returned HTTP 404.
- The error response identified the unexpected path as `/internal/projects`.

The active gateway configuration was compared with `config/defaults/gateway.json`.

The comparison revealed that the active gateway used `/internal` as its API prefix, while the default configuration specified `/api`.

#### Root Cause

The `api_prefix` setting in `config/gateway.json` was incorrectly configured as `/internal` instead of `/api`.

Consequently, the gateway forwarded application requests using an incorrect HTTP path, causing the API to return 404 Not Found.

#### Resolution

Corrected the active gateway configuration by changing:

- Incorrect API prefix: `/internal`
- Correct API prefix: `/api`

Restarted the ProjectHub processes to ensure the gateway loaded the corrected configuration.

#### Verification

After restarting the services:

- API TCP connectivity was successful.
- Gateway TCP connectivity was successful.
- HTTP health check returned 200 OK.
- Database connectivity was confirmed.
- All four processes were running.
- `/health` returned HTTP 200.
- `/projects` returned HTTP 200.

Both formal verification checks passed.

#### Evidence

Resolution evidence is stored in:

`evidence/incident-4/resolution-verification.txt`

#### Prevention

- Validate reverse-proxy path prefixes against the API's expected routes.
- Keep active gateway configurations consistent with default configurations.
- Test application endpoints in addition to basic health endpoints.
- Include HTTP path validation in deployment testing.
- Monitor HTTP 404 responses to identify routing and path-rewriting problems.


### Incident 5 — Background Worker-to-API Communication

**Status:** Resolved

#### Impact

The background worker could not communicate with the ProjectHub API. Tasks submitted through the application remained queued because the worker could not reach the API to retrieve and process them. The API and gateway appeared healthy, making this an issue specific to worker-to-API communication.

#### Investigation

The initial service status showed that the API and gateway were running and reachable. However, the worker log repeatedly reported connection-refused errors.

Inspection of the active worker configuration revealed:

- API host: `api.projecthub.test`
- Configured API port: `18099`

The default worker configuration specified port `18081`. The API was listening on port `18081`, so the active worker configuration was incorrect.

#### Root Cause

The worker was configured to connect to port `18099` instead of the API's actual listening port, `18081`. This caused connection failures and prevented the worker from processing queued tasks.

#### Resolution

Updated `config/worker.json` to use the correct API port:

```json
{
  "api_host": "api.projecthub.test",
  "api_port": 18081,
  "poll_seconds": 2
}
```

Restarted the ProjectHub services so the worker loaded the corrected configuration.

#### Verification

After the correction:

- The service status check confirmed that the API, gateway, database and worker were operational.
- The worker log confirmed successful startup using `api.projecthub.test:18081`.
- Submitted a test task titled `Incident 5 worker communication test`.
- The worker log confirmed that task ID 3 was processed and completed.
- The API task endpoint independently confirmed that task ID 3 had a status of `processed`.

#### Evidence

See `evidence/incident-5/resolution-verification.txt` for the corrected configuration, worker logs and API task verification.

#### Prevention

- Keep worker endpoint settings consistent with the API configuration.
- Validate service hostnames and ports before deployment.
- Implement worker health checks and connection-failure alerts.
- Monitor worker logs for repeated connection errors.
- Include end-to-end task-processing tests in deployment verification.

## Final Verification

All five injected incidents were investigated, resolved and verified:

- Incident 1: Service discovery and DNS resolution.
- Incident 2: API reachability and service binding.
- Incident 3: Gateway upstream TCP connectivity.
- Incident 4: Application routing and reverse-proxy path configuration.
- Incident 5: Background worker-to-API communication.

Evidence for the baseline and incident resolutions is provided in the corresponding files under the `evidence/` directory.

## Production Improvements

For a production environment, the following improvements would strengthen reliability and incident response:

- Centralise service configuration and validate changes before deployment.
- Implement continuous health checks for DNS, API, gateway and worker services.
- Monitor DNS failures, TCP connection errors and HTTP 4xx/5xx responses.
- Introduce structured logging and centralised log aggregation.
- Configure alerts for repeated connection failures and unprocessed background tasks.
- Add automated end-to-end tests for service discovery, API access, routing and worker task processing.
- Document recovery procedures and maintain tested rollback configurations.

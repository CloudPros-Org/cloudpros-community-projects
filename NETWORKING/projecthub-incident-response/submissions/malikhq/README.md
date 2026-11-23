# ProjectHub: Network Incident Response Lab

**CloudPros Weekly Community Project — Week 4**

- **Name:** Abdulmalik Ibikunle
- **GitHub:** [@malikhq](https://github.com/malikhq)
- **Focus:** Network Troubleshooting, DNS, TCP Connectivity, HTTP Routing, and Incident Response
- **Environment:** Ubuntu on WSL2
- **Status:** Five incidents investigated and documented

## 1. Project Overview

This project involved troubleshooting five production-style networking incidents affecting ProjectHub, a small SaaS application running on a single machine.

The lab simulates real-world failures involving private DNS resolution, API service binding, upstream connectivity, HTTP routing, and background worker communication.

My objective was to identify the root cause of each incident using logs, configuration files, connectivity tests, and service verification scripts. I then applied targeted fixes and verified the affected services.

## 2. Service Architecture

ProjectHub consists of four main components:

- **Private DNS:** Resolves internal service names to their configured IP addresses.
- **Edge gateway:** Receives HTTP requests and forwards them to the API.
- **ProjectHub API:** Serves project information and manages tasks.
- **Background worker:** Communicates with the API to process queued tasks.


### Ports and Services

| Address | Protocol | Purpose |
|---|---|---|
| `127.0.0.2:18080` | TCP | Edge gateway |
| `127.0.0.3:18081` | TCP | ProjectHub API |
| `127.0.0.4:15353` | UDP | Private lab DNS |
| `18099` | TCP | Fault-injection target |

All services operate on loopback addresses. The lab does not require Docker, cloud resources, or changes to system-wide DNS and firewall settings.

## 3. Incident Reports

### Incident 1: Service Discovery Failure

#### Problem and Impact

The gateway returned `502 Bad Gateway` because the API hostname resolved to the wrong IP address. This prevented the gateway and background worker from reaching the intended API endpoint through service discovery.

#### Investigation

I compared `config/hosts.json` with `config/defaults/hosts.json` to identify discrepancies in the private DNS mappings.

The investigation revealed that `api.projecthub.test` pointed to `127.0.0.9` instead of the expected `127.0.0.3`.

#### Root Cause

An incorrect DNS mapping directed API requests to the wrong loopback address.

#### Resolution

I updated `config/hosts.json` to map `api.projecthub.test` to `127.0.0.3`.

#### Verification

I restarted the lab and used the following commands to check service status and application health:

```sh
sh scripts/status.sh
sh scripts/verify.sh
```

The DNS mapping was corrected, and subsequent verification confirmed that the gateway's `/health` and `/projects` endpoints returned HTTP 200.

#### Prevention

- Add automated checks for internal DNS resolution.
- Validate service discovery before deployment.
- Monitor DNS failures and service connectivity errors.

### Incident 2: API Service Reachability Failure

#### Problem and Impact

The gateway returned `502 Bad Gateway` because it could not connect to the API at its intended address, even though the API process was running.

#### Investigation

I inspected `config/api.json`, compared it with `config/defaults/api.json`, and checked the listening sockets:

```sh
cat config/api.json
cat config/defaults/api.json
ss -ltnp
```

A direct request to `127.0.0.1:18081/health` returned HTTP 200, while a request to `127.0.0.3:18081/health` failed with connection refused.

This showed that the API was listening on the wrong loopback address.

#### Root Cause

The API was bound to `127.0.0.1` instead of `127.0.0.3`, preventing the gateway from connecting to it at the expected address.

#### Resolution

I updated `config/api.json` to use the intended bind address:

```json
{
  "bind_host": "127.0.0.3"
}
```

The change restored the API's expected listening address.

#### Verification

I restarted the lab and ran:

```sh
sh scripts/status.sh
sh scripts/verify.sh
```

I also tested the API directly and through the gateway. The `/health` and `/projects` endpoints returned HTTP 200.

#### Prevention

- Validate service bind addresses during startup.
- Test connectivity from the actual client service.
- Include listener and endpoint checks in deployment health checks.

### Incident 3: Upstream Connection Failure

#### Problem and Impact

The gateway returned `502 Bad Gateway` when forwarding requests to the API, even though the API was available at its intended address.

#### Investigation

I inspected `config/gateway.json`, compared it with `config/defaults/gateway.json`, and reviewed the gateway logs:

```sh
cat config/gateway.json
cat config/defaults/gateway.json
grep -nE 'ConnectionRefusedError|health|projects' logs/gateway.log
```

The logs showed `ConnectionRefusedError` for `/health` and `/projects`.

The active gateway configuration used upstream port `18099`, while the default configuration specified port `18081`.

#### Root Cause

The gateway was attempting to connect to the API on the wrong upstream port.

#### Resolution

I updated `config/gateway.json`, changing `upstream_port` from `18099` to `18081`.

#### Verification

I restarted the services and ran:

```sh
sh scripts/verify.sh
sh scripts/status.sh
ss -ltnp
```

I tested `/health` and `/projects` through the gateway and checked the listening ports to confirm that the expected service path was working.

#### Exposure and Impact Check

I checked that the gateway and API remained bound to their intended loopback addresses and that the correction did not introduce an unnecessary listener on port `18099`.

#### Prevention

- Validate upstream host and port settings automatically.
- Add gateway-to-API connectivity tests.
- Alert on repeated upstream connection failures.

### Incident 4: Application Routing Failure

#### Problem and Impact

The gateway's `/health` endpoint worked, but `/projects` returned HTTP 404 Not Found. Users could reach the gateway but could not retrieve project information through the expected endpoint.

#### Investigation

I compared `config/gateway.json` with `config/defaults/gateway.json` and inspected `logs/gateway.log`.

The active configuration used `/internal` as the API prefix instead of `/api`. The gateway logs confirmed that project requests were forwarded to `/internal/projects`, which the API did not recognise.

#### Root Cause

An incorrect API path prefix caused the gateway to forward requests to the wrong endpoint.

#### Resolution

I updated `config/gateway.json`, changing `api_prefix` from `/internal` to `/api`.

#### Verification

I restarted the services and ran:

```sh
sh scripts/verify.sh
```

The verification confirmed that `/health` and `/projects` returned HTTP 200.

#### Exposure and Impact Check

I checked the gateway and API listening addresses to ensure the routing correction did not introduce additional listening ports or expose the API beyond its intended loopback address.

#### Prevention

- Add automated tests for gateway routing and API prefixes.
- Validate important application endpoints after configuration changes.
- Include HTTP response-code checks in deployment verification.

### Incident 5: Background Worker Processing Failure

#### Problem and Impact

The background worker repeatedly failed to connect to the API, reporting `Connection refused` errors in `logs/worker.log`.

Although the API and gateway were reachable, the worker could not communicate with the API using its configured endpoint. This threatened background task processing.

#### Investigation

I inspected the worker logs and compared `config/worker.json` with `config/defaults/worker.json`.

The active worker configuration used port `18099`, while the expected API port was `18081`.

I also checked the API health endpoint directly to establish whether the API itself was available.

#### Root Cause

The worker was configured to connect to the wrong API port. The API listened on port `18081`, but the worker attempted to connect to port `18099`.

#### Resolution

I updated `config/worker.json` to use API port `18081` and restarted the lab services so the worker could use the corrected endpoint.

#### Verification

I checked the API health endpoint:

```sh
curl -i http://127.0.0.3:18081/health
```

The endpoint returned HTTP `200 OK` and reported that the database was reachable.

I also inspected `logs/worker.log`. The worker log subsequently recorded that it started with `api.projecthub.test:18081`.

**Verification limitation:** Successful background task processing has not yet been confirmed. The API health check and worker startup log establish API availability and the corrected worker endpoint, but they do not independently prove that queued tasks are being processed.

#### Prevention

- Validate worker API host and port configuration.
- Monitor repeated connection failures in worker logs.
- Add alerts for tasks that remain queued for too long.
- Test end-to-end task processing as part of incident verification.

## 4. Final Verification

After correcting the five incidents, I used the lab's verification and status scripts to check the overall service state.

```sh
sh scripts/status.sh
sh scripts/verify.sh
```

The final status output showed:

```text
api      127.0.0.3:18081  TCP reachable
gateway  127.0.0.2:18080  TCP reachable
HTTP health via gateway: 200 {
  "status": "ok",
  "service": "projecthub-api",
  "database": "reachable"
}
process dns      running
process api      running
process gateway  running
process worker   running
```

These results confirm that the API and gateway were reachable at their intended addresses, the gateway health request succeeded, the database was reachable through the application, and all four service processes were running.

However, the status output alone does not prove that the worker successfully processed a newly created task. That requires a separate end-to-end task processing test.


## 5. Evidence

Evidence for each incident is organised separately to make the investigation and verification process easy to review.

```text
submissions/
└── malikhq/
    ├── README.md
    └── evidence/
        ├── incident-1/
        ├── incident-2/
        ├── incident-3/
        ├── incident-4/
        └── incident-5/
```

The evidence should include relevant command outputs, configuration excerpts, DNS results, HTTP response codes, listening sockets, and application logs.

Examples of useful evidence include:

| Incident | Evidence to capture |
|---|---|
| Incident 1 | DNS lookup before and after the correction |
| Incident 2 | API configuration and listening socket output |
| Incident 3 | Gateway configuration, error logs, and endpoint tests |
| Incident 4 | API prefix configuration and `/projects` response |
| Incident 5 | Worker configuration, worker logs, and task state before and after processing |

Only actual outputs from the lab should be included as evidence. Screenshots can supplement these outputs but should not replace them.

## 6. Lessons Learned

This challenge reinforced several important networking and incident response principles.

1. **A running process does not guarantee service availability.** A service can be running but bound to the wrong address or listening on an unexpected port.
2. **DNS resolution is part of the application request path.** An incorrect internal hostname mapping can prevent multiple services from reaching the same API.
3. **Successful TCP connectivity does not guarantee correct application behaviour.** HTTP path prefixes and routing rules must also be correct.
4. **Troubleshooting should follow the request path.** Checking DNS, listening sockets, connection errors, gateway configuration, and application responses helps isolate failures systematically.
5. **Verification must reflect the affected component.** API health does not prove gateway routing works, and a running worker does not prove background tasks are being processed.
6. **Evidence matters.** Configuration differences, logs, connection results, and response codes provide a defensible explanation of the root cause and the fix.

## 7. Production Improvements

If I owned this service in production, I would introduce the following improvements:

- Automated configuration validation for DNS records, listener addresses, upstream ports, and API prefixes.
- End-to-end synthetic checks that test the complete client-to-gateway-to-API request path.
- Worker health checks that validate processing progress rather than only process availability.
- Monitoring and alerting for HTTP 5xx responses, connection failures, DNS errors, and tasks stuck in the queue.
- Structured logs containing request identifiers and relevant service details to improve incident correlation.
- Deployment checks that validate application behaviour before and after configuration changes.
- Documented runbooks for common DNS, TCP, reverse-proxy, and background-processing failures.

## 8. Conclusion

The ProjectHub Network Incident Response Lab provided practical experience investigating and resolving five networking incidents across DNS, TCP connectivity, service binding, HTTP routing, and background worker communication.

I used configuration comparisons, service logs, listening socket checks, and HTTP verification to identify the reported failures and apply targeted corrections.

The main lesson was to troubleshoot the complete service path, validate each hypothesis with evidence, and verify recovery from the perspective of the affected client or component.

Before final submission, I will ensure the evidence directories contain the actual outputs from each investigation and complete the end-to-end task processing and stop/start verification checks.

## 9. References

- [CloudPros Community Projects](https://github.com/joincloudpros/cloudpros-community-projects)
- `task.md` — Challenge instructions and incident requirements
- `docs/architecture.md` — Service architecture and application endpoints


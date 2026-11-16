# ProjectHub lab architecture

The lab represents a compact SaaS deployment. All services run as separate local processes and communicate over loopback TCP or UDP. The use of different loopback addresses makes listener and upstream-address problems reproducible without exposing a service to the LAN or internet.

## Network map

| Component | Address | Protocol | Purpose |
|---|---|---|---|
| Edge gateway | `127.0.0.2:18080` | HTTP over TCP | Client entry point and reverse proxy |
| ProjectHub API | `127.0.0.3:18081` | HTTP over TCP | Projects, tasks and worker API |
| Lab DNS | `127.0.0.4:15353` | DNS over UDP | Resolves the private `projecthub.test` names |
| Fault-test port | `127.0.0.1:18099` | TCP | Deliberately unused in the healthy baseline |

The private DNS zone contains:

| Name | Healthy A record |
|---|---|
| `edge.projecthub.test` | `127.0.0.2` |
| `api.projecthub.test` | `127.0.0.3` |

The lab DNS service is authoritative only for this exercise. It is not configured as the computer's system resolver and does not forward public DNS requests.

## Request flow

```text
Browser / curl
      |
      | HTTP :18080
      v
Edge gateway (127.0.0.2)
      |
      | DNS A lookup: api.projecthub.test
      | TCP / HTTP :18081
      v
ProjectHub API (127.0.0.3)
      |
      | SQLite database
      v
Project and task records

Background worker
      |
      | DNS A lookup + TCP / HTTP
      +--------------------------> ProjectHub API
```

The gateway maps public application paths to the API's `/api` routes. The worker communicates with the API independently of the gateway. This allows an incident to affect one request path while another remains healthy.

## HTTP endpoints

| Method | Gateway path | Purpose |
|---|---|---|
| `GET` | `/health` | API and database health through the gateway |
| `GET` | `/projects` | List seeded projects |
| `GET` | `/tasks` | List tasks and processing status |
| `POST` | `/tasks` | Create a task for the background worker |

Example task body:

```json
{"title": "Prepare the network change plan"}
```

A newly created task starts as `queued`. The background worker retrieves it through the API and changes its state to `processed`.

## Configuration and logs

Active configuration is stored in `config/*.json`; known-good starting values are in `config/defaults/`. Runtime data is stored in `state/`, and process output is written to `logs/`.

The fault injector changes only the lab's own configuration. It does not change system DNS, host firewall rules or operating-system network configuration.

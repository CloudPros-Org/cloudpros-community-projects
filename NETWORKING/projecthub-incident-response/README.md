# ProjectHub: Network Incident Response Lab

A one-week, hands-on network troubleshooting challenge built around a small SaaS platform running on a single machine.

You will investigate five production-style incidents involving DNS, TCP connectivity, service binding, HTTP reverse-proxy behaviour and communication between application services. The lab includes the application, a private DNS listener, an HTTP gateway, an API, a background worker and all setup/fault-injection scripts.

## What is included

- **Private DNS service:** a small authoritative DNS service for the lab's private hostnames. It uses real DNS queries over UDP and does not change your computer's DNS settings.
- **HTTP gateway:** accepts client requests and forwards them to the API over TCP.
- **ProjectHub API:** serves project and task data backed by SQLite.
- **Background worker:** polls the API and processes queued tasks.
- **Fault injector:** introduces five controlled incidents in sequence without disclosing the configuration change.
- **Reset and verification tools:** restore the baseline, check the application and support repeatable testing.

Everything runs directly as ordinary processes. **Docker is not used.** The Python application uses only the standard library; no `pip install` is required.

## Requirements

- Python 3.10 or newer
- Bash or zsh (the supplied shell scripts use portable `/bin/sh` syntax)
- `curl` is useful for exercising the HTTP endpoints
- The lab uses loopback addresses and the following ports: TCP `18080`, `18081`, `18099`; UDP `15353`

No administrator privileges are required. The lab does not modify `/etc/hosts`, `/etc/resolv.conf`, system firewall rules or other machine-wide settings.

## Start the lab

From the project directory:

```sh
sh scripts/setup.sh
sh scripts/start.sh
sh scripts/status.sh
sh scripts/verify.sh
```

The baseline verification should pass before you begin the challenge.

Open the application endpoints locally:

- Gateway health: `http://127.0.0.2:18080/health`
- Projects: `http://127.0.0.2:18080/projects`
- Tasks: `http://127.0.0.2:18080/tasks`

The private lab DNS server listens on `127.0.0.4:15353/udp`. The lab hostnames are `edge.projecthub.test` and `api.projecthub.test`. Use the supplied `sh scripts/dns-lookup.sh <hostname>` helper to query the lab DNS service. You can also use a DNS client that supports specifying both a server address and a non-standard port.

## Daily workflow

Introduce the incidents in order, and only move on after you have resolved and documented the current one:

```sh
sh scripts/inject-incident.sh 1
```

The script stops and restarts the lab with the next fault in place. It deliberately does not tell you what changed. Your corrections remain in the active configuration when the next incident is introduced, so unresolved faults will accumulate.

After each fix, restart the affected lab processes if your changes require it, then verify the expected behaviour. The general controls are:

```sh
sh scripts/stop.sh
sh scripts/start.sh
sh scripts/status.sh
sh scripts/verify.sh
```

To return to a clean baseline and remove local lab data/logs:

```sh
sh scripts/reset.sh
sh scripts/start.sh
sh scripts/verify.sh
```

**Warning:** reset removes the local SQLite database and lab logs. Save any evidence you need before resetting.

## Documentation

- Read [`task.md`](task.md) for the scenario, five incident tickets, evidence requirements and submission instructions.
- Read [`docs/architecture.md`](docs/architecture.md) for the service map and application endpoints.


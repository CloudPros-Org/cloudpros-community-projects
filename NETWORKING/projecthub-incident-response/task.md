# CloudPros Weekly Community Project

## ProjectHub: Network Operations and Production Incident Response

**Duration:** One week  
**Submission:** GitHub Pull Request  
**Environment:** macOS Terminal, Windows WSL2 Ubuntu, or Linux  
**Focus:** Network troubleshooting, service connectivity, DNS, HTTP routing and incident analysis

---

## The Scenario

You've joined **ProjectHub**, a growing SaaS company, as a DevOps Engineer. ProjectHub operates a web-based project management platform used by customers to organise projects, assign tasks and track delivery.

The platform runs as a small collection of services on a single host. Customers access it through an edge gateway, the gateway forwards requests to an API, and a background worker communicates with that API to process queued tasks. The services rely on private DNS records to locate one another.

The support team has reported a series of incidents affecting the platform. You have been given the application repository and access to the lab environment. Your responsibility is to investigate each report, establish what is failing, restore normal service and provide evidence that your changes have worked.

You are expected to approach this as the engineer responsible for the service. The incident reports describe symptoms, not solutions. You will need to research the relevant networking concepts, decide how to investigate each issue and explain why your chosen fix is appropriate.

## What We Provide

The repository contains the complete runnable lab:

- A private DNS service using real DNS queries over UDP.
- An HTTP edge gateway that reverse-proxies requests to the API.
- A ProjectHub API with seeded project data and task creation.
- A background worker that processes tasks through the API.
- Configuration files and known-good defaults.
- Setup, start, stop, verification, reset and fault-injection scripts.

The application uses Python's standard library only. There are no third-party Python packages to install, no Docker containers and no cloud resources to provision.

**The lab is deliberately isolated.** Services bind only to loopback addresses. The setup and fault-injection scripts do not modify your computer's system DNS, `/etc/hosts`, firewall rules or other machine-wide network settings. You do not need administrator privileges.

## Environment Requirements

Use one of the following:

- **Windows:** Ubuntu 24.04 through WSL2. Run the project from the WSL filesystem and use its terminal.
- **macOS:** macOS Terminal. The supplied scripts work from Bash or zsh; Python 3.10 or newer is required.
- **Linux:** A normal terminal with Python 3.10 or newer.

The shell scripts use portable `/bin/sh` syntax. Invoke them with `sh` from Bash or zsh.

The lab uses these local ports:

| Port | Protocol | Purpose |
|---|---|---|
| `18080` | TCP | Edge gateway |
| `18081` | TCP | API |
| `18099` | TCP | Fault-injection target |
| `15353` | UDP | Private lab DNS |

The setup script checks that these ports are available before initialising the lab.

## Set Up the Environment

1. Fork and clone the CloudPros repository.
2. Open a terminal in the project directory:

   ```sh
   cd NETWORKING/projecthub-incident-response
   ```

3. Run the setup script:

   ```sh
   sh scripts/setup.sh
   ```

4. Start the services:

   ```sh
   sh scripts/start.sh
   ```

5. Check the service status and confirm that the healthy baseline passes:

   ```sh
   sh scripts/status.sh
   sh scripts/verify.sh
   ```

Do not introduce an incident until the baseline verification succeeds. If it does not, resolve the environment/setup issue first and ask for help if needed.

## Understand the Service

The edge gateway is the client entry point. The API serves project and task data. The worker retrieves queued tasks through the API and marks them as processed. The private DNS service resolves the lab's internal hostnames.

The service map and application endpoints are documented in [`docs/architecture.md`](docs/architecture.md). You should understand the normal request flow before troubleshooting failures.

The main application endpoints are:

| Method | Endpoint | Expected behaviour |
|---|---|---|
| `GET` | `http://127.0.0.2:18080/health` | Returns a healthy API/database response |
| `GET` | `http://127.0.0.2:18080/projects` | Returns the seeded ProjectHub projects |
| `GET` | `http://127.0.0.2:18080/tasks` | Returns tasks and their processing states |
| `POST` | `http://127.0.0.2:18080/tasks` | Creates a task for the background worker |

A task created through the application should move from `queued` to `processed` when the worker is operating correctly.

## Your Incidents

There are five incidents, introduced progressively throughout the week. Each ticket describes what users or the support team are experiencing. You are responsible for determining the underlying cause.

### Incident 1: Service discovery failure

The support team reports that requests passing through the edge gateway are failing. The API process appears to be running, but the gateway and background worker are reporting problems when trying to reach it by its service name.

**Your responsibility:** Investigate the name-resolution and connectivity path. Restore service discovery and demonstrate that both the gateway and worker can communicate with the intended API endpoint.

### Incident 2: API service reachability failure

The edge gateway is reachable, but it cannot establish a connection to the API at its documented internal address. The API process appears to be running, and a check against a different local address produces a different result.

**Your responsibility:** Investigate the API's listener and the addresses on which it is available. Restore the intended service reachability and demonstrate that the gateway can communicate with the API.

### Incident 3: Upstream connection failure

The API responds when checked directly at its documented internal address, but requests passing through the edge gateway receive gateway errors. Restarting the gateway does not resolve the issue.

**Your responsibility:** Trace the request path from the edge to the API. Identify the remaining connectivity failure, correct it and demonstrate successful requests through the gateway.

### Incident 4: Application routing failure

The edge gateway and API are both reachable. The health endpoint responds, but the projects endpoint returns an unexpected HTTP response. Users cannot access project information.

**Your responsibility:** Investigate the HTTP request path between the gateway and API. Restore the expected routing behaviour and verify both health and application endpoints.

### Incident 5: Background processing outage

Users can create tasks successfully, but newly created tasks remain queued and are not processed. The website and API appear to be operating normally, and the worker process is still running.

**Your responsibility:** Investigate the worker's communication with the API, restore processing and demonstrate that queued work is completed without manually changing task records.

## Introducing the Incidents

Introduce the first incident with:

```sh
sh scripts/inject-incident.sh 1
```

After resolving and documenting it, introduce the next incident with `2`, then `3`, `4` and `5` in order.

**Important:** The injector preserves your previous configuration changes. It adds the next fault rather than resetting the environment. This is intentional: unresolved issues can accumulate, just as they can during a sequence of production incidents. Resolve and verify each ticket before moving on.

The injector restarts the lab services after applying each fault. It does not disclose which setting it changed.

Do not run `reset.sh` between incidents. Reset is for returning to a clean baseline if you need to restart the entire challenge. It removes the local database and lab logs, so save any evidence you need first.

## What You Must Demonstrate

For every incident, provide evidence that you have:

1. Reproduced and described the reported symptom.
2. Investigated the relevant network path and service behaviour.
3. Identified the root cause, supported by evidence from your own environment.
4. Applied a justified correction.
5. Verified the service from the relevant client or component perspective, not just by checking that a process is running.
6. Considered whether the change introduces any unintended exposure or affects another service.

At the end of the challenge, demonstrate all of the following:

- The private service names resolve to the intended addresses.
- The edge gateway accepts requests at its documented address.
- The gateway can reach the API and the application endpoints return the expected responses.
- The background worker can reach the API and process newly created tasks.
- The overall verification script passes.
- Your fixes remain effective after stopping and starting the lab services.

## Submission Requirements

Create a folder for your work at:

```text
NETWORKING/projecthub-incident-response/submissions/<your-github-handle>/
```

Include:

```text
submissions/<your-github-handle>/
├── README.md
└── evidence/
    ├── incident-1/
    ├── incident-2/
    ├── incident-3/
    ├── incident-4/
    └── incident-5/
```

Your README must contain an incident report for each ticket. For every report, explain:

- **Impact:** What users or internal services experienced.
- **Investigation:** What you examined, what you tried and why you chose that approach.
- **Evidence:** Relevant command output, DNS responses, connection results, logs or configuration excerpts.
- **Root cause:** What was actually wrong and how the evidence supports your conclusion.
- **Resolution:** What you changed and why.
- **Verification:** How you proved the incident was resolved from the perspective of the affected client or service.
- **Prevention:** A practical recommendation that could reduce the likelihood or impact of a similar incident.

Include the actual outputs from your own lab. Screenshots can support your report, but screenshots alone are not sufficient. Do not paste generic explanations in place of evidence from your environment. Redact usernames or other personal information if necessary, but do not remove the IP addresses, ports, response codes or relevant log details needed to understand your diagnosis.

Your final report should also include:

- A brief description of the service architecture.
- The final verification results.
- Any differences you encountered between macOS, WSL2 or Linux.
- What you learnt and what you would improve if you owned this service in production.

## Submission Instructions

1. Create a working branch in your fork.
2. Add your work only under `NETWORKING/projecthub-incident-response/submissions/<your-github-handle>/`.
3. You may edit the active configuration files locally to diagnose and fix the incidents. Do not commit changes to the shared challenge files; your Pull Request should contain only your own submission folder. Do not modify another member's submission.
4. Open a Pull Request into the **`week4-projecthub-network-incident-response`** branch in the CloudPros repository, not `main`.
5. Use this PR title: `[Networking] ProjectHub Incident Response - Your Name`.
6. Explain what you investigated, how you verified your fixes and what you learnt.
7. Mention **@joincloudpros** for review and leave your PR open. Do not merge your own submission.

## Final Checklist

- [ ] Environment setup completed and healthy baseline verified
- [ ] All five incidents introduced in order
- [ ] Root cause and evidence documented for every incident
- [ ] Each fix verified from the affected service/client perspective
- [ ] Private DNS, gateway, API and worker all operate correctly
- [ ] New tasks are processed successfully
- [ ] Final verification passes after a stop/start cycle
- [ ] README and evidence folders are complete
- [ ] PR targets `week4-projecthub-network-incident-response` and is left open

## Getting Help

If you get stuck, ask in the CloudPros **Ask for Help** group. Share the incident you are working on, the impact you can reproduce, the evidence you have collected and what you have already tried. Avoid sharing only a screenshot of an error without context.

The aim is to develop sound network troubleshooting judgement: understand the path, gather evidence, test a hypothesis, make a controlled change and verify the result.

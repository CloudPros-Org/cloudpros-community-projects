# CloudPros Weekly Community Project

## Week 2: Containerise a 3-Tier Application

**Deadline:** Sunday, 8 November 2026, 11:59 PM (GMT)  
**Submission:** GitHub Pull Request  
**Difficulty:** Hands-on Docker and Docker Compose

---

## Problem Statement

"It works on my machine" is not a deployment strategy.

This week, your challenge is to package a small Notes API, its PostgreSQL database and an Nginx reverse proxy so someone else can run the entire application with **one command**.

The focus is on **Docker, Docker Compose, container networking, image optimisation, health checks, persistent data and configuration management**, not on building a complicated application.

## What You're Building

A small Notes API written in **Python (Flask or FastAPI)** or **Node.js (Express)**, backed by **PostgreSQL 16**.

The API must provide:

| Endpoint | Purpose |
| --- | --- |
| `GET /health` | Return a successful health response when the application is ready |
| `GET /notes` | List saved notes from PostgreSQL |
| `POST /notes` | Create a note and save it to PostgreSQL |

You may use AI to help write the small API, but **the Docker work must be yours**. You should understand and be able to explain everything you submit.

## Tools

- Docker
- Docker Compose (the `docker compose` CLI)
- Nginx
- PostgreSQL 16
- Python or Node.js
- Git and GitHub

**Cost:** Free, using a local Docker environment.

---

## Project Requirements

### 1. Compose three services

Create a `docker-compose.yml` (or `compose.yml`) containing exactly these three application services:

- `proxy`: Nginx
- `api`: your Notes API
- `db`: PostgreSQL 16

The services must communicate using Docker networking and service names, not hard-coded container IP addresses.

### 2. Publish only the proxy

- Publish Nginx to the host on **port 8080**.
- **Do not** add a `ports:` section to the `api` or `db` services.
- Requests from the host must go through Nginx to the API.
- The database must not be directly published to the host.

**Expected outcome:** `http://localhost:8080/health` and `http://localhost:8080/notes` work through Nginx.

### 3. Build a small, secure API image

- Write a **multi-stage Dockerfile** for the API.
- Run the application as a **non-root user**.
- Keep the **final image below 200 MB**.
- Include a useful `.dockerignore`.
- Do not bake credentials or secrets into the image.

Show the final image size in your evidence. You may choose Python or Node.js, but the size limit applies either way.

### 4. Add health checks and startup dependencies

- Configure a working Docker health check for **PostgreSQL**.
- Configure a working Docker health check for the **API**.
- The API must wait for the database to become **healthy** before starting.
- The proxy must wait for the API to become **healthy** before starting.

Use Compose health-aware dependencies such as `depends_on` with `condition: service_healthy`. A container merely being started is not proof that its application is ready.

### 5. Persist notes

Use a **named Docker volume** for PostgreSQL data.

Create a note, run:

```bash
docker compose down
docker compose up -d
```

Then verify that the note still exists.

**Important:** Do not use `docker compose down -v` for the persistence test, because `-v` removes the named volume.

### 6. Manage configuration safely

- Load database credentials from a local `.env` file.
- Add `.env` to `.gitignore`.
- Commit a safe `.env.example` containing example values.
- Do not commit real passwords, tokens or other secrets.
- Document any variables contributors need to set.

### 7. Use two networks

Create two Compose networks:

| Network | Members |
| --- | --- |
| `frontend` | `proxy` and `api` |
| `backend` | `api` and `db` |

The proxy **must not** join the backend network and must not be able to reach the database directly. The API bridges the two networks.

### 8. Make it reproducible from a fresh clone

A new contributor should be able to run:

```bash
cp .env.example .env
docker compose up -d --build
```

and have a working application without manual database setup or other undocumented steps.

Make sure the application initialises its database table automatically if required.

---

## Evidence Required

Include your commands, outputs or screenshots in your submission README or an `evidence/` directory. Demonstrate:

1. **Services and health:** `docker compose ps` shows all three services running and the DB and API healthy.
2. **API through Nginx:** `curl http://localhost:8080/health`, `curl http://localhost:8080/notes`, and a successful `POST /notes` request.
3. **Ports:** `docker compose ps` or `docker port` confirms only the proxy is published on host port 8080.
4. **Image:** `docker image ls` (or equivalent) confirms the API's final image is under 200 MB; explain your multi-stage build and non-root user.
5. **Network isolation:** show that the proxy has no direct route to the database through the Compose networks, and that the API belongs to both.
6. **Persistence:** show the note before and after `docker compose down` and `docker compose up -d`.
7. **Configuration:** include `.env.example`, confirm `.env` is ignored, and show that a fresh-clone setup works.

Explain any problems you encountered, how you troubleshot them, and the reasoning behind your design choices.

---

## Suggested Project Layout

Keep each submission in its own folder so contributors do not overwrite one another:

```text
DOCKER/
└── three-tier-notes-app/
    ├── task.md
    ├── README.md
    ├── assets/
    └── submissions/
        └── <your-github-username>/
            ├── README.md
            ├── docker-compose.yml
            ├── Dockerfile
            ├── .dockerignore
            ├── .gitignore
            ├── .env.example
            ├── nginx/
            ├── api/
            └── evidence/
```

This is a suggested layout. You may organise files differently inside **your own submission folder** as long as the solution is easy to run and review.

## Submission Instructions

1. Fork the CloudPros community projects repository and create a branch for Week 2.
2. Add your work under `DOCKER/three-tier-notes-app/submissions/<your-github-username>/`.
3. Include a README with setup instructions, design decisions, tests and evidence.
4. Open a Pull Request against the designated submissions branch, following the repository's existing contribution workflow. **Do not merge your own PR before review.**
5. Use the title: `[Week 2] Containerise a 3-Tier App - Your Name`.
6. In the PR description, summarise what you built, how you tested it, what you learnt and anything you struggled with.

## Submission Checklist

- [ ] Notes API supports `GET /health`, `GET /notes`, `POST /notes`
- [ ] Notes are stored in PostgreSQL 16
- [ ] Compose defines `proxy`, `api`, `db`
- [ ] Only Nginx is published on host port 8080
- [ ] Multi-stage API Dockerfile, non-root user, final image under 200 MB
- [ ] `.dockerignore` is present
- [ ] DB and API have working health checks and correct startup dependencies
- [ ] Notes survive `docker compose down` and `docker compose up -d`
- [ ] Credentials come from ignored `.env`; safe `.env.example` is committed
- [ ] `frontend` and `backend` networks isolate the proxy from the DB
- [ ] Fresh-clone command works
- [ ] README and testing evidence are included
- [ ] PR is submitted for review, not self-merged

## Getting Help

If you're stuck, ask in the community's **Ask for Help** group. Share what you're trying to achieve, what you've already attempted, and the errors you're seeing.

**The aim isn't just to get the containers running. Understand why your setup works, what each service is responsible for, and the trade-offs behind your decisions.**

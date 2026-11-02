# Week 2: Containerise a 3-Tier Application

Build a small Notes API backed by PostgreSQL 16 and served through Nginx, all started with one Docker Compose command.

**Deadline:** Sunday, 8 November 2026, 11:59 PM (GMT)

## Start here

Read the full [project brief and requirements](task.md).

### Overview

- **API:** Python (Flask/FastAPI) or Node (Express)
- **Endpoints:** `GET /health`, `GET /notes`, `POST /notes`
- **Services:** `proxy` (Nginx), `api`, `db` (PostgreSQL 16)
- **Host port:** 8080, exposed by the proxy only
- **Core skills:** multi-stage builds, non-root images, health checks, Compose networks, persistent volumes and environment variables

### Expected fresh-clone experience

```bash
cp .env.example .env
docker compose up -d --build
```

Run these commands **from your own submission directory**, where your Compose file and `.env.example` live.

## Submitting

Add your solution to `submissions/<your-github-username>/` and open a PR titled `[Week 2] Containerise a 3-Tier App - Your Name`. Include a README and testing evidence. Please do not merge your own PR before review.

Questions? Use the CloudPros **Ask for Help** group.

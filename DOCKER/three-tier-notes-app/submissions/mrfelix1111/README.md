# Three-Tier Notes Application

## Project Overview

This project containerises a three-tier Notes application using Docker Compose.

The application consists of:
- Nginx as the reverse proxy.
- A Python Flask REST API.
- PostgreSQL 16 as the database.

All services are managed using Docker Compose.

## Architecture

The application uses three services:

| Service | Technology | Purpose |
|---|---|---|
| Proxy | Nginx | Reverse proxy and external entry point |
| API | Python Flask | Handles application requests |
| Database | PostgreSQL 16 | Stores notes persistently |

### Network Architecture

Two separate Docker bridge networks are used:

- **Frontend:** Connects Nginx and the API.
- **Backend:** Connects the API and PostgreSQL.

The Nginx proxy cannot directly access the database.

Only Nginx publishes a port to the host:

- Host port: 8080
- Container port: 80

The API and database are not exposed directly to the host.

## Prerequisites

- Docker Engine
- Docker Compose v2

## Project Setup

Clone the repository and navigate to this directory:

```bash
cd DOCKER/three-tier-notes-app/submissions/mrfelix1111
cp .env.example .env
nano .env
```

Replace the example POSTGRES_PASSWORD with a secure password of your choice, then save the file.

Start the application:

```bash
docker compose up -d --build
```


## Environment Variables

The application uses these environment variables:

| Variable | Description |
|---|---|
| POSTGRES_DB | PostgreSQL database name |
| POSTGRES_USER | PostgreSQL username |
| POSTGRES_PASSWORD | PostgreSQL password |

The `.env` file is excluded from Git. Only `.env.example` is committed.

## API Endpoints

The API is accessible through Nginx at `http://localhost:8080`.

| Method | Endpoint | Description |
|---|---|---|
| GET | /health | Checks API and database health |
| GET | /notes | Retrieves all notes |
| POST | /notes | Creates a new note |

## Testing the API

Check application health:

```bash
curl http://localhost:8080/health

```

Retrieve all notes:

```bash
curl http://localhost:8080/notes
```

Create a note:

```bash
curl -X POST http://localhost:8080/notes \
  -H "Content-Type: application/json" \
  -d '{"content":"My first Docker note"}'
```

## Data Persistence

PostgreSQL data is stored in a named Docker volume called `postgres_data`.

Data remains available after stopping and recreating containers:

```bash
docker compose down
docker compose up -d
```

Do not use `docker compose down -v` if you want to preserve database data.

## Security and Design

- The API runs as a non-root user named `appuser`.
- The API Dockerfile uses a multi-stage build.
- Only Nginx publishes a host port.
- The API and database are not directly exposed to the host.
- Separate frontend and backend networks provide network isolation.
- Docker healthchecks monitor the API and database.
- The API waits for the database to become healthy.
- Nginx waits for the API to become healthy.
- Environment credentials are not committed to Git.

## API Image Size

The final built API Docker image is approximately 97.9 MB in Docker's reported disk usage, with a content size of 24 MB. This is below the assignment's 200 MB requirement.

## Challenges and Solutions

During development, Docker initially experienced DNS resolution issues when downloading dependencies and building the API image in WSL2.

This was resolved by configuring DNS servers in the Docker daemon configuration and restarting Docker. After the change, image builds completed successfully.

## Useful Commands

```bash
docker compose ps
docker compose logs -f
docker compose logs api
docker compose restart
docker compose down
```

## Conclusion

This project demonstrates a containerised three-tier application using Nginx, Python Flask and PostgreSQL 16. Docker Compose manages the services, healthchecks, networks and persistent database storage.

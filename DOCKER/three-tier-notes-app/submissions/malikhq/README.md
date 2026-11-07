
# Week 2: Containerise a 3-Tier Application

A Notes API built with Flask, PostgreSQL 16, and Nginx, orchestrated using Docker Compose.

## Architecture

- **Proxy:** Nginx receives requests on port 8080 and forwards them to the API.
- **API:** Flask, served by Gunicorn, implements the health and notes endpoints.
- **Database:** PostgreSQL 16 stores notes persistently.
- **Networks:** Separate frontend and backend networks.
- **Volume:** A named Docker volume persists PostgreSQL data.
- **Health checks:** Compose checks the database, API, and proxy.
- **Security:** The API runs as a non-root user with a read-only root filesystem and dropped Linux capabilities.

## Prerequisites

- Docker Engine
- Docker Compose plugin
- Git

## Start the application

Run these commands from this directory:

```bash
cp .env.example .env
```

Edit `.env` and replace the example password with a strong, unique password.

Start all services:

```bash
docker compose up -d --build
docker compose ps
```

The application is available at:

http://localhost:8080

## API endpoints

### Health check

```bash
curl -i http://localhost:8080/health
```

Expected: HTTP 200 with a JSON response indicating that the API and database are healthy.

### List notes

```bash
curl -i http://localhost:8080/notes
```

Expected: HTTP 200 with a JSON array.

### Create a note

```bash
curl -i -X POST http://localhost:8080/notes \
  -H "Content-Type: application/json" \
  -d '{"title":"My first note","content":"Testing Docker Compose"}'
```

Expected: HTTP 201 with the newly created note.

### Validate invalid input

```bash
curl -i -X POST http://localhost:8080/notes \
  -H "Content-Type: application/json" \
  -d '{"content":"Missing title"}'
```

Expected: HTTP 400.

## Persistence test

Create a note before running the following commands:

```bash
docker compose down
docker compose up -d
curl -i http://localhost:8080/notes
```

The previously created note should remain available because the PostgreSQL named volume is retained.

Do not use `docker compose down -v` during this test because it deletes the named volume.

## Troubleshooting

Check service status:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs --tail=100
docker compose logs api
docker compose logs db
docker compose logs proxy
```

Validate the Compose configuration:

```bash
docker compose config
```

## Testing evidence

Capture actual terminal output or screenshots demonstrating:

- [ ] All three services start successfully.
- [ ] All service health checks pass.
- [ ] `GET /health` returns HTTP 200.
- [ ] `GET /notes` returns JSON.
- [ ] `POST /notes` creates a note and returns HTTP 201.
- [ ] Invalid input returns HTTP 400.
- [ ] Notes persist after containers are recreated.
- [ ] Only Nginx publishes host port 8080.
- [ ] The API runs as a non-root user.

Only mark tests as passed after running them.

## Security considerations

- The API uses a multi-stage Docker build.
- The API runs as a non-root user.
- The API root filesystem is read-only.
- Linux capabilities are dropped from the API container.
- Database credentials are supplied through environment variables.
- The database is not published to the host.
- Nginx configuration is mounted read-only.

For production deployments, consider a secrets manager, image digest pinning, vulnerability scanning, resource limits, and verified database backups.

## Stop the application

```bash
docker compose down
```

This stops and removes the containers and network while preserving the named database volume.

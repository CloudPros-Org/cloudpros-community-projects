# CloudPros Week 2: Containerise a 3-Tier Notes Application

**Contributor:** Paul Egboh (`poshpeck`)
**Project:** Week 2 – Containerise a 3-Tier Application
**Technology:** Docker, Docker Compose, Python, Flask, PostgreSQL 16 and Nginx

## 1. Project Overview

This project containerises a Notes API backed by PostgreSQL 16 and served through an Nginx reverse proxy.

The application is deployed using Docker Compose and consists of exactly three services:

- **Proxy:** Nginx receives external HTTP requests and forwards them to the API.
- **API:** A Python Flask application provides endpoints for checking application health and managing notes.
- **Database:** PostgreSQL 16 stores notes persistently.

The application can be started with a single Docker Compose command.

## 2. Architecture

```text
                 Host machine
                http://localhost:8080
                         |
                         v
                +----------------+
                |   Nginx Proxy  |
                |     proxy      |
                +----------------+
                         |
                  frontend network
                         |
                         v
                +----------------+
                |   Flask API    |
                |      api       |
                +----------------+
                         |
                  backend network
                         |
                         v
                +----------------+
                |  PostgreSQL 16 |
                |       db       |
                +----------------+
                         |
                  Named volume
                  postgres_data
```

### Network design

Two separate Docker bridge networks provide service isolation:

| Network | Connected services |
|---|---|
| frontend | proxy and api |
| backend | api and db |

The proxy does not join the backend network and therefore has no direct network connection to PostgreSQL. The API connects both networks.

Only the proxy publishes a port to the host:

`8080:80`

The API and database are accessible internally through Docker service names.

## 3. Project Structure

```text
poshpeck/
├── api/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .dockerignore
├── db/
│   └── init/
│       └── 01-create-notes-table.sql
├── nginx/
│   ├── Dockerfile
│   └── nginx.conf
├── tests/
│   └── test_api.py
├── evidence/
├── .env.example
├── .gitignore
├── docker-compose.yml
└── README.md
```

## 4. Technologies Used

- Docker and Docker Compose
- Python 3.12
- Flask 3.1.2
- Gunicorn 23.0.0
- Psycopg 3.2.10
- PostgreSQL 16
- Nginx Alpine
- Pytest
- Requests

## 5. Application Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | Checks API and database availability |
| GET | `/notes` | Retrieves saved notes |
| POST | `/notes` | Creates and stores a new note |

### Example: Create a note

```bash
curl -X POST http://localhost:8080/notes \
  -H "Content-Type: application/json" \
  -d '{"title":"My first note","content":"Testing the Notes API."}'
```

### Retrieve notes

```bash
curl http://localhost:8080/notes
```

### Check application health

```bash
curl http://localhost:8080/health
```

## 6. Getting Started

### Prerequisites

- Docker Engine
- Docker Compose plugin
- Git

### Step 1: Configure environment variables

From this submission directory:

```bash
cp .env.example .env
```

Edit `.env` and replace the placeholder database password with a secure password.

The environment variables are:

| Variable | Purpose |
|---|---|
| POSTGRES_DB | PostgreSQL database name |
| POSTGRES_USER | PostgreSQL username |
| POSTGRES_PASSWORD | PostgreSQL password |
| DB_HOST | Database service hostname |
| DB_PORT | PostgreSQL port |

### Step 2: Start the application

```bash
docker compose up -d --build
```

### Step 3: Check the services

```bash
docker compose ps
```

The database and API should report healthy status.

### Step 4: Access the application

Open:

`http://localhost:8080/health`

The application should return a healthy response.

## 7. Docker Security and Optimisation

### Multi-stage API build

The API Dockerfile uses a multi-stage build:

1. The builder stage installs Python dependencies.
2. The production stage copies the installed dependencies and application code into a clean Python image.

This reduces unnecessary build content in the final image.

### Non-root execution

The API runs under a dedicated Linux user named `app`, rather than root.

Verified container identity:

```text
uid=999(app) gid=999(app) groups=999(app)
```

### Image size

Verified API image size:

```text
140010371 bytes
134M
```

This is below the required 200 MB limit.

### Secrets management

Database credentials are loaded through the local `.env` file.

The `.env` file is excluded through `.gitignore`. A safe `.env.example` is included for contributors.

Credentials are not baked into the API image.

## 8. Health Checks and Startup Dependencies

The PostgreSQL service uses `pg_isready` to determine database readiness.

The API health check sends a request to its health endpoint and verifies that the application and database are available.

Compose startup dependencies use `condition: service_healthy`:

- The API waits for PostgreSQL to become healthy.
- The proxy waits for the API to become healthy.

This ensures that dependent services do not start simply because their containers have been created.

## 9. Database Persistence

PostgreSQL data is stored in a named Docker volume:

`postgres_data`

The persistence test was performed using:

```bash
docker compose down
docker compose up -d
```

A test note was created before stopping the application. After the containers were removed and recreated, the note was retrieved successfully.

This verified that database records survive container recreation.

**Note:** Do not use `docker compose down -v` when testing persistence, as that removes the named volume.

## 10. Automated Testing

The project includes automated API tests using Pytest and Requests.

Install the development dependencies:

```bash
pip install -r requirements-dev.txt
```

Run the tests:

```bash
python -m pytest -v
```

### Test results

**7 tests passed.**

The tests cover:

1. API health endpoint.
2. Retrieving notes.
3. Creating a note.
4. Missing note title validation.
5. Missing note content validation.
6. Invalid JSON validation.
7. Title length validation.

The tests were executed successfully against the application through Nginx on port 8080.

## 11. Network Isolation Verification

Docker inspection confirmed the following network memberships:

| Container | Network membership |
|---|---|
| Proxy | frontend |
| API | frontend and backend |
| Database | backend |

This demonstrates the intended separation between the public-facing proxy and the database.

## 12. Troubleshooting and Lessons Learned

During development, Docker image downloads initially encountered a DNS resolution problem in the WSL environment. This was resolved by configuring Docker daemon DNS servers.

The project also reinforced the importance of:

- Using Docker service names instead of fixed container IP addresses.
- Separating frontend and backend networks.
- Using health-aware startup dependencies.
- Persisting database data in named volumes.
- Keeping secrets outside source control.
- Using multi-stage builds to reduce image size.
- Running containers with non-root privileges.
- Testing persistence after container recreation.

## 13. Conclusion

The completed application demonstrates a reproducible three-tier Docker deployment using Nginx, Flask and PostgreSQL 16.

The API endpoints, database connectivity, health checks, network isolation, image optimisation, non-root execution and persistent storage were tested successfully.

The final automated test result was **7 passed**, and the API image size was verified at **134 MiB**, below the required 200 MB limit.

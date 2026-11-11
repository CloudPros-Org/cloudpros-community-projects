# Setup instructions

Prerequisites

- Docker with the Compose plugin (`docker compose version` should work)
- Git
- Port 8080 free on your machine, because Nginx publishes it

Python and PostgreSQL do not need to be installed. Everything runs in containers.

1. Get the code

git clone https://github.com/temi-daniel/cloudpros-community-projects.git
cd cloudpros-community-projects
git checkout week-2-notes-app
cd DOCKER/three-tier-notes-app/submissions/temi-daniel

Run every command below from this folder, because Docker Compose reads (docker-compose.yaml) and (.env) from the folder you run it in.

2. Create the .env file

Copy the template, then edit the new file and set your own values:

cp .env.example .env

POSTGRES_USER - Database username, created when Postgres first starts
POSTGRES_PASSWORD - Password for that user
POSTGRES_DB -  Name of the database the API uses

Notes:
- Use letters and numbers in the password. Characters like @, : and / break the database connection URL.
- .env holds real credentials, so it is listed in `.gitignore` and is never committed. Only `.env.example` is committed.

3. Start the application

docker compose up -d --build

The first run takes longer because it downloads the base images and builds the API image. The services start in order, db first, then api, then proxy, because each one waits for the previous one to be healthy. This can take up to a minute.

4. Check that it works

docker compose ps - should show all three services up, with db and api marked (healthy).
curl http://localhost:8080/health - The health request should return {"status":"ok"}.


On Windows PowerShell, use `curl.exe` instead of `curl`, because plain `curl` is an alias for a different command.

5. Stop the application

Stop and keep your data: docker compose down

Full reset, which deletes the database volume: docker compose down -v


If you change the credentials in `.env` after the first run, you need the full reset. Postgres only reads them when it creates a new volume, so the old volume keeps the old password and the API can't log in.

# Design decisions

Three services, one public entry point

The application is split into proxy (Nginx), api (the Notes API) and db (PostgreSQL 16). Each has one job: the proxy receives requests, the API applies the logic, and the database stores the notes. Only the proxy publishes a port (8080 on the host). The api and db services have no ports: section so they can't be reached from outside Docker. Everything goes through one controlled entry point.

- Two networks to isolate the database

I defined two networks frontend and backend:

- frontend: proxy and api
- backend: api and db

The api is the only service on both, so it is the only link between the proxy and the database. The proxy is not on backend so Docker's DNS can't resolve db from inside it, and a compromised proxy would have no route to the database.

- Service names instead of IP addresses

Services reach each other by name (api:8000, db:5432). Docker's built-in DNS resolves the name to the container's current address so nothing breaks when containers are recreated and their IPs change.

- Multi-stage build, Alpine base and non-root user

The API Dockerfile has two stages. The build stage installs dependencies into /install with pip install --prefix. The final stage starts from a fresh image and copies only /install and app.py so pip's working files stay behind.

- Alpine base: a python:3.13-slim build came out at about 204 MB, over the 200 MB limit, so I switched to python:3.13-alpine. The final image is 94.3MB. The trade-off is that Alpine uses BusyBox, so the user commands are addgroup and adduser instead of groupadd and useradd, which the Debian-based slim image provides.
- Non-root user: the container runs as appuser, so a bug in the app gives an attacker an unprivileged account instead of root. The app listens on port 8000 because non-root users can't bind to ports below 1024.
- Gunicorn: the container runs gunicorn instead of Flask's development server, which isn't meant for production use. It's started in exec form so it receives stop signals correctly.
- Layer order: requirements.txt is copied and installed before the app code, so rebuilds reuse the cached dependency layer when only app.py changes.

- Health checks and startup order

A container that has started isn't necessarily ready. Postgres needs time to initialise, and the API needs a database connection. Both have health checks:

- db uses pg_isready.
- api calls its own /health endpoint, which runs a real query against Postgres. The check uses Python's standard library because the image has no curl.

Compose uses depends_on with condition: service_healthy, so api waits for a healthy db and proxy waits for a healthy api. The API also creates the notes table on startup and retries the connection for up to 30 seconds, so a fresh clone needs no manual database setup.

- Named volume for persistence

Database files are stored in the named volume pg_data, mounted at /var/lib/postgresql/data. A named volume is managed by Docker separately from any container, so docker compose down removes containers and networks but not the data. The notes survive a restart, and down -v is the deliberate way to delete them.

- Configuration in .env

Database credentials live in a local .env file, which is in .gitignore and never committed. Compose substitutes the values into the db and api services at runtime, so no secret is stored in an image or in git. The committed .env.example lists the variable names with placeholder values, so a new contributor knows what to set.

- Read-only Nginx config

The Nginx config is mounted from nginx/ into the container as read-only (:ro). The container only needs to read its config, so it has no reason to be able to modify it.

# Testing/evidence troubleshooting

All checks were run from submissions/temi-daniel on Windows PowerShell (VSCode) The full command output is in [evidence/README.md](evidence/README.md).

1. Services and health

docker compose ps
output - C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose ps
NAME                  IMAGE                COMMAND                  SERVICE   CREATED              STATUS                        PORTS
temi-daniel-api-1     temi-daniel-api      "gunicorn app:app --…"   api       About a minute ago   Up About a minute (healthy)   8000/tcp
temi-daniel-db-1      postgres:16-alpine   "docker-entrypoint.s…"   db        About a minute ago   Up About a minute (healthy)   5432/tcp
temi-daniel-proxy-1   nginx:1.25-alpine    "/docker-entrypoint.…"   proxy     About a minute ago   Up About a minute             0.0.0.0:8080->80/tcp, [::]:8080->80/tcp

All three services are running, and db and api report healthy.

2. API through Nginx

curl http://localhost:8080/health
curl http://localhost:8080/notes
curl -X POST http://localhost:8080/notes -H "Content-Type: application/json" -d "@note.json"


Output -
PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> curl http://localhost:8080/health

Security Warning: Script Execution Risk
Invoke-WebRequest parses the content of the web page. Script code in the web page might be run when the page is parsed.
      RECOMMENDED ACTION:
      Use the -UseBasicParsing switch to avoid script code execution.

      Do you want to continue?

[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"): Y


StatusCode        : 200
StatusDescription : OK
Content           : {"status":"ok"}

RawContent        : HTTP/1.1 200 OK
                    Connection: keep-alive
                    Content-Length: 16
                    Content-Type: application/json
                    Date: Sat, 07 Nov 2026 13:39:53 GMT
                    Server: nginx/1.25.5

                    {"status":"ok"}

Forms             : {}
Headers           : {[Connection, keep-alive], [Content-Length, 16], [Content-Type, application/json], [Date, Sat, 07 Nov 2026 13:39:53 GMT]...}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : mshtml.HTMLDocumentClass
RawContentLength  : 16

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> curl http://localhost:8080/notes

Security Warning: Script Execution Risk
Invoke-WebRequest parses the content of the web page. Script code in the web page might be run when the page is parsed.
      RECOMMENDED ACTION:
      Use the -UseBasicParsing switch to avoid script code execution.

      Do you want to continue?

[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"): Y


StatusCode        : 200
StatusDescription : OK
Content           : [{"content":"Testing persistence","created_at":"Sat, 07 Nov 2026 10:46:32 GMT","id":1,"title":"Docker Volume"}]

RawContent        : HTTP/1.1 200 OK
                    Connection: keep-alive
                    Content-Length: 112
                    Content-Type: application/json
                    Date: Sat, 07 Nov 2026 13:41:00 GMT
                    Server: nginx/1.25.5

                    [{"content":"Testing persistence","created_at...
Forms             : {}
Headers           : {[Connection, keep-alive], [Content-Length, 112], [Content-Type, application/json], [Date, Sat, 07 Nov 2026 13:41:00 GMT]...}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : mshtml.HTMLDocumentClass
RawContentLength  : 112


PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> $body = @{
>>     title   = "Docker Volume"
>>     content = "Testing persistence"
>> } | ConvertTo-Json
>>
>> Invoke-RestMethod -Uri "http://localhost:8080/notes" -Method POST -ContentType "application/json" -Body $body

content             created_at                    id title
-------             ----------                    -- -----
Testing persistence Sat, 07 Nov 2026 10:46:32 GMT  1 Docker Volume


PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> curl.exe http://localhost:8080/notes
[{"content":"Testing persistence","created_at":"Sat, 07 Nov 2026 10:46:32 GMT","id":1,"title":"Docker Volume"}]

/health returns 200, POST /notes returns 201 with an id and created_at generated by PostgreSQL, and GET /notes returns the saved note. This shows the request path works from the host, through Nginx and the API, to the database.

3. Only the proxy is published

docker compose ps


output -
temi-daniel-proxy-1   nginx:1.25-alpine    "/docker-entrypoint.…"   proxy     About a minute ago   Up About a minute             0.0.0.0:8080->80/tcp, [::]:8080->80/tcp

Only proxy has a host port mapping (8080 to 80). api and db publish nothing.

4. Image size, multi-stage build and non-root user


docker image ls temi-daniel-api -

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker image ls temi-daniel-api
                                                                                                                                           i Info →   U  In Use
IMAGE                    ID             DISK USAGE   CONTENT SIZE   EXTRA
temi-daniel-api:latest   463c1dcdbabb       94.3MB           23MB    U

docker history temi-daniel-api

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker history temi-daniel-api
IMAGE          CREATED      CREATED BY                                      SIZE      COMMENT
463c1dcdbabb   2 days ago   CMD ["gunicorn" "app:app" "--bind" "0.0.0.0:…   0B        buildkit.dockerfile.v0
<missing>      2 days ago   EXPOSE [8000/tcp]                               0B        buildkit.dockerfile.v0
<missing>      2 days ago   USER appuser                                    0B        buildkit.dockerfile.v0
<missing>      2 days ago   COPY --chown=appuser:apigroup app.py . # bui…   12.3kB    buildkit.dockerfile.v0
<missing>      2 days ago   COPY /install /usr/local # buildkit             18.3MB    buildkit.dockerfile.v0
<missing>      2 days ago   RUN /bin/sh -c addgroup -S apigroup && addus…   36.9kB    buildkit.dockerfile.v0
<missing>      2 days ago   WORKDIR /api                                    8.19kB    buildkit.dockerfile.v0
<missing>      5 days ago   CMD ["python3"]                                 0B        buildkit.dockerfile.v0
<missing>      5 days ago   RUN /bin/sh -c set -eux;  for src in idle3 p…   16.4kB    buildkit.dockerfile.v0
<missing>      5 days ago   RUN /bin/sh -c set -eux;   apk add --no-cach…   41MB      buildkit.dockerfile.v0
<missing>      5 days ago   ENV PYTHON_SHA256=abb0102e6d4ae027509bcb8232…   0B        buildkit.dockerfile.v0
<missing>      5 days ago   ENV PYTHON_VERSION=3.13.18                      0B        buildkit.dockerfile.v0
<missing>      5 days ago   ENV GPG_KEY=7169605F62C751356D054A26A821E680…   0B        buildkit.dockerfile.v0
<missing>      5 days ago   RUN /bin/sh -c set -eux;  apk add --no-cache…   2.81MB    buildkit.dockerfile.v0
<missing>      5 days ago   ENV LANG=C.UTF-8                                0B        buildkit.dockerfile.v0
<missing>      5 days ago   ENV PATH=/usr/local/bin:/usr/local/sbin:/usr…   0B        buildkit.dockerfile.v0
<missing>      5 days ago   CMD ["/bin/sh"]                                 0B        buildkit.dockerfile.v0
<missing>      5 days ago   ADD alpine-minirootfs-3.24.4-x86_64.tar.gz /…   9.09MB    buildkit.dockerfile.v0
PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel>


docker compose exec api whoami

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose exec api whoami
appuser


The final image is 23mb under the 200 MB limit. docker history shows the packages copied from the build stage, with no pip install layer in the final image. The container runs as appuser not root.

5. Network isolation

- docker network inspect temi-daniel_frontend --format "{{range .Containers}}{{.Name}} {{end}}"

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker network inspect temi-daniel_frontend --format "{{range .Containers}}{{.Name}} {{end}}"
>>
temi-daniel-proxy-1 temi-daniel-api-1


- docker network inspect temi-daniel_backend --format "{{range .Containers}}{{.Name}} {{end}}"

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker network inspect temi-daniel_backend --format "{{range .Containers}}{{.Name}} {{end}}"
>>
temi-daniel-api-1 temi-daniel-db-1

The api container is on both networks. The proxy cannot resolve db because the two share no network.

- docker compose exec proxy ping -c 1 db:

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose exec proxy ping -c 1 db

ping: bad address 'db'

6. Persistence

curl http://localhost:8080/notes
docker compose down
docker compose up -d
curl http://localhost:8080/notes

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose down
[+] down 5/5
 ✔ Container temi-daniel-proxy-1 Removed                                                                                                                   0.5s
 ✔ Container temi-daniel-api-1   Removed                                                                                                                   1.1s
 ✔ Container temi-daniel-db-1    Removed                                                                                                                   0.5s
 ✔ Network temi-daniel_frontend  Removed                                                                                                                   0.7s
 ✔ Network temi-daniel_backend   Removed                                                                                                                   0.4s
PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose up -d
[+] up 5/5
 ✔ Network temi-daniel_backend   Created                                                                                                                   0.1s
 ✔ Network temi-daniel_frontend  Created                                                                                                                   0.1s
 ✔ Container temi-daniel-db-1    Healthy                                                                                                                  12.6s
 ✔ Container temi-daniel-api-1   Healthy                                                                                                                  18.8s
 ✔ Container temi-daniel-proxy-1 Started                                                                                                                  19.1s
PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> curl http://localhost:8080/notes

Security Warning: Script Execution Risk
Invoke-WebRequest parses the content of the web page. Script code in the web page might be run when the page is parsed.
      RECOMMENDED ACTION:
      Use the -UseBasicParsing switch to avoid script code execution.

      Do you want to continue?

[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"): Y


StatusCode        : 200
StatusDescription : OK
Content           : [{"content":"Testing persistence","created_at":"Sat, 07 Nov 2026 10:46:32 GMT","id":1,"title":"Docker Volume"}]

RawContent        : HTTP/1.1 200 OK
                    Connection: keep-alive
                    Content-Length: 112
                    Content-Type: application/json
                    Date: Sat, 07 Nov 2026 13:57:59 GMT
                    Server: nginx/1.25.5

                    [{"content":"Testing persistence","created_at...
Forms             : {}
Headers           : {[Connection, keep-alive], [Content-Length, 112], [Content-Type, application/json], [Date, Sat, 07 Nov 2026 13:57:59 GMT]...}
Images            : {}
InputFields       : {}
Links             : {}
ParsedHtml        : mshtml.HTMLDocumentClass
RawContentLength  : 112


The note has the same id and created_at after down and up -d so it was read back from the pg_data volume.

7. .env is ignored by git, and .env.example is committed with placeholder values only. In a fresh clone cp .env.example .env followed by docker compose up -d --build gave a working /health response with no other steps.

#Troubleshooting

1. Docker Hub connection errors when pulling images

- Symptom: docker compose up failed with tls: protocol version not supported while pulling nginx and later with server gave HTTP response to HTTPS client while pulling python.
- Diagnosis: the errors named auth.docker.io and registry-1.docker.io, and Compose had already read my file, so the problem was the connection to the registry and not my configuration.
- Fix: I had to change my network and also restarted my docker desktop

2.  API exits with `password authentication failed

- Symptom: db showed Healthy, but api exited with code 3 after about 48 seconds.
- Diagnosis: docker compose logs api showed 30 retries of password authentication failed then a RuntimeError
- Cause: Postgres only reads POSTGRES_USER, POSTGRES_PASSWORD and POSTGRES_DB when it first creates an empty volume. I had changed .env afterwards, so the volume kept the old password. pg_isready doesn't check passwords, so db still looked healthy.
- Fix: docker compose down -v removed the volume so Postgres initialised again with the current values.

3. Dockerfile and compose mistakes

- python:3.16-slim: not found: that tag doesn't exist. I changed it to a real version and used the same one in both stages.
- Volume mount failing: my source path pointed at a folder or the wrong file name while the destination was a single file. I corrected the source to the real file inside nginx/.
- Healthcheck never passing: "python -c" was one array item, so Docker looked for a program with that exact name. In exec form each argument must be its own item, so I split it into "python" and "-c". The same rule applied to "--bind", "0.0.0.0:8000" in the Dockerfile CMD.
- COPY source and destination mixed up: copying . to app.py created a directory called app.py. I changed it to copy the single file into the working directory.

4. Image over 200 MB, and Alpine user commands

- Symptom: docker image ls temi-daniel-api showed 204 MB with python:3.13-slim.
- Fix: I switched both stages to python:3.13-alpine.
- Follow-on error: Alpine uses BusyBox, so groupadd and useradd failed with not found. I used addgroup -S and adduser -S -G ... -h ... -s ... instead, and had to remove -c, which BusyBox adduser doesn't accept.

5. PowerShell quirks

- POST returning 400 'content' is required: PowerShell split my inline JSON at the spaces. I wrote the JSON to note.json and sent it with -d "@note.json".

6. Smaller mistakes

- Typing docker compose up -d -- build (with a space) made Compose treat build as a service name. The flag is --build.
- Running Compose from the submissions folder gave no configuration file provided, because Compose only looks in the current folder.

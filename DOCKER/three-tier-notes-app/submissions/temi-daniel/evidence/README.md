Notes API supports GET /health, GET /notes, POST /notes
output -
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


2. Notes are stored in PostgreSQL 16

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose exec db psql -U temmy -d dbnotes
psql (16.15)
Type "help" for help.

dbnotes=# \dt
       List of relations
 Schema | Name  | Type  | Owner
--------+-------+-------+-------
 public | notes | table | temmy
(1 row)

dbnotes=# Submission Instructions
dbnotes-# Fork the CloudPros community projects repository and create a branch for Week 2.
dbnotes-# Add your work under DOCKER/three-tier-notes-app/submissions/<your-github-username>/.
dbnotes-# Include a README with setup instructions, design decisions, tests and evidence.
dbnotes-# Open a Pull Request against the designated submissions branch, following the repository's existing contribution workflow. Do not merge your own PR before review.
dbnotes'# Use the title: [Week 2] Containerise a 3-Tier App - Your Name.
dbnotes'# In the PR description, summarise what you built, how you tested it, what you learnt and anything you struggled with.
dbnotes=#

3. Compose defines proxy, api, db

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose up -d
[+] up 6/6
 ✔ Network temi-daniel_backend   Created                                                                                                                   0.1s
 ✔ Network temi-daniel_frontend  Created                                                                                                                   0.1s
 ✔ Volume temi-daniel_pg_data    Created                                                                                                                   0.0s
 ✔ Container temi-daniel-db-1    Healthy                                                                                                                  12.1s
 ✔ Container temi-daniel-api-1   Healthy                                                                                                                  18.3s
 ✔ Container temi-daniel-proxy-1 Started

4. Only Nginx is published on host port 8080

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose ps
NAME                  IMAGE                COMMAND                  SERVICE   CREATED       STATUS                 PORTS
temi-daniel-api-1     temi-daniel-api      "gunicorn app:app --…"   api       3 hours ago   Up 3 hours (healthy)   8000/tcp
temi-daniel-db-1      postgres:16-alpine   "docker-entrypoint.s…"   db        3 hours ago   Up 3 hours (healthy)   5432/tcp
temi-daniel-proxy-1   nginx:1.25-alpine    "/docker-entrypoint.…"   proxy     3 hours ago   Up 3 hours             0.0.0.0:8080->80/tcp, [::]:8080->80/tcp

5. Multi-stage API Dockerfile, non-root user, final image under 200 MB

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker history temi-daniel-api
IMAGE          CREATED        CREATED BY                                      SIZE      COMMENT
6a2076cc0e70   21 hours ago   CMD ["gunicorn" "app:app" "--bind" "0.0.0.0:…   0B        buildkit.dockerfile.v0
<missing>      21 hours ago   EXPOSE [8000/tcp]                               0B        buildkit.dockerfile.v0
<missing>      21 hours ago   USER appuser                                    0B        buildkit.dockerfile.v0
<missing>      21 hours ago   COPY --chown=appuser:apigroup app.py . # bui…   12.3kB    buildkit.dockerfile.v0
<missing>      21 hours ago   COPY /install /usr/local # buildkit             21.1MB    buildkit.dockerfile.v0
<missing>      21 hours ago   RUN /bin/sh -c groupadd -r apigroup && usera…   41kB      buildkit.dockerfile.v0
<missing>      21 hours ago   WORKDIR /api                                    8.19kB    buildkit.dockerfile.v0
<missing>      2 days ago     CMD ["python3"]                                 0B        buildkit.dockerfile.v0
<missing>      2 days ago     RUN /bin/sh -c set -eux;  for src in idle3 p…   16.4kB    buildkit.dockerfile.v0
<missing>      2 days ago     RUN /bin/sh -c set -eux;   savedAptMark="$(a…   40.5MB    buildkit.dockerfile.v0
<missing>      2 days ago     ENV PYTHON_SHA256=abb0102e6d4ae027509bcb8232…   0B        buildkit.dockerfile.v0
<missing>      2 days ago     ENV PYTHON_VERSION=3.13.18                      0B        buildkit.dockerfile.v0
<missing>      2 days ago     ENV GPG_KEY=7169605F62C751356D054A26A821E680…   0B        buildkit.dockerfile.v0
<missing>      2 days ago     RUN /bin/sh -c set -eux;  apt-get update;  a…   4.93MB    buildkit.dockerfile.v0
<missing>      2 days ago     ENV LANG=C.UTF-8                                0B        buildkit.dockerfile.v0
<missing>      2 days ago     ENV PATH=/usr/local/bin:/usr/local/sbin:/usr…   0B        buildkit.dockerfile.v0
<missing>      2 days ago     # debian.sh --arch 'amd64' out/ 'trixie' '@1…   87.7MB    debuerreotype 0.17
PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> Select-String -Pattern "^FROM" api/Dockerfile

api\Dockerfile:3:FROM python:3.13-slim AS build
api\Dockerfile:13:FROM python:3.13-slim AS production


PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel>
- non root account

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose exec api whoami
appuser

- final stage under 200 image

python:3.13-slim                                                                        09a17cad0266        178MB         45.3MB


7. DB and API have working health checks and correct startup dependencies

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose up -d
[+] up 6/6
 ✔ Network temi-daniel_backend   Created                                                                                                                   0.1s
 ✔ Network temi-daniel_frontend  Created                                                                                                                   0.1s
 ✔ Volume temi-daniel_pg_data    Created                                                                                                                   0.0s
 ✔ Container temi-daniel-db-1    Healthy                                                                                                                  12.1s
 ✔ Container temi-daniel-api-1   Healthy                                                                                                                  18.3s
 ✔ Container temi-daniel-proxy-1 Started

8. Notes survive docker compose down and docker compose up -d

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


9. Credentials come from ignored .env; safe .env.example is committed

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> git check-ignore -v .env
DOCKER/three-tier-notes-app/submissions/temi-daniel/.gitignore:1:.env   .env
PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> git status
On branch week-2-notes-app
Your branch is up to date with 'origin/week-2-notes-app'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   .env.example
        modified:   .gitignore
        modified:   api/.dockerignore
        modified:   api/Dockerfile
        modified:   docker-compose.yaml

Untracked files:
  (use "git add <file>..." to include in what will be committed)
        evidence/
        nginx/

no changes added to commit (use "git add" and/or "git commit -a")

10. frontend and backend networks isolate the proxy from the DB

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker network inspect temi-daniel_frontend --format "{{range .Containers}}{{.Name}}{{end}}"
temi-daniel-api-1temi-daniel-proxy-1
PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker network inspect temi-daniel_backend --format "{{range .Containers}}{{.Name}}{{end}}"
temi-daniel-api-1temi-daniel-db-1

11. Fresh-clone command works

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> cp .env.example .env

PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose down -v
[+] down 6/6
 ✔ Container temi-daniel-proxy-1 Removed                                                                                                                   0.1s
 ✔ Container temi-daniel-api-1   Removed                                                                                                                   0.2s
 ✔ Container temi-daniel-db-1    Removed                                                                                                                   0.7s
 ✔ Volume temi-daniel_pg_data    Removed                                                                                                                   0.1s
 ✔ Network temi-daniel_frontend  Removed                                                                                                                   0.5s
 ✔ Network temi-daniel_backend   Removed                                                                                                                   0.8s
PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel> docker compose up -d --build
#1 [internal] load local bake definitions
#1 reading from stdin 711B done
#1 DONE 0.0s

#2 [internal] load build definition from Dockerfile
#2 transferring dockerfile: 599B 0.0s done
#2 DONE 0.1s

#3 [internal] load metadata for docker.io/library/python:3.13-slim
#3 DONE 0.2s

#4 [internal] load .dockerignore
#4 transferring context: 58B 0.0s done
#4 DONE 0.1s

#5 [internal] load build context
#5 transferring context: 63B 0.0s done
#5 DONE 0.1s

#6 [build 1/4] FROM docker.io/library/python:3.13-slim@sha256:09a17cad02668ae61ece136b4fd36ac3849e14f670ebedb637ea3e15580525bc
#6 resolve docker.io/library/python:3.13-slim@sha256:09a17cad02668ae61ece136b4fd36ac3849e14f670ebedb637ea3e15580525bc 0.1s done
#6 DONE 0.1s

#7 [build 4/4] RUN pip install --no-cache-dir --prefix=/install -r requirements.txt
#7 CACHED

#8 [production 4/5] COPY --from=build /install /usr/local
#8 CACHED

#9 [build 2/4] WORKDIR /api
#9 CACHED

#10 [production 3/5] RUN groupadd -r apigroup && useradd -r -g apigroup -d /api -s /sbin/nologin -c "Docker image user" appuser
#10 CACHED

#11 [build 3/4] COPY requirements.txt .
#11 CACHED

#12 [production 5/5] COPY --chown=appuser:apigroup app.py .
#12 CACHED

#13 exporting to image
#13 exporting layers 0.0s done
#13 exporting manifest sha256:e30ad13b5bad8efe8d8dfc582954bb2a3cbe3fe1a72c18e6dcc44974b1cc70d8
#13 exporting manifest sha256:e30ad13b5bad8efe8d8dfc582954bb2a3cbe3fe1a72c18e6dcc44974b1cc70d8 done
#13 exporting config sha256:10741a1639771b90f26c3b0349eda16698e016fbbc60fe362fcc0e80960a24c9 done
#13 exporting attestation manifest sha256:1b474ea29cd1d0a0af943de03897653d090d67aaec249745423c8a5bc8c99a97 0.1s done
#13 exporting manifest list sha256:ebd26993a22321c24d599a4bd3979e4f7c43feb4f4ebee55cc5a378107ce23fd
#13 exporting manifest list sha256:ebd26993a22321c24d599a4bd3979e4f7c43feb4f4ebee55cc5a378107ce23fd 0.1s done
#13 naming to docker.io/library/temi-daniel-api:latest 0.0s done
#13 unpacking to docker.io/library/temi-daniel-api:latest 0.0s done
#13 DONE 0.5s

#14 resolving provenance for metadata file
#14 DONE 0.0s
[+] up 7/7
 ✔ Image temi-daniel-api         Built                                                                                                                     5.5s
 ✔ Network temi-daniel_backend   Created                                                                                                                   0.2s
 ✔ Network temi-daniel_frontend  Created                                                                                                                   0.2s
 ✔ Volume temi-daniel_pg_data    Created                                                                                                                   0.0s
 ✔ Container temi-daniel-db-1    Healthy                                                                                                                  13.2s
 ✔ Container temi-daniel-api-1   Healthy                                                                                                                  19.6s
 ✔ Container temi-daniel-proxy-1 Started                                                                                                                  19.9s
PS C:\Users\HP\OneDrive\Desktop\Docker\cloudpros-community-projects\DOCKER\three-tier-notes-app\submissions\temi-daniel>

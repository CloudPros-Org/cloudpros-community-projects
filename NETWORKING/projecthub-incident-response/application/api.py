from __future__ import annotations
import json
import sqlite3
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
from common import DB_PATH, log, read_config


def connect():
    DB_PATH.parent.mkdir(exist_ok=True)
    connection = sqlite3.connect(DB_PATH, timeout=5)
    connection.row_factory = sqlite3.Row
    return connection


@contextmanager
def database():
    db = connect()
    try:
        with db:
            yield db
    finally:
        db.close()


def initialise_database():
    with database() as db:
        db.executescript("""
        CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY, name TEXT NOT NULL, owner TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            project_id INTEGER NOT NULL DEFAULT 1,
            status TEXT NOT NULL DEFAULT 'queued',
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        """)
        if db.execute("SELECT COUNT(*) FROM projects").fetchone()[0] == 0:
            db.executemany("INSERT INTO projects(name, owner) VALUES (?, ?)", [
                ("Network refresh", "Maya Chen"),
                ("Customer portal", "Jordan Lee"),
                ("Observability rollout", "Sam Patel"),
            ])


class Handler(BaseHTTPRequestHandler):
    server_version = "ProjectHubAPI/1.0"

    def send_json(self, status, payload):
        body = json.dumps(payload, indent=2).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        try:
            if path == "/health":
                with database() as db:
                    db.execute("SELECT 1").fetchone()
                return self.send_json(200, {"status": "ok", "service": "projecthub-api", "database": "reachable"})
            if path == "/api/projects":
                with database() as db:
                    rows = db.execute("SELECT id, name, owner FROM projects ORDER BY id").fetchall()
                return self.send_json(200, {"projects": [dict(row) for row in rows]})
            if path == "/api/tasks":
                with database() as db:
                    rows = db.execute("SELECT id, title, project_id, status, created_at FROM tasks ORDER BY id DESC").fetchall()
                return self.send_json(200, {"tasks": [dict(row) for row in rows]})
            if path == "/api/jobs/next":
                with database() as db:
                    row = db.execute("SELECT id, title FROM tasks WHERE status='queued' ORDER BY id LIMIT 1").fetchone()
                    if row:
                        db.execute("UPDATE tasks SET status='processing' WHERE id=?", (row["id"],))
                return self.send_json(200, {"job": dict(row) if row else None})
            return self.send_json(404, {"error": "not_found", "path": path})
        except sqlite3.Error as exc:
            log("api", f"database error on GET {path}: {exc}")
            return self.send_json(503, {"error": "database_unavailable"})

    def do_POST(self):
        path = urlparse(self.path).path
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, json.JSONDecodeError):
            return self.send_json(400, {"error": "invalid_json"})
        try:
            if path == "/api/tasks":
                title = str(payload.get("title", "")).strip()
                if not title:
                    return self.send_json(400, {"error": "title_required"})
                with database() as db:
                    cursor = db.execute("INSERT INTO tasks(title) VALUES (?)", (title,))
                    task_id = cursor.lastrowid
                log("api", f"created task id={task_id}")
                return self.send_json(201, {"id": task_id, "title": title, "status": "queued"})
            if path.startswith("/api/jobs/") and path.endswith("/complete"):
                task_id = int(path.split("/")[3])
                with database() as db:
                    db.execute("UPDATE tasks SET status='processed' WHERE id=?", (task_id,))
                return self.send_json(200, {"id": task_id, "status": "processed"})
            return self.send_json(404, {"error": "not_found", "path": path})
        except (sqlite3.Error, ValueError) as exc:
            log("api", f"database/request error on POST {path}: {exc}")
            return self.send_json(503, {"error": "request_failed"})

    def log_message(self, fmt, *args):
        log("api", fmt % args)


def main():
    initialise_database()
    cfg = read_config("api")
    server = ThreadingHTTPServer((cfg["bind_host"], int(cfg["port"])), Handler)
    log("api", f"listening on {cfg['bind_host']}:{cfg['port']}")
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

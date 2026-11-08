import os

import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)

# Database settings come from environment variables (loaded from .env by Docker Compose).
DB_HOST = os.environ.get("DB_HOST", "db")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ["POSTGRES_DB"]
DB_USER = os.environ["POSTGRES_USER"]
DB_PASSWORD = os.environ["POSTGRES_PASSWORD"]


def get_conn():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=3,
    )


def init_db():
    # Create the table automatically if it does not exist yet.
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS notes (
                    id SERIAL PRIMARY KEY,
                    content TEXT NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                )
                """
            )
    finally:
        conn.close()


@app.get("/health")
def health():
    # Ready means: the app is running AND it can reach the database.
    try:
        conn = get_conn()
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        finally:
            conn.close()
        return jsonify(status="ok"), 200
    except Exception:
        return jsonify(status="unavailable"), 503


@app.get("/notes")
def list_notes():
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("SELECT id, content, created_at FROM notes ORDER BY id")
            rows = cur.fetchall()
    finally:
        conn.close()
    return jsonify(
        [{"id": r[0], "content": r[1], "created_at": r[2].isoformat()} for r in rows]
    )


@app.post("/notes")
def create_note():
    data = request.get_json(silent=True) or {}
    content = data.get("content")
    if not isinstance(content, str) or not content.strip():
        return jsonify(error="content is required"), 400
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO notes (content) VALUES (%s) RETURNING id, content, created_at",
                (content.strip(),),
            )
            row = cur.fetchone()
    finally:
        conn.close()
    return (
        jsonify(id=row[0], content=row[1], created_at=row[2].isoformat()),
        201,
    )


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)

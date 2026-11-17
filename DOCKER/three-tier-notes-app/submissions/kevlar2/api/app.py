import os

import psycopg2
from flask import Flask, jsonify, request

app = Flask(__name__)


def connect():
    return psycopg2.connect(
        host=os.environ["POSTGRES_HOST"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        connect_timeout=3,
    )


def init_db():
    with connect() as conn, conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS notes ("
            "id SERIAL PRIMARY KEY, "
            "content TEXT NOT NULL, "
            "created_at TIMESTAMPTZ NOT NULL DEFAULT now())"
        )


@app.get("/health")
def health():
    try:
        with connect() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        return jsonify(status="ok")
    except Exception:
        return jsonify(status="unavailable"), 503


@app.get("/notes")
def list_notes():
    with connect() as conn, conn.cursor() as cur:
        cur.execute("SELECT id, content, created_at FROM notes ORDER BY id")
        rows = cur.fetchall()
    return jsonify([{"id": r[0], "content": r[1], "created_at": r[2].isoformat()} for r in rows])


@app.post("/notes")
def create_note():
    content = (request.get_json(silent=True) or {}).get("content", "").strip()
    if not content:
        return jsonify(error="content is required"), 400
    with connect() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO notes (content) VALUES (%s) RETURNING id, created_at",
            (content,),
        )
        note_id, created_at = cur.fetchone()
    return jsonify(id=note_id, content=content, created_at=created_at.isoformat()), 201


init_db()  # runs on import so it also works under gunicorn

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)

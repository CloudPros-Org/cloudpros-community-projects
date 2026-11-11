import os
import time

import psycopg
from psycopg.rows import dict_row
from flask import Flask, jsonify, request

app = Flask(__name__)

# Connection settings come from the environment so nothing is hardcoded.
DATABASE_URL = os.environ.get(
    "DATABASE_URL", "postgresql://notes:notes@localhost:5432/notes"
)


def get_conn():
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)


def init_db(retries=30, delay=1.0):
    """Create the notes table. Retries because Postgres may still be starting."""
    for attempt in range(1, retries + 1):
        try:
            with get_conn() as conn:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS notes (
                        id         SERIAL PRIMARY KEY,
                        title      TEXT NOT NULL DEFAULT '',
                        content    TEXT NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                    """
                )
            return
        except psycopg.OperationalError as exc:
            print(f"DB not ready (attempt {attempt}/{retries}): {exc}", flush=True)
            time.sleep(delay)
    raise RuntimeError("Could not connect to the database")


@app.get("/health")
def health():
    # "Ready" means the app can actually reach PostgreSQL.
    try:
        with get_conn() as conn:
            conn.execute("SELECT 1")
        return jsonify(status="ok"), 200
    except Exception:
        return jsonify(status="unavailable"), 503


@app.get("/notes")
def list_notes():
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT id, title, content, created_at FROM notes ORDER BY id DESC"
        ).fetchall()
    return jsonify(rows), 200


@app.post("/notes")
def create_note():
    data = request.get_json(silent=True) or {}
    content = (data.get("content") or "").strip()
    title = (data.get("title") or "").strip()
    if not content:
        return jsonify(error="'content' is required"), 400

    with get_conn() as conn:
        row = conn.execute(
            """
            INSERT INTO notes (title, content)
            VALUES (%s, %s)
            RETURNING id, title, content, created_at
            """,
            (title, content),
        ).fetchone()
    return jsonify(row), 201


init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))

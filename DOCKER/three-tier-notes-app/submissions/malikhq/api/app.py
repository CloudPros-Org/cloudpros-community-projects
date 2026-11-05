
import os
import time

import psycopg
from flask import Flask, jsonify, request
from psycopg.rows import dict_row

app = Flask(__name__)

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "db"),
    "port": int(os.environ.get("DB_PORT", "5432")),
    "dbname": os.environ["DB_NAME"],
    "user": os.environ["DB_USER"],
    "password": os.environ["DB_PASSWORD"],
    "connect_timeout": 3,
}


def get_connection():
    return psycopg.connect(**DB_CONFIG, row_factory=dict_row)


def initialise_database():
    last_error = None

    for attempt in range(10):
        try:
            with get_connection() as conn:
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS notes (
                        id BIGSERIAL PRIMARY KEY,
                        title VARCHAR(200) NOT NULL,
                        content TEXT NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                """)

            app.logger.info("Database schema is ready")
            return

        except psycopg.OperationalError as exc:
            last_error = exc
            app.logger.warning(
                "Database not ready (attempt %s/10)",
                attempt + 1,
            )
            time.sleep(2)

    raise RuntimeError(
        "Could not initialise database"
    ) from last_error


@app.get("/health")
def health():
    try:
        with get_connection() as conn:
            conn.execute("SELECT 1")

        return jsonify(
            status="ok",
            database="ok",
        ), 200

    except psycopg.Error:
        app.logger.exception("Health check failed")

        return jsonify(
            status="error",
            database="unavailable",
        ), 503


@app.get("/notes")
def list_notes():
    try:
        with get_connection() as conn:
            rows = conn.execute("""
                SELECT id, title, content, created_at
                FROM notes
                ORDER BY id DESC
            """).fetchall()

        notes = [
            {
                **row,
                "created_at": row["created_at"].isoformat(),
            }
            for row in rows
        ]

        return jsonify(notes), 200

    except psycopg.Error:
        app.logger.exception("Failed to retrieve notes")

        return jsonify(
            error="Database operation failed"
        ), 503


@app.post("/notes")
def create_note():
    if not request.is_json:
        return jsonify(
            error="Content-Type must be application/json"
        ), 415

    payload = request.get_json(silent=True)

    if not isinstance(payload, dict):
        return jsonify(
            error="Request body must be a JSON object"
        ), 400

    title = payload.get("title")
    content = payload.get("content")

    if not isinstance(title, str) or not title.strip():
        return jsonify(
            error="title must be a non-empty string"
        ), 400

    if len(title.strip()) > 200:
        return jsonify(
            error="title must be 200 characters or fewer"
        ), 400

    if not isinstance(content, str) or not content.strip():
        return jsonify(
            error="content must be a non-empty string"
        ), 400

    try:
        with get_connection() as conn:
            row = conn.execute(
                """
                INSERT INTO notes (title, content)
                VALUES (%s, %s)
                RETURNING id, title, content, created_at
                """,
                (title.strip(), content.strip()),
            ).fetchone()

        row["created_at"] = row["created_at"].isoformat()

        return jsonify(row), 201

    except psycopg.Error:
        app.logger.exception("Failed to create note")

        return jsonify(
            error="Database operation failed"
        ), 503


with app.app_context():
    initialise_database()

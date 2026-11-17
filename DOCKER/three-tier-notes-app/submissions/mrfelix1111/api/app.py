import os
import time

import psycopg
from flask import Flask, jsonify, request
from psycopg.rows import dict_row

app = Flask(__name__)

DATABASE_URL = os.environ["DATABASE_URL"]


def get_db_connection():
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)


def initialise_database():
    for attempt in range(10):
        try:
            with get_db_connection() as conn:
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS notes (
                        id SERIAL PRIMARY KEY,
                        content TEXT NOT NULL,
                        created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
                    )
                """)
            print("Database table is ready.")
            return
        except psycopg.OperationalError:
            if attempt == 9:
                raise
            print("Waiting for database...")
            time.sleep(3)


@app.route("/health", methods=["GET"])
def health():
    try:
        with get_db_connection() as conn:
            conn.execute("SELECT 1")
        return jsonify({"status": "healthy"}), 200
    except psycopg.Error:
        return jsonify({"status": "unhealthy"}), 503


@app.route("/notes", methods=["GET"])
def get_notes():
    with get_db_connection() as conn:
        rows = conn.execute(
            "SELECT id, content, created_at FROM notes ORDER BY id"
        ).fetchall()

    return jsonify(rows), 200


@app.route("/notes", methods=["POST"])
def create_note():
    data = request.get_json(silent=True)

    if not data or not isinstance(data.get("content"), str):
        return jsonify({"error": "A note content string is required"}), 400

    content = data["content"].strip()

    if not content:
        return jsonify({"error": "Note content cannot be empty"}), 400

    with get_db_connection() as conn:
        note = conn.execute(
            "INSERT INTO notes (content) VALUES (%s) "
            "RETURNING id, content, created_at",
            (content,)
        ).fetchone()

    return jsonify(note), 201


if __name__ == "__main__":
    initialise_database()
    app.run(host="0.0.0.0", port=5000)

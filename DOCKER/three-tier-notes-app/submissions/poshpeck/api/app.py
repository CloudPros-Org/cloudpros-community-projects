import os

import psycopg
from flask import Flask, jsonify, request

app = Flask(__name__)


def get_db_connection():
    """Create a connection to the PostgreSQL database."""
    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("POSTGRES_DB", "notesdb"),
        user=os.getenv("POSTGRES_USER", "notesuser"),
        password=os.getenv("POSTGRES_PASSWORD"),
    )


@app.route("/health", methods=["GET"])
def health():
    """Check whether the API and database are available."""
    try:
        with get_db_connection() as conn:
            conn.execute("SELECT 1")

        return jsonify({
            "status": "healthy",
            "application": "notes-api",
            "database": "connected"
        }), 200

    except psycopg.Error:
        return jsonify({
            "status": "unhealthy",
            "application": "notes-api",
            "database": "disconnected"
        }), 503


@app.route("/notes", methods=["GET"])
def get_notes():
    """Retrieve all notes from PostgreSQL."""
    try:
        with get_db_connection() as conn:
            rows = conn.execute(
                """
                SELECT id, title, content, created_at
                FROM notes
                ORDER BY id DESC
                """
            ).fetchall()

        notes = [
            {
                "id": row[0],
                "title": row[1],
                "content": row[2],
                "created_at": row[3].isoformat()
            }
            for row in rows
        ]

        return jsonify(notes), 200

    except psycopg.Error:
        return jsonify({"error": "Database operation failed"}), 500


@app.route("/notes", methods=["POST"])
def create_note():
    """Create and save a new note."""
    data = request.get_json(silent=True)

    if not isinstance(data, dict):
        return jsonify({"error": "A JSON object is required"}), 400

    title = data.get("title")
    content = data.get("content")

    if not isinstance(title, str) or not title.strip():
        return jsonify({"error": "A valid title is required"}), 400

    if not isinstance(content, str) or not content.strip():
        return jsonify({"error": "Valid content is required"}), 400

    if len(title) > 255:
        return jsonify({"error": "Title must not exceed 255 characters"}), 400

    try:
        with get_db_connection() as conn:
            row = conn.execute(
                """
                INSERT INTO notes (title, content)
                VALUES (%s, %s)
                RETURNING id, title, content, created_at
                """,
                (title.strip(), content.strip())
            ).fetchone()

        note = {
            "id": row[0],
            "title": row[1],
            "content": row[2],
            "created_at": row[3].isoformat()
        }

        return jsonify(note), 201

    except psycopg.Error:
        return jsonify({"error": "Could not save note"}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)

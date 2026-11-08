import requests

BASE_URL = "http://localhost:8080"


def test_health_endpoint():
    response = requests.get(f"{BASE_URL}/health")

    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
    assert response.json()["database"] == "connected"


def test_get_notes():
    response = requests.get(f"{BASE_URL}/notes")

    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_create_note():
    payload = {
        "title": "Pytest automated test",
        "content": "Testing note creation through the API."
    }

    response = requests.post(
        f"{BASE_URL}/notes",
        json=payload
    )

    assert response.status_code == 201
    assert response.json()["title"] == payload["title"]
    assert response.json()["content"] == payload["content"]


def test_create_note_without_title():
    payload = {
        "content": "This note has no title."
    }

    response = requests.post(
        f"{BASE_URL}/notes",
        json=payload
    )

    assert response.status_code == 400


def test_create_note_without_content():
    payload = {
        "title": "Missing content"
    }

    response = requests.post(
        f"{BASE_URL}/notes",
        json=payload
    )

    assert response.status_code == 400


def test_create_note_with_invalid_json():
    response = requests.post(
        f"{BASE_URL}/notes",
        data="This is not JSON",
        headers={"Content-Type": "application/json"}
    )

    assert response.status_code == 400

def test_create_note_with_title_over_255_characters():
    payload = {
        "title": "A" * 256,
        "content": "Testing the title length validation."
    }

    response = requests.post(
        f"{BASE_URL}/notes",
        json=payload
    )

    assert response.status_code == 400
    assert response.json()["error"] == "Title must not exceed 255 characters"

from unittest.mock import patch

from fastapi.testclient import TestClient

from backend.main import app

client = TestClient(app)


def test_health_check():
    response = client.get("/healthz")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_chat_requires_a_question():
    response = client.post("/v1/chat", json={"question": "  "})

    assert response.status_code == 422


def test_chat_returns_gemini_answer():
    with patch("backend.main.os.environ.get", side_effect=lambda key, default=None: {
        "GOOGLE_API_KEY": "server-only-test-key",
        "GEMINI_MODEL": "gemini-test",
    }.get(key, default)), patch("backend.main.httpx.Client") as client_class:
        gemini = client_class.return_value.__enter__.return_value
        gemini.post.return_value.status_code = 200
        gemini.post.return_value.json.return_value = {
            "candidates": [
                {"content": {"parts": [{"text": "Respuesta de prueba"}]}}
            ]
        }

        response = client.post("/v1/chat", json={"question": "¿Qué es Toxo?"})

    assert response.status_code == 200
    assert response.json() == {"answer": "Respuesta de prueba"}
    assert gemini.post.call_args.kwargs["headers"] == {
        "x-goog-api-key": "server-only-test-key"
    }


def test_chat_fails_clearly_when_key_is_not_configured():
    with patch("backend.main.os.environ.get", return_value=None):
        response = client.post("/v1/chat", json={"question": "Hola"})

    assert response.status_code == 503


def test_feedback_is_saved_without_user_identifiers():
    with patch("backend.main.firestore.Client") as firestore_client:
        response = client.post(
            "/v1/feedback",
            json={"message": "Me gustó la app"},
        )

    assert response.status_code == 201
    saved = firestore_client.return_value.collection.return_value.add.call_args.args[0]
    assert saved["message"] == "Me gustó la app"
    assert set(saved) == {"message", "created_at"}

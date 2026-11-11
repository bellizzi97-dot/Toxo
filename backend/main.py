import os

import httpx
from fastapi import FastAPI, HTTPException
from google.api_core.exceptions import GoogleAPIError
from google.auth.exceptions import GoogleAuthError
from google.cloud import firestore
from pydantic import BaseModel, Field

app = FastAPI(title="Toxo API", version="1.0.0")


class ChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=4000)


class FeedbackRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)


def _generate_answer(question: str) -> str:
    api_key = os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=503,
            detail="El servicio de IA todavía no está configurado.",
        )

    model = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent"
    )
    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": (
                            "Responde en español, de forma clara y concisa. "
                            "Si no sabes algo, dilo; no inventes datos.\n\n"
                            f"Pregunta: {question}"
                        )
                    }
                ]
            }
        ],
        "generationConfig": {"maxOutputTokens": 768},
    }

    try:
        with httpx.Client(timeout=30) as client:
            response = client.post(
                url,
                headers={"x-goog-api-key": api_key},
                json=payload,
            )
    except httpx.TimeoutException as error:
        raise HTTPException(
            status_code=504,
            detail="El servicio de IA tardó demasiado.",
        ) from error
    except httpx.HTTPError as error:
        raise HTTPException(
            status_code=502,
            detail="No se pudo contactar al servicio de IA.",
        ) from error

    if response.status_code >= 400:
        raise HTTPException(
            status_code=502,
            detail="El servicio de IA rechazó la solicitud.",
        )
    try:
        data = response.json()
        parts = data["candidates"][0]["content"]["parts"]
        if not isinstance(parts, list):
            raise TypeError("Gemini parts were not a list")
        answer = "\n".join(
            part["text"]
            for part in parts
            if isinstance(part, dict) and isinstance(part.get("text"), str)
        ).strip()
    except (IndexError, KeyError, TypeError, ValueError) as error:
        raise HTTPException(
            status_code=502,
            detail="El servicio de IA devolvió una respuesta no válida.",
        ) from error

    if not answer:
        raise HTTPException(
            status_code=502,
            detail="El servicio de IA no devolvió texto.",
        )
    return answer


@app.get("/healthz")
def health_check() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/chat")
def chat(request: ChatRequest) -> dict[str, str]:
    question = request.question.strip()
    if not question:
        raise HTTPException(status_code=422, detail="La pregunta no puede estar vacía.")
    return {"answer": _generate_answer(question)}


@app.post("/v1/feedback", status_code=201)
def submit_feedback(request: FeedbackRequest) -> dict[str, bool]:
    message = request.message.strip()
    if not message:
        raise HTTPException(status_code=422, detail="El comentario no puede estar vacío.")
    try:
        firestore.Client().collection("feedback").add(
            {
                "message": message,
                "created_at": firestore.SERVER_TIMESTAMP,
            }
        )
    except (GoogleAPIError, GoogleAuthError) as error:
        raise HTTPException(
            status_code=503,
            detail="No se pudo guardar el comentario.",
        ) from error
    return {"ok": True}

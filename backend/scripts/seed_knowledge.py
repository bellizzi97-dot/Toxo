from __future__ import annotations

from pathlib import Path

from src.config import AssistantConfig
from src.db import DatabaseManager


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
CONF = AssistantConfig.from_env()


def seed_core_knowledge() -> None:
    db = DatabaseManager(CONF.database_path)
    docs = [
        (
            "Principio de Toxo",
            "Toxo es un asistente de inteligencia artificial diseñado para operar sin conexión. Su propósito es responder preguntas, aprender de la experiencia del usuario y recordar información relevante en un entorno local.",
            "seed",
        ),
        (
            "Offline-first",
            "La base del sistema es la privacidad, la autonomía y la velocidad. Todo debe poder ejecutarse sin depender de internet en cada consulta.",
            "seed",
        ),
        (
            "Personalidad de Toxo",
            "Toxo busca ser útil, cercano y espontáneo. No necesita ser frío ni mecánico; puede ser alegre, curioso y perspicaz cuando ayuda a la persona con la que habla.",
            "seed",
        ),
    ]

    for title, body, source in docs:
        db.add_knowledge(title, body, source)

    print("Knowledge base seeded.")


if __name__ == "__main__":
    seed_core_knowledge()

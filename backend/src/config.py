from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = BASE_DIR / "data"
DB_PATH = DATA_DIR / "toxodb.sqlite3"
KNOWLEDGE_DIR = DATA_DIR / "knowledge"
MEMORY_DIR = DATA_DIR / "memory"

DEFAULT_PERSONALITY = {
    "name": "Toxo",
    "style": "warm, curious, direct, analytical",
    "motto": "Mi trabajo es ayudarte con claridad, memoria y criterio.",
}


@dataclass
class AssistantConfig:
    name: str = "Toxo"
    style: str = "warm, curious, direct, analytical"
    data_dir: Path = DATA_DIR
    database_path: Path = DB_PATH
    knowledge_dir: Path = KNOWLEDGE_DIR
    memory_dir: Path = MEMORY_DIR

    @classmethod
    def from_env(cls) -> "AssistantConfig":
        data_dir = DATA_DIR
        data_dir.mkdir(parents=True, exist_ok=True)
        (data_dir / "knowledge").mkdir(parents=True, exist_ok=True)
        (data_dir / "memory").mkdir(parents=True, exist_ok=True)
        return cls(
            name="Toxo",
            style="warm, curious, direct, analytical",
            data_dir=data_dir,
            database_path=data_dir / "toxodb.sqlite3",
            knowledge_dir=data_dir / "knowledge",
            memory_dir=data_dir / "memory",
        )

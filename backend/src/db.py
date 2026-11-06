from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import List, Tuple


SCHEMA = """
CREATE TABLE IF NOT EXISTS knowledge (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    source TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS memory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    topic TEXT NOT NULL,
    note TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS conversation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_message TEXT NOT NULL,
    assistant_reply TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
"""


class DatabaseManager:
    def __init__(self, db_path: str | Path):
        self.db_path = str(db_path)
        self._initialize()

    def _initialize(self) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.executescript(SCHEMA)

    def add_knowledge(self, title: str, body: str, source: str) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT INTO knowledge (title, body, source) VALUES (?, ?, ?)",
                (title, body, source),
            )

    def add_memory(self, topic: str, note: str) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT INTO memory (topic, note) VALUES (?, ?)",
                (topic, note),
            )

    def add_conversation(self, user_message: str, assistant_reply: str) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                "INSERT INTO conversation (user_message, assistant_reply) VALUES (?, ?)",
                (user_message, assistant_reply),
            )

    def get_all_knowledge(self) -> List[Tuple[str, str, str]]:
        with sqlite3.connect(self.db_path) as conn:
            rows = conn.execute(
                "SELECT title, body, source FROM knowledge ORDER BY id DESC"
            ).fetchall()
        return rows

    def search_memory(self, topic: str, limit: int = 5) -> List[str]:
        with sqlite3.connect(self.db_path) as conn:
            rows = conn.execute(
                "SELECT note FROM memory WHERE topic LIKE ? ORDER BY id DESC LIMIT ?",
                (f"%{topic}%", limit),
            ).fetchall()
        return [row[0] for row in rows]

    def get_recent_conversations(self, limit: int = 5) -> List[Tuple[str, str]]:
        with sqlite3.connect(self.db_path) as conn:
            rows = conn.execute(
                "SELECT user_message, assistant_reply FROM conversation ORDER BY id DESC LIMIT ?",
                (limit,),
            ).fetchall()
        return rows

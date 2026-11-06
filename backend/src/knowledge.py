from __future__ import annotations

from typing import List, Tuple

from src.db import DatabaseManager


class KnowledgeStore:
    def __init__(self, db: DatabaseManager):
        self.db = db

    def add_document(self, title: str, body: str, source: str) -> None:
        self.db.add_knowledge(title, body, source)

    def add_text_file(self, path: str, source_label: str | None = None) -> None:
        with open(path, "r", encoding="utf-8") as handle:
            body = handle.read()
        title = source_label or path.split("/")[-1]
        self.db.add_knowledge(title, body, source_label or path)

    def search(self, query: str, limit: int = 5) -> List[Tuple[str, str, str]]:
        q = query.strip().lower()
        if not q:
            return []

        rows = self.db.get_all_knowledge()
        scored: List[Tuple[float, str, str, str]] = []

        for title, body, source in rows:
            text = f"{title}\n{body}\n{source}".lower()
            score = 0.0
            for token in q.split():
                if token in text:
                    score += 1.0
            if score > 0:
                scored.append((score, title, body, source))

        scored.sort(key=lambda item: item[0], reverse=True)
        result = []
        for score, title, body, source in scored[:limit]:
            result.append((title, body[:600], source))
        return result

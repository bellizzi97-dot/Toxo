# Toxo

Toxo is an offline-first AI assistant designed to run on Android and Windows, capable of learning from user interactions and answering questions from local knowledge sources.

## Goals

- Offline operation with no cloud dependency
- Local knowledge base built from user-provided sources
- Memory and personalization for recurring users
- Cross-platform execution on Android and Windows
- Conversational personality with warmth and spontaneity

## Current status

This repository is being bootstrapped as a practical MVP. It includes:

- a local Python backend for offline knowledge + memory
- a sqlite-based storage layer
- a conversational assistant with simple retrieval logic
- a basic cross-platform architecture plan for Android and Windows

## Quick start

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python src/cli.py
```

## Structure

- `backend/` — core offline assistant engine
- `apps/windows/` — Windows packaging and UX direction
- `apps/android/` — Android app scaffold and architecture
- `docs/` — technical vision and roadmap

## Recommended stack

- Backend: Python + SQLite + local embeddings / retrieval
- Runtime: Ollama or llama.cpp for offline inference when available
- Android: Kotlin + Jetpack Compose
- Windows: Python + Tkinter or a WPF/MAUI version later

## Important note

This project is intentionally designed to work offline using local data and local models. Public datasets such as Wikipedia can be imported when legally available and stored locally, but the repository does not ship copyrighted content by default.

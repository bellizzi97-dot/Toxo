# Toxo backend

This directory contains the initial offline assistant backend.

## What it does

- stores local knowledge in SQLite
- collects user memories and conversation history
- retrieves information relevant to the user's question
- generates a response using local model support when available
- falls back to a deterministic offline answer if no model is installed

## Run it

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python src/cli.py
```

## Data

The app stores data in `backend/data/`.

## Notes

This is an MVP and intentionally simple. The goal is to build a base that can later evolve into a richer application with a real local LLM, user profiles, and richer retrieval.

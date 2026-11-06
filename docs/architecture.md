# Toxo architecture

## Objective

Toxo is a local-first AI assistant for Android and Windows. It stores knowledge and memory locally, can answer without internet, and can personalize the interaction over time.

## Core principles

1. Offline-first
2. User memory and personalization
3. Local knowledge storage
4. Cross-platform compatibility
5. Legal and private data handling

## Architecture

### 1. Local backend

The backend handles:

- database operations
- knowledge retrieval
- learning and memory
- conversations
- local model integration via Ollama

### 2. Knowledge layer

Knowledge is imported from local files or user-generated content. The app stores:

- documents
- notes
- summaries
- snippets that matter to the user

### 3. Memory and personality

Each user can have a profile with:

- preferences
- recurring topics
- facts they care about
- tone and communication style

### 4. Cross-platform apps

- Android: Kotlin + Jetpack Compose
- Windows: Python + Tkinter or future .NET/MAUI

The app layer connects to the same local backend or exposes an API behind the scenes.

## MVP path

1. Bootstrapping a local Python backend
2. Database and memory module
3. Local RAG-style knowledge retrieval
4. Optional local LLM integration via Ollama
5. Android and Windows front ends
6. User profile and personalization
